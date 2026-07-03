`timescale 1ns / 1ps

module cpu_core_tb;

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

    initial begin
        $dumpfile("cpu_core_tb.vcd");
        $dumpvars(0, cpu_core_tb);

        $display("Starting strengthened CPU core simulation...");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow DUT initial blocks to run.
        #1;

        // Program:
        //
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
        dut.fetch_inst.imem.mem[0]  = build_instruction(4'h6, 5'd1, 5'd0, 5'd0, 13'd15);
        dut.fetch_inst.imem.mem[1]  = build_instruction(4'h6, 5'd2, 5'd0, 5'd0, 13'd10);
        dut.fetch_inst.imem.mem[2]  = build_instruction(4'h1, 5'd3, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[3]  = build_instruction(4'h2, 5'd4, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[4]  = build_instruction(4'h3, 5'd5, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[5]  = build_instruction(4'h4, 5'd6, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[6]  = build_instruction(4'h5, 5'd7, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[7]  = build_instruction(4'h6, 5'd8, 5'd0, 5'd0, 13'h1fff);
        dut.fetch_inst.imem.mem[8]  = build_instruction(4'h6, 5'd0, 5'd0, 5'd0, 13'd99);
        dut.fetch_inst.imem.mem[9]  = build_instruction(4'hf, 5'd9, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[10] = build_instruction(4'h0, 5'd0, 5'd0, 5'd0, 13'd0);

        // Apply synchronous reset.
        @(negedge clk);
        rst    = 1'b1;
        enable = 1'b0;
        clock_tick();

        // Start CPU execution.
        @(negedge clk);
        rst    = 1'b0;
        enable = 1'b1;

        // Execute all 11 instructions.
        repeat (11) begin
            clock_tick();
        end

        // Stop fetching so final debug signals are stable.
        @(negedge clk);
        enable = 1'b0;
        #1;

        // Final register checks.
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
