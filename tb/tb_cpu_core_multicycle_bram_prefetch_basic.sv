`timescale 1ns / 1ps

module tb_cpu_core_multicycle_bram_prefetch_basic;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH_ADDR     = 3'd0;
    localparam logic [2:0] STATE_DECODE         = 3'd2;
    localparam logic [2:0] STATE_EXECUTE        = 3'd3;
    localparam logic [2:0] STATE_MEMORY_ADDR    = 3'd4;
    localparam logic [2:0] STATE_WRITEBACK      = 3'd6;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;

    logic        clk;
    logic        rst;
    logic        enable;
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
    logic [31:0] instruction_addr;
    logic [31:0] data_addr;
    logic        prefetch_valid;
    logic [31:0] prefetch_pc;
    logic [31:0] prefetch_instruction;

    int unsigned tests_run;
    int unsigned tests_failed;
    int unsigned cycles;
    int unsigned completed_instructions;
    int unsigned bad_reg_write_state_count;
    int unsigned bad_mem_write_state_count;
    int unsigned branch_jump_reg_write_pulses;
    int unsigned branch_jump_mem_write_pulses;

    int unsigned arithmetic_cycles;
    int unsigned arithmetic_completed;

    cpu_core_multicycle_bram_prefetch #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
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
        .memory_read_data(memory_read_data),
        .instruction_addr(instruction_addr),
        .data_addr(data_addr),
        .prefetch_valid(prefetch_valid),
        .prefetch_pc(prefetch_pc),
        .prefetch_instruction(prefetch_instruction)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] build_instruction(
        input logic [3:0]  build_opcode,
        input logic [4:0]  build_rd,
        input logic [4:0]  build_rs1,
        input logic [4:0]  build_rs2,
        input logic [12:0] build_imm13
    );
        begin
            build_instruction = {
                build_opcode,
                build_rd,
                build_rs1,
                build_rs2,
                build_imm13
            };
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

    function automatic logic opcode_is_arithmetic(input logic [3:0] opcode);
        begin
            unique case (opcode)
                OP_ADD,
                OP_SUB,
                OP_AND,
                OP_OR,
                OP_XOR,
                OP_ADDI: opcode_is_arithmetic = 1'b1;
                default: opcode_is_arithmetic = 1'b0;
            endcase
        end
    endfunction

    function automatic real cpi_value(
        input int unsigned cycle_count,
        input int unsigned instruction_count
    );
        begin
            if (instruction_count == 0) begin
                cpi_value = 0.0;
            end else begin
                cpi_value = real'(cycle_count) / real'(instruction_count);
            end
        end
    endfunction

    function automatic real mips_at_100mhz(
        input int unsigned cycle_count,
        input int unsigned instruction_count
    );
        real cpi;
        begin
            cpi = cpi_value(cycle_count, instruction_count);

            if (cpi == 0.0) begin
                mips_at_100mhz = 0.0;
            end else begin
                mips_at_100mhz = 100.0 / cpi;
            end
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

    task automatic check_count(
        input string       case_name,
        input int unsigned actual,
        input int unsigned expected
    );
        begin
            tests_run++;

            if (actual != expected) begin
                tests_failed++;
                $error("FAIL: %s | expected=%0d got=%0d", case_name, expected, actual);
            end else begin
                $display("PASS: %s | value=%0d", case_name, actual);
            end
        end
    endtask

    task automatic clear_memories;
        int unsigned i;
        begin
            for (i = 0; i < IMEM_DEPTH; i++) begin
                dut.instr_mem_inst.mem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            end

            for (i = 0; i < DMEM_DEPTH; i++) begin
                dut.data_mem_inst.mem[i] = 32'h0000_0000;
            end
        end
    endtask

    task automatic reset_counters;
        begin
            cycles                       = 0;
            completed_instructions       = 0;
            bad_reg_write_state_count    = 0;
            bad_mem_write_state_count    = 0;
            branch_jump_reg_write_pulses = 0;
            branch_jump_mem_write_pulses = 0;
        end
    endtask

    task automatic step_and_monitor;
        logic [2:0]  state_before;
        logic [3:0]  opcode_before;
        logic [31:0] instruction_before;
        begin
            state_before       = state;
            opcode_before      = opcode_reg;
            instruction_before = instruction_reg;

            if (!rst && enable) begin
                if (reg_write && (state != STATE_WRITEBACK)) begin
                    bad_reg_write_state_count++;
                    $error("FAIL: reg_write asserted outside WRITEBACK");
                end

                if (mem_write && !((state == STATE_MEMORY_ADDR) && (opcode_reg == OP_STORE))) begin
                    bad_mem_write_state_count++;
                    $error("FAIL: mem_write asserted outside STORE MEMORY_ADDR");
                end

                if ((opcode_reg == OP_BEQ) || (opcode_reg == OP_JUMP)) begin
                    if (reg_write) begin
                        branch_jump_reg_write_pulses++;
                        $error("FAIL: BEQ/JUMP asserted reg_write");
                    end

                    if (mem_write) begin
                        branch_jump_mem_write_pulses++;
                        $error("FAIL: BEQ/JUMP asserted mem_write");
                    end
                end
            end

            @(posedge clk);
            #1;

            if (!rst && enable) begin
                cycles++;

                if ((state_before == STATE_WRITEBACK) &&
                    (opcode_is_arithmetic(opcode_before) || (opcode_before == OP_LOAD))) begin
                    completed_instructions++;
                end else if ((state_before == STATE_MEMORY_ADDR) && (opcode_before == OP_STORE)) begin
                    completed_instructions++;
                end else if ((state_before == STATE_EXECUTE) &&
                             ((opcode_before == OP_BEQ) || (opcode_before == OP_JUMP))) begin
                    completed_instructions++;
                end else if (state_before == STATE_DECODE) begin
                    if ((instruction_before[31:28] == OP_NOP) ||
                        !opcode_is_valid(instruction_before[31:28])) begin
                        completed_instructions++;
                    end
                end
            end
        end
    endtask

    task automatic reset_and_run_loaded_program(
        input int unsigned expected_completed,
        input int unsigned max_cycles
    );
        begin
            reset_counters();
            rst    = 1'b1;
            enable = 1'b0;

            @(posedge clk);
            #1;

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            while ((completed_instructions < expected_completed) && (cycles < max_cycles)) begin
                step_and_monitor();
            end

            @(negedge clk);
            enable = 1'b0;
            #1;

            check_count("completed instruction count", completed_instructions, expected_completed);
        end
    endtask

    task automatic load_arithmetic_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0] = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'h1fff);
            dut.instr_mem_inst.mem[1] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd1);
            dut.instr_mem_inst.mem[2] = build_instruction(OP_ADD,  5'd3, 5'd1, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[3] = build_instruction(OP_SUB,  5'd4, 5'd0, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[4] = build_instruction(OP_ADDI, 5'd5, 5'd0, 5'd0, 13'd10);
            dut.instr_mem_inst.mem[5] = build_instruction(OP_ADDI, 5'd6, 5'd0, 5'd0, 13'd20);
            dut.instr_mem_inst.mem[6] = build_instruction(OP_ADD,  5'd7, 5'd5, 5'd6, 13'd0);
            dut.instr_mem_inst.mem[7] = build_instruction(OP_SUB,  5'd8, 5'd6, 5'd5, 13'd0);
            dut.instr_mem_inst.mem[8] = build_instruction(OP_ADDI, 5'd0, 5'd0, 5'd0, 13'd123);
            dut.instr_mem_inst.mem[9] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_memory_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0] = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd64);
            dut.instr_mem_inst.mem[1] = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd123);
            dut.instr_mem_inst.mem[2] = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[3] = build_instruction(OP_LOAD,  5'd3, 5'd1, 5'd0, 13'd0);
            dut.instr_mem_inst.mem[4] = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd3, 13'd4);
            dut.instr_mem_inst.mem[5] = build_instruction(OP_LOAD,  5'd4, 5'd1, 5'd0, 13'd4);
            dut.instr_mem_inst.mem[6] = build_instruction(OP_ADDI,  5'd5, 5'd0, 5'd0, 13'd68);
            dut.instr_mem_inst.mem[7] = build_instruction(OP_LOAD,  5'd6, 5'd5, 5'd0, 13'h1ffc);
            dut.instr_mem_inst.mem[8] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_control_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0]  = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd5);
            dut.instr_mem_inst.mem[1]  = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd5);
            dut.instr_mem_inst.mem[2]  = build_instruction(OP_BEQ,  5'd0, 5'd1, 5'd2, 13'd2);
            dut.instr_mem_inst.mem[3]  = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd99);
            dut.instr_mem_inst.mem[4]  = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd42);
            dut.instr_mem_inst.mem[5]  = build_instruction(OP_JUMP, 5'd0, 5'd0, 5'd0, 13'd2);
            dut.instr_mem_inst.mem[6]  = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd99);
            dut.instr_mem_inst.mem[7]  = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd77);
            dut.instr_mem_inst.mem[8]  = build_instruction(OP_ADDI, 5'd5, 5'd0, 5'd0, 13'd1);
            dut.instr_mem_inst.mem[9]  = build_instruction(OP_ADDI, 5'd6, 5'd0, 5'd0, 13'd2);
            dut.instr_mem_inst.mem[10] = build_instruction(OP_BEQ,  5'd0, 5'd5, 5'd6, 13'd2);
            dut.instr_mem_inst.mem[11] = build_instruction(OP_ADDI, 5'd7, 5'd0, 5'd0, 13'd55);
            dut.instr_mem_inst.mem[12] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_invalid_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0] = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd10);
            dut.instr_mem_inst.mem[1] = build_instruction(4'hb,     5'd3, 5'd0, 5'd0, 13'd111);
            dut.instr_mem_inst.mem[2] = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd20);
            dut.instr_mem_inst.mem[3] = build_instruction(4'hf,     5'd4, 5'd0, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[4] = build_instruction(OP_STORE, 5'd0, 5'd0, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[5] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_bram_prefetch_basic.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_bram_prefetch_basic);

        $display("Starting Phase 11A BRAM-aware prefetch CPU basic simulation...");

        rst                          = 1'b1;
        enable                       = 1'b0;
        tests_run                    = 0;
        tests_failed                 = 0;
        arithmetic_cycles            = 0;
        arithmetic_completed         = 0;

        clear_memories();

        @(posedge clk);
        #1;
        check_value("reset state is FETCH_ADDR", {29'd0, state}, {29'd0, STATE_FETCH_ADDR});
        check_value("reset PC is zero", pc, 32'h0000_0000);
        check_value("reset prefetch_valid is low", {31'd0, prefetch_valid}, 32'd0);
        check_value("reset x0 is zero", dut.regs[0], 32'd0);

        $display("");
        $display("---- Sequential arithmetic prefetch benchmark ----");
        load_arithmetic_program();
        reset_and_run_loaded_program(10, 70);
        arithmetic_cycles    = cycles;
        arithmetic_completed = completed_instructions;
        check_value("arithmetic: x0 remains zero", dut.regs[0], 32'd0);
        check_value("arithmetic: ADDI x1, x0, -1", dut.regs[1], 32'hffff_ffff);
        check_value("arithmetic: ADDI x2, x0, 1", dut.regs[2], 32'd1);
        check_value("arithmetic: ADD wraparound x3", dut.regs[3], 32'h0000_0000);
        check_value("arithmetic: SUB underflow x4", dut.regs[4], 32'hffff_ffff);
        check_value("arithmetic: ADDI x5, x0, 10", dut.regs[5], 32'd10);
        check_value("arithmetic: ADDI x6, x0, 20", dut.regs[6], 32'd20);
        check_value("arithmetic: ADD x7, x5, x6", dut.regs[7], 32'd30);
        check_value("arithmetic: SUB x8, x6, x5", dut.regs[8], 32'd10);
        check_count("arithmetic: prefetch cycle count", arithmetic_cycles, 30);
        check_count("arithmetic: below Phase 10G BRAM baseline cycle count", (arithmetic_cycles < 48), 1);
        check_count("arithmetic: reg_write only during WRITEBACK", bad_reg_write_state_count, 0);
        check_count("arithmetic: mem_write only during STORE MEMORY_ADDR", bad_mem_write_state_count, 0);
        $display(
            "PREFETCH BENCHMARK: cycles=%0d completed=%0d CPI=%0.3f estimated MIPS @100MHz=%0.3f",
            arithmetic_cycles,
            arithmetic_completed,
            cpi_value(arithmetic_cycles, arithmetic_completed),
            mips_at_100mhz(arithmetic_cycles, arithmetic_completed)
        );
        $display("PHASE 10G matching BRAM arithmetic baseline: cycles=48 completed=10 CPI=4.800 MIPS=20.833");

        $display("");
        $display("---- LOAD/STORE with prefetch ----");
        load_memory_program();
        reset_and_run_loaded_program(9, 80);
        check_value("memory: x0 remains zero", dut.regs[0], 32'd0);
        check_value("memory: base address x1", dut.regs[1], 32'd64);
        check_value("memory: stored value x2", dut.regs[2], 32'd123);
        check_value("memory: load [base + 0] into x3", dut.regs[3], 32'd123);
        check_value("memory: load [base + 4] into x4", dut.regs[4], 32'd123);
        check_value("memory: alternate base x5", dut.regs[5], 32'd68);
        check_value("memory: load [x5 - 4] into x6", dut.regs[6], 32'd123);
        check_value("memory: BRAM data word 16", dut.data_mem_inst.mem[16], 32'd123);
        check_value("memory: BRAM data word 17", dut.data_mem_inst.mem[17], 32'd123);
        check_count("memory: reg_write only during WRITEBACK", bad_reg_write_state_count, 0);
        check_count("memory: mem_write only during STORE MEMORY_ADDR", bad_mem_write_state_count, 0);

        $display("");
        $display("---- BEQ/JUMP prefetch invalidation ----");
        load_control_program();
        reset_and_run_loaded_program(11, 100);
        check_value("control: x0 remains zero", dut.regs[0], 32'd0);
        check_value("control: x1 = 5", dut.regs[1], 32'd5);
        check_value("control: x2 = 5", dut.regs[2], 32'd5);
        check_value("control: taken BEQ skips x3 = 99", dut.regs[3], 32'd42);
        check_value("control: JUMP skips x4 = 99", dut.regs[4], 32'd77);
        check_value("control: x5 = 1", dut.regs[5], 32'd1);
        check_value("control: x6 = 2", dut.regs[6], 32'd2);
        check_value("control: not-taken BEQ executes x7 = 55", dut.regs[7], 32'd55);
        check_value("control: x3 is not wrong prefetched value 99", (dut.regs[3] == 32'd99), 32'd0);
        check_value("control: x4 is not wrong prefetched value 99", (dut.regs[4] == 32'd99), 32'd0);
        check_count("control: BEQ/JUMP never assert reg_write", branch_jump_reg_write_pulses, 0);
        check_count("control: BEQ/JUMP never assert mem_write", branch_jump_mem_write_pulses, 0);

        $display("");
        $display("---- Invalid opcode safety with prefetch ----");
        load_invalid_program();
        reset_and_run_loaded_program(6, 60);
        check_value("invalid: x0 remains zero", dut.regs[0], 32'd0);
        check_value("invalid: valid instruction before invalid opcodes writes x1", dut.regs[1], 32'd10);
        check_value("invalid: valid instruction after invalid opcode writes x2", dut.regs[2], 32'd20);
        check_value("invalid: first invalid opcode does not write x3", dut.regs[3], 32'd0);
        check_value("invalid: second invalid opcode does not write x4", dut.regs[4], 32'd0);
        check_value("invalid: valid STORE after invalid opcodes writes memory", dut.data_mem_inst.mem[0], 32'd20);
        check_count("invalid: reg_write only during WRITEBACK", bad_reg_write_state_count, 0);
        check_count("invalid: mem_write only during STORE MEMORY_ADDR", bad_mem_write_state_count, 0);

        $display("");
        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 11A BRAM PREFETCH BASIC TEST FAILED");
            $fatal(1, "%0d of %0d Phase 11A tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 11A BRAM PREFETCH BASIC TEST PASSED");
        $finish;
    end

endmodule
