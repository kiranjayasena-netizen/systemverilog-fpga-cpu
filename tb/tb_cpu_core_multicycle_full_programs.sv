`timescale 1ns / 1ps

module tb_cpu_core_multicycle_full_programs;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_DECODE = 3'd1;
    localparam int unsigned IMEM_DEPTH = 256;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] fetched_instruction;
    logic [31:0] instruction_addr;
    logic [2:0]  state;
    logic [31:0] pc;
    logic [31:0] instruction_reg;
    logic [31:0] instruction_pc;
    logic [3:0]  opcode_reg;
    logic [4:0]  rd_reg;
    logic [4:0]  rs1_reg;
    logic [4:0]  rs2_reg;
    logic [12:0] imm13_reg;
    logic [31:0] imm_ext_reg;
    logic        valid_instr;
    logic        reg_write;
    logic        mem_write;
    logic [31:0] alu_result;
    logic [31:0] memory_read_data;

    logic [31:0] imem [0:IMEM_DEPTH-1];

    int unsigned tests_run;
    int unsigned tests_failed;
    int unsigned subtest_start_run;
    int unsigned subtest_start_failed;
    int unsigned invalid_decode_count;
    int unsigned invalid_bad_valid_count;
    int unsigned invalid_reg_write_pulses;
    int unsigned invalid_mem_write_pulses;
    string active_subtest;

    cpu_core_multicycle dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .fetched_instruction(fetched_instruction),
        .instruction_addr(instruction_addr),
        .state(state),
        .pc(pc),
        .instruction_reg(instruction_reg),
        .instruction_pc(instruction_pc),
        .opcode_reg(opcode_reg),
        .rd_reg(rd_reg),
        .rs1_reg(rs1_reg),
        .rs2_reg(rs2_reg),
        .imm13_reg(imm13_reg),
        .imm_ext_reg(imm_ext_reg),
        .valid_instr(valid_instr),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_result(alu_result),
        .memory_read_data(memory_read_data)
    );

    assign fetched_instruction = imem[instruction_addr[9:2]];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] build_instruction(
        input logic [3:0]  opcode,
        input logic [4:0]  rd,
        input logic [4:0]  rs1,
        input logic [4:0]  rs2,
        input logic [12:0] imm13
    );
        begin
            build_instruction = {opcode, rd, rs1, rs2, imm13};
        end
    endfunction

    function automatic logic opcode_is_valid(input logic [3:0] opcode);
        begin
            unique case (opcode)
                OP_NOP,
                OP_ADD,
                OP_SUB,
                OP_AND,
                OP_OR,
                OP_XOR,
                OP_ADDI,
                OP_LOAD,
                OP_STORE,
                OP_BEQ,
                OP_JUMP: opcode_is_valid = 1'b1;
                default: opcode_is_valid = 1'b0;
            endcase
        end
    endfunction

    task automatic check_value(
        input string       case_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected=0x%08h got=0x%08h",
                    case_name,
                    expected,
                    actual
                );
            end else begin
                $display("PASS: %s | value=0x%08h", case_name, actual);
            end
        end
    endtask

    task automatic start_subtest(input string subtest_name);
        begin
            active_subtest       = subtest_name;
            subtest_start_run    = tests_run;
            subtest_start_failed = tests_failed;

            $display("");
            $display("---- %s ----", active_subtest);
        end
    endtask

    task automatic finish_subtest;
        int unsigned subtest_runs;
        int unsigned subtest_failures;
        begin
            subtest_runs     = tests_run - subtest_start_run;
            subtest_failures = tests_failed - subtest_start_failed;

            $display(
                "%s summary: tests run=%0d, tests failed=%0d",
                active_subtest,
                subtest_runs,
                subtest_failures
            );
        end
    endtask

    task automatic clear_imem;
        int unsigned i;
        begin
            for (i = 0; i < IMEM_DEPTH; i++) begin
                imem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            end
        end
    endtask

    task automatic step_and_monitor(input logic monitor_invalid);
        logic [2:0]  state_before;
        logic [31:0] instruction_before;
        begin
            state_before       = state;
            instruction_before = instruction_reg;

            @(posedge clk);
            #1;

            if (!rst && enable && monitor_invalid &&
                (state_before == STATE_DECODE) &&
                !opcode_is_valid(instruction_before[31:28])) begin
                invalid_decode_count++;

                if (valid_instr !== 1'b0) begin
                    invalid_bad_valid_count++;
                    $error("FAIL: invalid opcode produced valid_instr high");
                end

                if (reg_write !== 1'b0) begin
                    invalid_reg_write_pulses++;
                    $error("FAIL: invalid opcode asserted reg_write");
                end

                if (mem_write !== 1'b0) begin
                    invalid_mem_write_pulses++;
                    $error("FAIL: invalid opcode asserted mem_write");
                end
            end
        end
    endtask

    task automatic run_loaded_program(
        input int unsigned cycle_count,
        input logic        monitor_invalid
    );
        begin
            rst    = 1'b1;
            enable = 1'b0;

            @(posedge clk);
            #1;

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            repeat (cycle_count) begin
                step_and_monitor(monitor_invalid);
            end

            @(negedge clk);
            enable = 1'b0;
            #1;
        end
    endtask

    task automatic load_arithmetic_edge_program;
        begin
            clear_imem();

            imem[0] = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'h1fff);
            imem[1] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd1);
            imem[2] = build_instruction(OP_ADD,  5'd3, 5'd1, 5'd2, 13'd0);
            imem[3] = build_instruction(OP_SUB,  5'd4, 5'd0, 5'd2, 13'd0);
            imem[4] = build_instruction(OP_ADDI, 5'd5, 5'd0, 5'd0, 13'd10);
            imem[5] = build_instruction(OP_ADDI, 5'd6, 5'd0, 5'd0, 13'd20);
            imem[6] = build_instruction(OP_ADD,  5'd7, 5'd5, 5'd6, 13'd0);
            imem[7] = build_instruction(OP_SUB,  5'd8, 5'd6, 5'd5, 13'd0);
            imem[8] = build_instruction(OP_ADDI, 5'd0, 5'd0, 5'd0, 13'd123);
            imem[9] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_memory_offset_program;
        begin
            clear_imem();

            imem[0] = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd64);
            imem[1] = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd123);
            imem[2] = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd2, 13'd0);
            imem[3] = build_instruction(OP_LOAD,  5'd3, 5'd1, 5'd0, 13'd0);
            imem[4] = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd3, 13'd4);
            imem[5] = build_instruction(OP_LOAD,  5'd4, 5'd1, 5'd0, 13'd4);
            imem[6] = build_instruction(OP_ADDI,  5'd5, 5'd0, 5'd0, 13'd68);
            imem[7] = build_instruction(OP_LOAD,  5'd6, 5'd5, 5'd0, 13'h1ffc);
            imem[8] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_branch_control_program;
        begin
            clear_imem();

            imem[0]  = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd5);
            imem[1]  = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd5);
            imem[2]  = build_instruction(OP_BEQ,  5'd0, 5'd1, 5'd2, 13'd2);
            imem[3]  = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd99);
            imem[4]  = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd42);
            imem[5]  = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd1);
            imem[6]  = build_instruction(OP_ADDI, 5'd5, 5'd0, 5'd0, 13'd2);
            imem[7]  = build_instruction(OP_BEQ,  5'd0, 5'd4, 5'd5, 13'd2);
            imem[8]  = build_instruction(OP_ADDI, 5'd6, 5'd0, 5'd0, 13'd77);
            imem[9]  = build_instruction(OP_ADDI, 5'd7, 5'd0, 5'd0, 13'd88);
            imem[10] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_jump_control_program;
        begin
            clear_imem();

            imem[0] = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd11);
            imem[1] = build_instruction(OP_JUMP, 5'd0, 5'd0, 5'd0, 13'd2);
            imem[2] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd99);
            imem[3] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd22);
            imem[4] = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd33);
            imem[5] = build_instruction(OP_JUMP, 5'd0, 5'd0, 5'd0, 13'd2);
            imem[6] = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd99);
            imem[7] = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd44);
            imem[8] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_simple_loop_program;
        begin
            clear_imem();

            imem[0] = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd0);
            imem[1] = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd3);
            imem[2] = build_instruction(OP_ADDI,  5'd3, 5'd0, 5'd0, 13'd1);
            imem[3] = build_instruction(OP_ADD,   5'd1, 5'd1, 5'd3, 13'd0);
            imem[4] = build_instruction(OP_SUB,   5'd2, 5'd2, 5'd3, 13'd0);
            imem[5] = build_instruction(OP_BEQ,   5'd0, 5'd2, 5'd0, 13'd2);
            imem[6] = build_instruction(OP_JUMP,  5'd0, 5'd0, 5'd0, 13'h1ffd);
            imem[7] = build_instruction(OP_STORE, 5'd0, 5'd0, 5'd1, 13'd0);
            imem[8] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_invalid_opcode_program;
        begin
            clear_imem();

            imem[0] = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd10);
            imem[1] = build_instruction(4'hb,    5'd3, 5'd0, 5'd0, 13'd111);
            imem[2] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd20);
            imem[3] = build_instruction(4'hf,    5'd4, 5'd0, 5'd2, 13'd0);
            imem[4] = build_instruction(OP_STORE, 5'd0, 5'd0, 5'd2, 13'd0);
            imem[5] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_full_programs.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_full_programs);

        $display("Starting Phase 8F multi-cycle CPU full-program verification...");

        rst                       = 1'b1;
        enable                    = 1'b0;
        tests_run                 = 0;
        tests_failed              = 0;
        invalid_decode_count      = 0;
        invalid_bad_valid_count   = 0;
        invalid_reg_write_pulses  = 0;
        invalid_mem_write_pulses  = 0;
        active_subtest            = "";
        subtest_start_run         = 0;
        subtest_start_failed      = 0;

        start_subtest("Arithmetic edge program");
        load_arithmetic_edge_program();
        run_loaded_program(90, 1'b0);
        check_value("arithmetic: x0 remains zero", dut.regs[0], 32'd0);
        check_value("arithmetic: ADDI x1, x0, -1", dut.regs[1], 32'hffff_ffff);
        check_value("arithmetic: ADDI x2, x0, 1", dut.regs[2], 32'd1);
        check_value("arithmetic: ADD wraparound x3", dut.regs[3], 32'h0000_0000);
        check_value("arithmetic: SUB underflow x4", dut.regs[4], 32'hffff_ffff);
        check_value("arithmetic: ADDI x5, x0, 10", dut.regs[5], 32'd10);
        check_value("arithmetic: ADDI x6, x0, 20", dut.regs[6], 32'd20);
        check_value("arithmetic: ADD x7, x5, x6", dut.regs[7], 32'd30);
        check_value("arithmetic: SUB x8, x6, x5", dut.regs[8], 32'd10);
        finish_subtest();

        start_subtest("Memory offset program");
        load_memory_offset_program();
        run_loaded_program(100, 1'b0);
        check_value("memory: x0 remains zero", dut.regs[0], 32'd0);
        check_value("memory: base address x1", dut.regs[1], 32'd64);
        check_value("memory: stored value x2", dut.regs[2], 32'd123);
        check_value("memory: load [base + 0] into x3", dut.regs[3], 32'd123);
        check_value("memory: load [base + 4] into x4", dut.regs[4], 32'd123);
        check_value("memory: alternate base x5", dut.regs[5], 32'd68);
        check_value("memory: load [x5 - 4] into x6", dut.regs[6], 32'd123);
        check_value("memory: data word 16", dut.data_mem[16], 32'd123);
        check_value("memory: data word 17", dut.data_mem[17], 32'd123);
        finish_subtest();

        start_subtest("Branch control program");
        load_branch_control_program();
        run_loaded_program(100, 1'b0);
        check_value("branch: x0 remains zero", dut.regs[0], 32'd0);
        check_value("branch: x1 = 5", dut.regs[1], 32'd5);
        check_value("branch: x2 = 5", dut.regs[2], 32'd5);
        check_value("branch: taken BEQ skips x3 = 99", dut.regs[3], 32'd42);
        check_value("branch: x4 = 1", dut.regs[4], 32'd1);
        check_value("branch: x5 = 2", dut.regs[5], 32'd2);
        check_value("branch: not-taken BEQ executes x6 = 77", dut.regs[6], 32'd77);
        check_value("branch: fall-through writes x7 = 88", dut.regs[7], 32'd88);
        check_value("branch: x3 is not skipped value 99", (dut.regs[3] == 32'd99), 32'd0);
        finish_subtest();

        start_subtest("Jump control program");
        load_jump_control_program();
        run_loaded_program(90, 1'b0);
        check_value("jump: x0 remains zero", dut.regs[0], 32'd0);
        check_value("jump: x1 = 11", dut.regs[1], 32'd11);
        check_value("jump: JUMP skips x2 = 99", dut.regs[2], 32'd22);
        check_value("jump: x3 = 33", dut.regs[3], 32'd33);
        check_value("jump: JUMP skips x4 = 99", dut.regs[4], 32'd44);
        check_value("jump: x2 is not skipped value 99", (dut.regs[2] == 32'd99), 32'd0);
        check_value("jump: x4 is not skipped value 99", (dut.regs[4] == 32'd99), 32'd0);
        finish_subtest();

        start_subtest("Simple loop program");
        load_simple_loop_program();
        run_loaded_program(140, 1'b0);
        check_value("loop: x0 remains zero", dut.regs[0], 32'd0);
        check_value("loop: accumulator x1", dut.regs[1], 32'd3);
        check_value("loop: counter x2", dut.regs[2], 32'd0);
        check_value("loop: step x3", dut.regs[3], 32'd1);
        check_value("loop: data memory word 0", dut.data_mem[0], 32'd3);
        finish_subtest();

        start_subtest("Invalid opcode safety program");
        invalid_decode_count      = 0;
        invalid_bad_valid_count   = 0;
        invalid_reg_write_pulses  = 0;
        invalid_mem_write_pulses  = 0;
        load_invalid_opcode_program();
        run_loaded_program(80, 1'b1);
        check_value("invalid: x0 remains zero", dut.regs[0], 32'd0);
        check_value("invalid: valid instruction before invalid opcodes writes x1", dut.regs[1], 32'd10);
        check_value("invalid: valid instruction after invalid opcode writes x2", dut.regs[2], 32'd20);
        check_value("invalid: first invalid opcode does not write x3", dut.regs[3], 32'd0);
        check_value("invalid: second invalid opcode does not write x4", dut.regs[4], 32'd0);
        check_value("invalid: valid STORE after invalid opcodes writes memory", dut.data_mem[0], 32'd20);
        check_value("invalid: invalid opcode decode count", invalid_decode_count, 32'd2);
        check_value("invalid: invalid opcodes keep valid_instr low", invalid_bad_valid_count, 32'd0);
        check_value("invalid: invalid opcodes never assert reg_write", invalid_reg_write_pulses, 32'd0);
        check_value("invalid: invalid opcodes never assert mem_write", invalid_mem_write_pulses, 32'd0);
        finish_subtest();

        $display("");
        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 8F MULTI-CYCLE FULL-PROGRAM TEST FAILED");
            $fatal(1, "%0d of %0d Phase 8F full-program tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 8F MULTI-CYCLE FULL-PROGRAM TEST PASSED");
        $finish;
    end

endmodule
