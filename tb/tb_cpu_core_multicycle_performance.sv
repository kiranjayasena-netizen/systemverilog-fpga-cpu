`timescale 1ns / 1ps

module tb_cpu_core_multicycle_performance;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH     = 3'd0;
    localparam logic [2:0] STATE_DECODE    = 3'd1;
    localparam logic [2:0] STATE_EXECUTE   = 3'd2;
    localparam logic [2:0] STATE_MEMORY    = 3'd3;
    localparam logic [2:0] STATE_WRITEBACK = 3'd4;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam real CLOCK_PERIOD_NS = 10.0;
    localparam real CLOCK_FREQ_MHZ = 100.0;

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

    int unsigned cycles;
    int unsigned completed_instructions;
    int unsigned arithmetic_instructions;
    int unsigned load_instructions;
    int unsigned store_instructions;
    int unsigned branch_instructions;
    int unsigned jump_instructions;
    int unsigned nop_instructions;
    int unsigned invalid_instructions;

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

    task automatic clear_imem;
        int unsigned i;
        begin
            for (i = 0; i < IMEM_DEPTH; i++) begin
                imem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            end
        end
    endtask

    task automatic reset_benchmark_counters;
        begin
            cycles                  = 0;
            completed_instructions  = 0;
            arithmetic_instructions = 0;
            load_instructions       = 0;
            store_instructions      = 0;
            branch_instructions     = 0;
            jump_instructions       = 0;
            nop_instructions        = 0;
            invalid_instructions    = 0;
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

    task automatic step_and_count;
        logic [2:0]  state_before;
        logic [3:0]  opcode_before;
        logic [31:0] instruction_before;
        begin
            state_before       = state;
            opcode_before      = opcode_reg;
            instruction_before = instruction_reg;

            @(posedge clk);
            #1;

            if (!rst && enable) begin
                cycles++;

                if ((state_before == STATE_WRITEBACK) &&
                    (opcode_is_arithmetic(opcode_before) || (opcode_before == OP_LOAD))) begin
                    record_completed_instruction(opcode_before);
                end else if ((state_before == STATE_MEMORY) && (opcode_before == OP_STORE)) begin
                    record_completed_instruction(opcode_before);
                end else if ((state_before == STATE_EXECUTE) &&
                             ((opcode_before == OP_BEQ) || (opcode_before == OP_JUMP))) begin
                    record_completed_instruction(opcode_before);
                end else if (state_before == STATE_DECODE) begin
                    if ((instruction_before[31:28] == OP_NOP) ||
                        !opcode_is_valid(instruction_before[31:28])) begin
                        record_completed_instruction(instruction_before[31:28]);
                    end
                end
            end
        end
    endtask

    task automatic print_benchmark_result(input string benchmark_name);
        real cpi;
        real estimated_mips;
        real runtime_ns;
        begin
            cpi            = $itor(cycles) / $itor(completed_instructions);
            estimated_mips = CLOCK_FREQ_MHZ / cpi;
            runtime_ns     = $itor(cycles) * CLOCK_PERIOD_NS;

            $display("");
            $display("BENCHMARK RESULT: %s", benchmark_name);
            $display("  Cycles:                 %0d", cycles);
            $display("  Completed instructions: %0d", completed_instructions);
            $display("  Arithmetic instructions:%0d", arithmetic_instructions);
            $display("  Load instructions:      %0d", load_instructions);
            $display("  Store instructions:     %0d", store_instructions);
            $display("  Branch instructions:    %0d", branch_instructions);
            $display("  Jump instructions:      %0d", jump_instructions);
            $display("  NOP instructions:       %0d", nop_instructions);
            $display("  Invalid instructions:   %0d", invalid_instructions);
            $display("  CPI:                    %0.3f", cpi);
            $display("  Estimated MIPS @100MHz: %0.3f", estimated_mips);
            $display("  Estimated runtime:      %0.1f ns", runtime_ns);
        end
    endtask

    task automatic run_loaded_benchmark(
        input string       benchmark_name,
        input int unsigned expected_completed,
        input int unsigned max_cycles
    );
        begin
            reset_benchmark_counters();

            rst    = 1'b1;
            enable = 1'b0;

            @(posedge clk);
            #1;

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            while ((completed_instructions < expected_completed) && (cycles < max_cycles)) begin
                step_and_count();
            end

            @(negedge clk);
            enable = 1'b0;
            #1;

            print_benchmark_result(benchmark_name);
            check_value({benchmark_name, ": completed instruction count"}, completed_instructions, expected_completed);
            check_value({benchmark_name, ": benchmark completed before max cycle limit"}, (cycles < max_cycles), 32'd1);
        end
    endtask

    task automatic load_arithmetic_heavy_program;
        begin
            clear_imem();

            imem[0]  = build_instruction(OP_ADDI, 5'd1,  5'd0, 5'd0, 13'd10);
            imem[1]  = build_instruction(OP_ADDI, 5'd2,  5'd0, 5'd0, 13'd3);
            imem[2]  = build_instruction(OP_ADD,  5'd3,  5'd1, 5'd2, 13'd0);
            imem[3]  = build_instruction(OP_SUB,  5'd4,  5'd1, 5'd2, 13'd0);
            imem[4]  = build_instruction(OP_AND,  5'd5,  5'd1, 5'd2, 13'd0);
            imem[5]  = build_instruction(OP_OR,   5'd6,  5'd1, 5'd2, 13'd0);
            imem[6]  = build_instruction(OP_XOR,  5'd7,  5'd1, 5'd2, 13'd0);
            imem[7]  = build_instruction(OP_ADDI, 5'd8,  5'd7, 5'd0, 13'h1fff);
            imem[8]  = build_instruction(OP_ADD,  5'd9,  5'd8, 5'd3, 13'd0);
            imem[9]  = build_instruction(OP_SUB,  5'd10, 5'd9, 5'd1, 13'd0);
            imem[10] = build_instruction(OP_NOP,  5'd0,  5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_memory_heavy_program;
        begin
            clear_imem();

            imem[0]  = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd64);
            imem[1]  = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd100);
            imem[2]  = build_instruction(OP_ADDI,  5'd3, 5'd0, 5'd0, 13'd200);
            imem[3]  = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd2, 13'd0);
            imem[4]  = build_instruction(OP_LOAD,  5'd4, 5'd1, 5'd0, 13'd0);
            imem[5]  = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd3, 13'd4);
            imem[6]  = build_instruction(OP_LOAD,  5'd5, 5'd1, 5'd0, 13'd4);
            imem[7]  = build_instruction(OP_ADDI,  5'd6, 5'd0, 5'd0, 13'd68);
            imem[8]  = build_instruction(OP_LOAD,  5'd7, 5'd6, 5'd0, 13'h1ffc);
            imem[9]  = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd7, 13'd8);
            imem[10] = build_instruction(OP_LOAD,  5'd8, 5'd1, 5'd0, 13'd8);
            imem[11] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_branch_jump_program;
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
            imem[9]  = build_instruction(OP_JUMP, 5'd0, 5'd0, 5'd0, 13'd2);
            imem[10] = build_instruction(OP_ADDI, 5'd7, 5'd0, 5'd0, 13'd99);
            imem[11] = build_instruction(OP_ADDI, 5'd7, 5'd0, 5'd0, 13'd88);
            imem[12] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic load_simple_loop_program;
        begin
            clear_imem();

            imem[0] = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd0);
            imem[1] = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd4);
            imem[2] = build_instruction(OP_ADDI,  5'd3, 5'd0, 5'd0, 13'd1);
            imem[3] = build_instruction(OP_ADD,   5'd1, 5'd1, 5'd3, 13'd0);
            imem[4] = build_instruction(OP_SUB,   5'd2, 5'd2, 5'd3, 13'd0);
            imem[5] = build_instruction(OP_BEQ,   5'd0, 5'd2, 5'd0, 13'd2);
            imem[6] = build_instruction(OP_JUMP,  5'd0, 5'd0, 5'd0, 13'h1ffd);
            imem[7] = build_instruction(OP_STORE, 5'd0, 5'd0, 5'd1, 13'd0);
            imem[8] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_performance.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_performance);

        $display("Starting Phase 10A multi-cycle CPU performance benchmarking...");

        rst          = 1'b1;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;
        reset_benchmark_counters();

        load_arithmetic_heavy_program();
        run_loaded_benchmark("Arithmetic-heavy program", 11, 80);
        check_value("arithmetic benchmark: x3 = 13", dut.regs[3], 32'd13);
        check_value("arithmetic benchmark: x10 = 11", dut.regs[10], 32'd11);
        check_value("arithmetic benchmark: arithmetic count", arithmetic_instructions, 32'd10);
        check_value("arithmetic benchmark: NOP count", nop_instructions, 32'd1);
        check_value("arithmetic benchmark: cycle count", cycles, 32'd42);

        load_memory_heavy_program();
        run_loaded_benchmark("Memory-heavy program", 12, 90);
        check_value("memory benchmark: x4 load word 16", dut.regs[4], 32'd100);
        check_value("memory benchmark: x5 load word 17", dut.regs[5], 32'd200);
        check_value("memory benchmark: x7 negative offset load", dut.regs[7], 32'd100);
        check_value("memory benchmark: x8 load word 18", dut.regs[8], 32'd100);
        check_value("memory benchmark: data word 16", dut.data_mem[16], 32'd100);
        check_value("memory benchmark: data word 17", dut.data_mem[17], 32'd200);
        check_value("memory benchmark: data word 18", dut.data_mem[18], 32'd100);
        check_value("memory benchmark: arithmetic count", arithmetic_instructions, 32'd4);
        check_value("memory benchmark: load count", load_instructions, 32'd4);
        check_value("memory benchmark: store count", store_instructions, 32'd3);
        check_value("memory benchmark: cycle count", cycles, 32'd50);

        load_branch_jump_program();
        run_loaded_benchmark("Branch/jump program", 11, 80);
        check_value("branch/jump benchmark: x3 taken branch result", dut.regs[3], 32'd42);
        check_value("branch/jump benchmark: x6 not-taken result", dut.regs[6], 32'd77);
        check_value("branch/jump benchmark: x7 jump target result", dut.regs[7], 32'd88);
        check_value("branch/jump benchmark: x3 is not 99", (dut.regs[3] == 32'd99), 32'd0);
        check_value("branch/jump benchmark: x7 is not 99", (dut.regs[7] == 32'd99), 32'd0);
        check_value("branch/jump benchmark: arithmetic count", arithmetic_instructions, 32'd7);
        check_value("branch/jump benchmark: branch count", branch_instructions, 32'd2);
        check_value("branch/jump benchmark: jump count", jump_instructions, 32'd1);
        check_value("branch/jump benchmark: cycle count", cycles, 32'd39);

        load_simple_loop_program();
        run_loaded_benchmark("Simple loop program", 20, 120);
        check_value("loop benchmark: x1 accumulator", dut.regs[1], 32'd4);
        check_value("loop benchmark: x2 counter", dut.regs[2], 32'd0);
        check_value("loop benchmark: data word 0", dut.data_mem[0], 32'd4);
        check_value("loop benchmark: arithmetic count", arithmetic_instructions, 32'd11);
        check_value("loop benchmark: branch count", branch_instructions, 32'd4);
        check_value("loop benchmark: jump count", jump_instructions, 32'd3);
        check_value("loop benchmark: store count", store_instructions, 32'd1);
        check_value("loop benchmark: cycle count", cycles, 32'd71);

        $display("");
        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 10A MULTI-CYCLE PERFORMANCE TEST FAILED");
            $fatal(1, "%0d of %0d Phase 10A performance tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 10A MULTI-CYCLE PERFORMANCE TEST PASSED");
        $finish;
    end

endmodule
