`timescale 1ns / 1ps

module tb_cpu_core_multicycle_bram_prefetch_full_programs;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH_ADDR     = 3'd0;
    localparam logic [2:0] STATE_FETCH_CAPTURE  = 3'd1;
    localparam logic [2:0] STATE_DECODE         = 3'd2;
    localparam logic [2:0] STATE_EXECUTE        = 3'd3;
    localparam logic [2:0] STATE_MEMORY_ADDR    = 3'd4;
    localparam logic [2:0] STATE_MEMORY_CAPTURE = 3'd5;
    localparam logic [2:0] STATE_WRITEBACK      = 3'd6;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;

    localparam int unsigned PHASE10G_BASELINE_CYCLES = 271;
    localparam int unsigned PHASE10G_BASELINE_INSTR  = 58;

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
    int unsigned subtest_start_run;
    int unsigned subtest_start_failed;

    int unsigned cycles;
    int unsigned completed_instructions;
    int unsigned arithmetic_instructions;
    int unsigned load_instructions;
    int unsigned store_instructions;
    int unsigned branch_instructions;
    int unsigned jump_instructions;
    int unsigned nop_instructions;
    int unsigned invalid_instructions;

    int unsigned total_cycles;
    int unsigned total_completed_instructions;
    int unsigned total_arithmetic_instructions;
    int unsigned total_load_instructions;
    int unsigned total_store_instructions;
    int unsigned total_branch_instructions;
    int unsigned total_jump_instructions;
    int unsigned total_nop_instructions;
    int unsigned total_invalid_instructions;

    int unsigned invalid_bad_valid_count;
    int unsigned invalid_reg_write_pulses;
    int unsigned invalid_mem_write_pulses;
    int unsigned bad_reg_write_state_count;
    int unsigned bad_mem_write_state_count;
    int unsigned branch_jump_reg_write_pulses;
    int unsigned branch_jump_mem_write_pulses;

    string active_subtest;

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
                $error(
                    "FAIL: %s | expected=%0d got=%0d",
                    case_name,
                    expected,
                    actual
                );
            end else begin
                $display("PASS: %s | value=%0d", case_name, actual);
            end
        end
    endtask

    task automatic check_less_than(
        input string       case_name,
        input int unsigned actual,
        input int unsigned limit
    );
        begin
            tests_run++;

            if (actual >= limit) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected less than %0d got=%0d",
                    case_name,
                    limit,
                    actual
                );
            end else begin
                $display("PASS: %s | value=%0d, limit=%0d", case_name, actual, limit);
            end
        end
    endtask

    task automatic start_subtest(input string subtest_name);
        begin
            active_subtest       = subtest_name;
            subtest_start_run    = tests_run;
            subtest_start_failed = tests_failed;

            cycles                    = 0;
            completed_instructions    = 0;
            arithmetic_instructions   = 0;
            load_instructions         = 0;
            store_instructions        = 0;
            branch_instructions       = 0;
            jump_instructions         = 0;
            nop_instructions          = 0;
            invalid_instructions      = 0;
            invalid_bad_valid_count   = 0;
            invalid_reg_write_pulses  = 0;
            invalid_mem_write_pulses  = 0;
            bad_reg_write_state_count = 0;
            bad_mem_write_state_count = 0;
            branch_jump_reg_write_pulses = 0;
            branch_jump_mem_write_pulses = 0;

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

            total_cycles                 += cycles;
            total_completed_instructions += completed_instructions;
            total_arithmetic_instructions += arithmetic_instructions;
            total_load_instructions      += load_instructions;
            total_store_instructions     += store_instructions;
            total_branch_instructions    += branch_instructions;
            total_jump_instructions      += jump_instructions;
            total_nop_instructions       += nop_instructions;
            total_invalid_instructions   += invalid_instructions;

            $display(
                "%s performance: cycles=%0d completed=%0d CPI=%0.3f estimated MIPS @100MHz=%0.3f",
                active_subtest,
                cycles,
                completed_instructions,
                cpi_value(cycles, completed_instructions),
                mips_at_100mhz(cycles, completed_instructions)
            );
            $display(
                "%s summary: tests run=%0d, tests failed=%0d",
                active_subtest,
                subtest_runs,
                subtest_failures
            );
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

    task automatic record_completed_instruction(input logic [3:0] completed_opcode);
        begin
            completed_instructions++;

            if (opcode_is_arithmetic(completed_opcode)) begin
                arithmetic_instructions++;
            end else begin
                unique case (completed_opcode)
                    OP_LOAD: begin
                        load_instructions++;
                    end

                    OP_STORE: begin
                        store_instructions++;
                    end

                    OP_BEQ: begin
                        branch_instructions++;
                    end

                    OP_JUMP: begin
                        jump_instructions++;
                    end

                    OP_NOP: begin
                        nop_instructions++;
                    end

                    default: begin
                        invalid_instructions++;
                    end
                endcase
            end
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
                    record_completed_instruction(opcode_before);
                end else if ((state_before == STATE_MEMORY_ADDR) && (opcode_before == OP_STORE)) begin
                    record_completed_instruction(opcode_before);
                end else if ((state_before == STATE_EXECUTE) &&
                             ((opcode_before == OP_BEQ) || (opcode_before == OP_JUMP))) begin
                    record_completed_instruction(opcode_before);
                end else if (state_before == STATE_DECODE) begin
                    if ((instruction_before[31:28] == OP_NOP) ||
                        !opcode_is_valid(instruction_before[31:28])) begin
                        record_completed_instruction(instruction_before[31:28]);
                    end

                    if (!opcode_is_valid(instruction_before[31:28])) begin
                        if (valid_instr !== 1'b0) begin
                            invalid_bad_valid_count++;
                            $error("FAIL: invalid opcode produced valid_instr high");
                        end

                        if (reg_write) begin
                            invalid_reg_write_pulses++;
                            $error("FAIL: invalid opcode asserted reg_write");
                        end

                        if (mem_write) begin
                            invalid_mem_write_pulses++;
                            $error("FAIL: invalid opcode asserted mem_write");
                        end
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

            check_count(
                {active_subtest, ": completed instruction count"},
                completed_instructions,
                expected_completed
            );
        end
    endtask

    task automatic check_common_control_safety;
        begin
            check_count({active_subtest, ": reg_write only during WRITEBACK"}, bad_reg_write_state_count, 0);
            check_count({active_subtest, ": mem_write only during STORE MEMORY_ADDR"}, bad_mem_write_state_count, 0);
            check_count({active_subtest, ": BEQ/JUMP never assert reg_write"}, branch_jump_reg_write_pulses, 0);
            check_count({active_subtest, ": BEQ/JUMP never assert mem_write"}, branch_jump_mem_write_pulses, 0);
        end
    endtask

    task automatic check_instruction_counts(
        input int unsigned expected_arithmetic,
        input int unsigned expected_load,
        input int unsigned expected_store,
        input int unsigned expected_branch,
        input int unsigned expected_jump,
        input int unsigned expected_nop,
        input int unsigned expected_invalid
    );
        begin
            check_count({active_subtest, ": arithmetic instruction count"}, arithmetic_instructions, expected_arithmetic);
            check_count({active_subtest, ": LOAD instruction count"}, load_instructions, expected_load);
            check_count({active_subtest, ": STORE instruction count"}, store_instructions, expected_store);
            check_count({active_subtest, ": BEQ instruction count"}, branch_instructions, expected_branch);
            check_count({active_subtest, ": JUMP instruction count"}, jump_instructions, expected_jump);
            check_count({active_subtest, ": NOP instruction count"}, nop_instructions, expected_nop);
            check_count({active_subtest, ": invalid instruction count"}, invalid_instructions, expected_invalid);
        end
    endtask

    task automatic load_arithmetic_edge_program;
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

    task automatic load_memory_offset_program;
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

    task automatic load_branch_control_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0]  = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd5);
            dut.instr_mem_inst.mem[1]  = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd5);
            dut.instr_mem_inst.mem[2]  = build_instruction(OP_BEQ,  5'd0, 5'd1, 5'd2, 13'd2);
            dut.instr_mem_inst.mem[3]  = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd99);
            dut.instr_mem_inst.mem[4]  = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd42);
            dut.instr_mem_inst.mem[5]  = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd1);
            dut.instr_mem_inst.mem[6]  = build_instruction(OP_ADDI, 5'd5, 5'd0, 5'd0, 13'd2);
            dut.instr_mem_inst.mem[7]  = build_instruction(OP_BEQ,  5'd0, 5'd4, 5'd5, 13'd2);
            dut.instr_mem_inst.mem[8]  = build_instruction(OP_ADDI, 5'd6, 5'd0, 5'd0, 13'd77);
            dut.instr_mem_inst.mem[9]  = build_instruction(OP_ADDI, 5'd7, 5'd0, 5'd0, 13'd88);
            dut.instr_mem_inst.mem[10] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_jump_control_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0] = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd11);
            dut.instr_mem_inst.mem[1] = build_instruction(OP_JUMP, 5'd0, 5'd0, 5'd0, 13'd2);
            dut.instr_mem_inst.mem[2] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd99);
            dut.instr_mem_inst.mem[3] = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd22);
            dut.instr_mem_inst.mem[4] = build_instruction(OP_ADDI, 5'd3, 5'd0, 5'd0, 13'd33);
            dut.instr_mem_inst.mem[5] = build_instruction(OP_JUMP, 5'd0, 5'd0, 5'd0, 13'd2);
            dut.instr_mem_inst.mem[6] = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd99);
            dut.instr_mem_inst.mem[7] = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd44);
            dut.instr_mem_inst.mem[8] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_simple_loop_program;
        begin
            clear_memories();

            dut.instr_mem_inst.mem[0] = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd0);
            dut.instr_mem_inst.mem[1] = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd3);
            dut.instr_mem_inst.mem[2] = build_instruction(OP_ADDI,  5'd3, 5'd0, 5'd0, 13'd1);
            dut.instr_mem_inst.mem[3] = build_instruction(OP_ADD,   5'd1, 5'd1, 5'd3, 13'd0);
            dut.instr_mem_inst.mem[4] = build_instruction(OP_SUB,   5'd2, 5'd2, 5'd3, 13'd0);
            dut.instr_mem_inst.mem[5] = build_instruction(OP_BEQ,   5'd0, 5'd2, 5'd0, 13'd2);
            dut.instr_mem_inst.mem[6] = build_instruction(OP_JUMP,  5'd0, 5'd0, 5'd0, 13'h1ffd);
            dut.instr_mem_inst.mem[7] = build_instruction(OP_STORE, 5'd0, 5'd0, 5'd1, 13'd0);
            dut.instr_mem_inst.mem[8] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_invalid_opcode_program;
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
        $dumpfile("tb_cpu_core_multicycle_bram_prefetch_full_programs.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_bram_prefetch_full_programs);

        $display("Starting Phase 11B BRAM-aware prefetch CPU full custom-ISA verification...");

        rst                          = 1'b1;
        enable                       = 1'b0;
        tests_run                    = 0;
        tests_failed                 = 0;
        subtest_start_run            = 0;
        subtest_start_failed         = 0;
        total_cycles                 = 0;
        total_completed_instructions = 0;
        total_arithmetic_instructions = 0;
        total_load_instructions      = 0;
        total_store_instructions     = 0;
        total_branch_instructions    = 0;
        total_jump_instructions      = 0;
        total_nop_instructions       = 0;
        total_invalid_instructions   = 0;
        active_subtest               = "";

        start_subtest("Prefetch arithmetic edge program");
        load_arithmetic_edge_program();
        reset_and_run_loaded_program(10, 80);
        check_value("arithmetic: x0 remains zero", dut.regs[0], 32'd0);
        check_value("arithmetic: ADDI x1, x0, -1", dut.regs[1], 32'hffff_ffff);
        check_value("arithmetic: ADDI x2, x0, 1", dut.regs[2], 32'd1);
        check_value("arithmetic: ADD wraparound x3", dut.regs[3], 32'h0000_0000);
        check_value("arithmetic: SUB underflow x4", dut.regs[4], 32'hffff_ffff);
        check_value("arithmetic: ADDI x5, x0, 10", dut.regs[5], 32'd10);
        check_value("arithmetic: ADDI x6, x0, 20", dut.regs[6], 32'd20);
        check_value("arithmetic: ADD x7, x5, x6", dut.regs[7], 32'd30);
        check_value("arithmetic: SUB x8, x6, x5", dut.regs[8], 32'd10);
        check_common_control_safety();
        check_instruction_counts(9, 0, 0, 0, 0, 1, 0);
        check_less_than("arithmetic: cycle count below Phase 10G baseline", cycles, 48);
        finish_subtest();

        start_subtest("Prefetch memory offset program");
        load_memory_offset_program();
        reset_and_run_loaded_program(9, 90);
        check_value("memory: x0 remains zero", dut.regs[0], 32'd0);
        check_value("memory: base address x1", dut.regs[1], 32'd64);
        check_value("memory: stored value x2", dut.regs[2], 32'd123);
        check_value("memory: load [base + 0] into x3", dut.regs[3], 32'd123);
        check_value("memory: load [base + 4] into x4", dut.regs[4], 32'd123);
        check_value("memory: alternate base x5", dut.regs[5], 32'd68);
        check_value("memory: load [x5 - 4] into x6", dut.regs[6], 32'd123);
        check_value("memory: BRAM data word 16", dut.data_mem_inst.mem[16], 32'd123);
        check_value("memory: BRAM data word 17", dut.data_mem_inst.mem[17], 32'd123);
        check_common_control_safety();
        check_instruction_counts(3, 3, 2, 0, 0, 1, 0);
        check_less_than("memory: cycle count below Phase 10G baseline", cycles, 49);
        finish_subtest();

        start_subtest("Prefetch branch control program");
        load_branch_control_program();
        reset_and_run_loaded_program(10, 90);
        check_value("branch: x0 remains zero", dut.regs[0], 32'd0);
        check_value("branch: x1 = 5", dut.regs[1], 32'd5);
        check_value("branch: x2 = 5", dut.regs[2], 32'd5);
        check_value("branch: taken BEQ skips x3 = 99", dut.regs[3], 32'd42);
        check_value("branch: x4 = 1", dut.regs[4], 32'd1);
        check_value("branch: x5 = 2", dut.regs[5], 32'd2);
        check_value("branch: not-taken BEQ executes x6 = 77", dut.regs[6], 32'd77);
        check_value("branch: fall-through writes x7 = 88", dut.regs[7], 32'd88);
        check_value("branch: x3 is not wrong prefetched value 99", (dut.regs[3] == 32'd99), 32'd0);
        check_common_control_safety();
        check_instruction_counts(7, 0, 0, 2, 0, 1, 0);
        check_less_than("branch: cycle count below Phase 10G baseline", cycles, 46);
        finish_subtest();

        start_subtest("Prefetch jump control program");
        load_jump_control_program();
        reset_and_run_loaded_program(7, 70);
        check_value("jump: x0 remains zero", dut.regs[0], 32'd0);
        check_value("jump: x1 = 11", dut.regs[1], 32'd11);
        check_value("jump: JUMP skips x2 = 99", dut.regs[2], 32'd22);
        check_value("jump: x3 = 33", dut.regs[3], 32'd33);
        check_value("jump: JUMP skips x4 = 99", dut.regs[4], 32'd44);
        check_value("jump: x2 is not wrong prefetched value 99", (dut.regs[2] == 32'd99), 32'd0);
        check_value("jump: x4 is not wrong prefetched value 99", (dut.regs[4] == 32'd99), 32'd0);
        check_common_control_safety();
        check_instruction_counts(4, 0, 0, 0, 2, 1, 0);
        check_less_than("jump: cycle count below Phase 10G baseline", cycles, 31);
        finish_subtest();

        start_subtest("Prefetch simple loop program");
        load_simple_loop_program();
        reset_and_run_loaded_program(16, 130);
        check_value("loop: x0 remains zero", dut.regs[0], 32'd0);
        check_value("loop: accumulator x1", dut.regs[1], 32'd3);
        check_value("loop: counter x2", dut.regs[2], 32'd0);
        check_value("loop: step x3", dut.regs[3], 32'd1);
        check_value("loop: BRAM data memory word 0", dut.data_mem_inst.mem[0], 32'd3);
        check_common_control_safety();
        check_instruction_counts(9, 0, 1, 3, 2, 1, 0);
        check_less_than("loop: cycle count below Phase 10G baseline", cycles, 73);
        finish_subtest();

        start_subtest("Prefetch invalid opcode safety program");
        load_invalid_opcode_program();
        reset_and_run_loaded_program(6, 60);
        check_value("invalid: x0 remains zero", dut.regs[0], 32'd0);
        check_value("invalid: valid instruction before invalid opcodes writes x1", dut.regs[1], 32'd10);
        check_value("invalid: valid instruction after invalid opcode writes x2", dut.regs[2], 32'd20);
        check_value("invalid: first invalid opcode does not write x3", dut.regs[3], 32'd0);
        check_value("invalid: second invalid opcode does not write x4", dut.regs[4], 32'd0);
        check_value("invalid: valid STORE after invalid opcodes writes BRAM memory", dut.data_mem_inst.mem[0], 32'd20);
        check_common_control_safety();
        check_count("invalid: invalid opcodes keep valid_instr low", invalid_bad_valid_count, 0);
        check_count("invalid: invalid opcodes never assert reg_write", invalid_reg_write_pulses, 0);
        check_count("invalid: invalid opcodes never assert mem_write", invalid_mem_write_pulses, 0);
        check_instruction_counts(2, 0, 1, 0, 0, 1, 2);
        check_less_than("invalid: cycle count below Phase 10G baseline", cycles, 24);
        finish_subtest();

        $display("");
        $display("Aggregate Phase 11B performance:");
        $display("  cycles:                 %0d", total_cycles);
        $display("  completed instructions: %0d", total_completed_instructions);
        $display("  arithmetic:             %0d", total_arithmetic_instructions);
        $display("  LOAD:                   %0d", total_load_instructions);
        $display("  STORE:                  %0d", total_store_instructions);
        $display("  BEQ:                    %0d", total_branch_instructions);
        $display("  JUMP:                   %0d", total_jump_instructions);
        $display("  NOP:                    %0d", total_nop_instructions);
        $display("  invalid:                %0d", total_invalid_instructions);
        $display("  CPI:                    %0.3f", cpi_value(total_cycles, total_completed_instructions));
        $display("  estimated MIPS @100MHz: %0.3f", mips_at_100mhz(total_cycles, total_completed_instructions));
        $display("Phase 10G BRAM-aware baseline: cycles=%0d instructions=%0d CPI=4.672 MIPS @100MHz=21.402",
                 PHASE10G_BASELINE_CYCLES,
                 PHASE10G_BASELINE_INSTR);

        check_count("aggregate: completed instruction count", total_completed_instructions, 58);
        check_count("aggregate: arithmetic instruction count", total_arithmetic_instructions, 34);
        check_count("aggregate: LOAD instruction count", total_load_instructions, 3);
        check_count("aggregate: STORE instruction count", total_store_instructions, 4);
        check_count("aggregate: BEQ instruction count", total_branch_instructions, 5);
        check_count("aggregate: JUMP instruction count", total_jump_instructions, 4);
        check_count("aggregate: NOP instruction count", total_nop_instructions, 6);
        check_count("aggregate: invalid instruction count", total_invalid_instructions, 2);
        check_less_than("aggregate: total active cycles below Phase 10G baseline", total_cycles, PHASE10G_BASELINE_CYCLES);

        $display("");
        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 11B BRAM PREFETCH FULL-PROGRAM TEST FAILED");
            $fatal(1, "%0d of %0d Phase 11B tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 11B BRAM PREFETCH FULL-PROGRAM TEST PASSED");
        $finish;
    end

endmodule
