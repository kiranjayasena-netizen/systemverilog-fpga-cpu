`timescale 1ns / 1ps

module cpu_core_tb;

    import cpu_defs_pkg::*;

    logic        clk;
    logic        rst;
    logic        enable;

    logic [31:0] pc;
    logic [31:0] instruction;

    logic [3:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] imm_ext;

    logic        reg_write;
    logic        use_imm;
    logic [2:0]  alu_op;
    logic        valid_instr;
    logic [31:0] alu_result;

    int unsigned tests_run;
    int unsigned tests_failed;

    cpu_core dut (
        .clk         (clk),
        .rst         (rst),
        .enable      (enable),
        .pc          (pc),
        .instruction (instruction),
        .opcode      (opcode),
        .rd          (rd),
        .rs1         (rs1),
        .rs2         (rs2),
        .imm_ext     (imm_ext),
        .reg_write   (reg_write),
        .use_imm     (use_imm),
        .alu_op      (alu_op),
        .valid_instr (valid_instr),
        .alu_result  (alu_result)
    );

    // 100 MHz clock: 10 ns period.
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
        build_instruction = {
            build_opcode,
            build_rd,
            build_rs1,
            build_rs2,
            build_imm13
        };
    endfunction

    task automatic clock_tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_reg(
        input string       case_name,
        input logic [4:0]  reg_index,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            actual = dut.reg_file_inst.regs[reg_index];
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | x%0d expected=0x%08h got=0x%08h",
                    case_name,
                    reg_index,
                    expected,
                    actual
                );
            end else begin
                $display(
                    "PASS: %s | x%0d=0x%08h",
                    case_name,
                    reg_index,
                    actual
                );
            end
        end
    endtask

    task automatic check_signal(
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
                $display(
                    "PASS: %s | value=0x%08h",
                    case_name,
                    actual
                );
            end
        end
    endtask

    task automatic check_mem_word(
        input string       case_name,
        input int unsigned word_index,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            actual = dut.data_mem_inst.mem[word_index];
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | mem[%0d] expected=0x%08h got=0x%08h",
                    case_name,
                    word_index,
                    expected,
                    actual
                );
            end else begin
                $display(
                    "PASS: %s | mem[%0d]=0x%08h",
                    case_name,
                    word_index,
                    actual
                );
            end
        end
    endtask

    task automatic run_program(input int unsigned instruction_count);
        begin
            @(negedge clk);
            rst    = 1'b1;
            enable = 1'b0;
            clock_tick();

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            repeat (instruction_count) begin
                clock_tick();
            end

            @(negedge clk);
            enable = 1'b0;
            #1;
        end
    endtask

    task automatic preload_strengthened_alu_program;
        begin
            // ADDI x1, x0, 15      -> x1 = 15
            // ADDI x2, x0, 10      -> x2 = 10
            // ADD  x3, x1, x2      -> x3 = 25
            // SUB  x4, x1, x2      -> x4 = 5
            // AND  x5, x1, x2      -> x5 = 10
            // OR   x6, x1, x2      -> x6 = 15
            // XOR  x7, x1, x2      -> x7 = 5
            // ADDI x8, x0, -1      -> x8 = 0xFFFF_FFFF
            // ADDI x0, x0, 99      -> x0 should remain 0
            // INVALID x9, x1, x2   -> x9 should remain 0
            // NOP
            dut.fetch_inst.imem.mem[0]  = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd15);
            dut.fetch_inst.imem.mem[1]  = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd10);
            dut.fetch_inst.imem.mem[2]  = build_instruction(OP_ADD, 5'd3, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[3]  = build_instruction(OP_SUB, 5'd4, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[4]  = build_instruction(OP_AND, 5'd5, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[5]  = build_instruction(OP_OR, 5'd6, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[6]  = build_instruction(OP_XOR, 5'd7, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[7]  = build_instruction(OP_ADDI, 5'd8, 5'd0, 5'd0, 13'h1fff);
            dut.fetch_inst.imem.mem[8]  = build_instruction(OP_ADDI, 5'd0, 5'd0, 5'd0, 13'd99);
            dut.fetch_inst.imem.mem[9]  = build_instruction(4'hf, 5'd9, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[10] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic preload_load_store_program;
        begin
            // ADDI  x1, x0, 64
            // ADDI  x2, x0, 123
            // STORE x2, [x1 + 0]
            // LOAD  x3, [x1 + 0]
            // ADDI  x4, x0, 68
            // LOAD  x5, [x4 - 4]
            // STORE x3, [x1 + 4]
            // LOAD  x6, [x1 + 4]
            // NOP
            dut.fetch_inst.imem.mem[0]  = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd64);
            dut.fetch_inst.imem.mem[1]  = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd123);
            dut.fetch_inst.imem.mem[2]  = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd2, 13'd0);
            dut.fetch_inst.imem.mem[3]  = build_instruction(OP_LOAD, 5'd3, 5'd1, 5'd0, 13'd0);
            dut.fetch_inst.imem.mem[4]  = build_instruction(OP_ADDI, 5'd4, 5'd0, 5'd0, 13'd68);
            dut.fetch_inst.imem.mem[5]  = build_instruction(OP_LOAD, 5'd5, 5'd4, 5'd0, 13'h1ffc);
            dut.fetch_inst.imem.mem[6]  = build_instruction(OP_STORE, 5'd0, 5'd1, 5'd3, 13'd4);
            dut.fetch_inst.imem.mem[7]  = build_instruction(OP_LOAD, 5'd6, 5'd1, 5'd0, 13'd4);
            dut.fetch_inst.imem.mem[8]  = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            dut.fetch_inst.imem.mem[9]  = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            dut.fetch_inst.imem.mem[10] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("cpu_core_tb.vcd");
        $dumpvars(0, cpu_core_tb);

        $display("Starting CPU core LOAD/STORE integration simulation...");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow DUT initial blocks to run.
        #1;

        $display("Running strengthened ALU/register program...");
        preload_strengthened_alu_program();
        run_program(11);

        check_reg("x0 remains hardwired to zero",      5'd0, 32'h0000_0000);
        check_reg("ADDI x1, x0, 15",                  5'd1, 32'h0000_000f);
        check_reg("ADDI x2, x0, 10",                  5'd2, 32'h0000_000a);
        check_reg("ADD x3, x1, x2",                   5'd3, 32'h0000_0019);
        check_reg("SUB x4, x1, x2",                   5'd4, 32'h0000_0005);
        check_reg("AND x5, x1, x2",                   5'd5, 32'h0000_000a);
        check_reg("OR x6, x1, x2",                    5'd6, 32'h0000_000f);
        check_reg("XOR x7, x1, x2",                   5'd7, 32'h0000_0005);
        check_reg("ADDI x8, x0, -1 sign extension",   5'd8, 32'hffff_ffff);
        check_reg("Invalid opcode does not write x9", 5'd9, 32'h0000_0000);

        // Optional final sanity check: after 11 instructions, PC should have advanced to 44.
        check_signal("PC advanced after strengthened program", pc, 32'h0000_002c);

        $display("Running LOAD/STORE program...");
        preload_load_store_program();
        run_program(9);

        check_reg("LOAD/STORE x1 base address",        5'd1, 32'd64);
        check_reg("LOAD/STORE x2 store data",          5'd2, 32'd123);
        check_reg("LOAD x3 from [x1 + 0]",             5'd3, 32'd123);
        check_reg("ADDI x4, x0, 68",                  5'd4, 32'd68);
        check_reg("LOAD x5 from [x4 - 4]",             5'd5, 32'd123);
        check_reg("LOAD x6 from [x1 + 4]",             5'd6, 32'd123);
        check_mem_word("STORE wrote word 16", 16, 32'd123);
        check_mem_word("STORE wrote word 17", 17, 32'd123);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("CPU CORE TEST FAILED");
            $fatal(1, "%0d of %0d CPU core tests failed.", tests_failed, tests_run);
        end

        $display("CPU CORE TEST PASSED");
        $finish;
    end

endmodule
