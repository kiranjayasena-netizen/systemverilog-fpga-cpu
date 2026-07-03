`timescale 1ns / 1ps

module cpu_core_branch_tb;

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

    task automatic check_reg_not(
        input string       case_name,
        input logic [4:0]  reg_index,
        input logic [31:0] unexpected
    );
        logic [31:0] actual;
        begin
            actual = dut.reg_file_inst.regs[reg_index];
            tests_run++;

            if (actual === unexpected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | x%0d unexpectedly=0x%08h",
                    case_name,
                    reg_index,
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

    task automatic run_program(input int unsigned cycle_count);
        begin
            @(negedge clk);
            rst    = 1'b1;
            enable = 1'b0;
            clock_tick();

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            repeat (cycle_count) begin
                clock_tick();
            end

            @(negedge clk);
            enable = 1'b0;
            #1;
        end
    endtask

    task automatic preload_branch_jump_program;
        begin
            // Taken BEQ and JUMP path.
            dut.fetch_inst.imem.mem[0]  = build_instruction(4'h6, 5'd1, 5'd0, 5'd0, 13'd5);
            dut.fetch_inst.imem.mem[1]  = build_instruction(4'h6, 5'd2, 5'd0, 5'd0, 13'd5);
            dut.fetch_inst.imem.mem[2]  = build_instruction(4'h9, 5'd0, 5'd1, 5'd2, 13'd2);
            dut.fetch_inst.imem.mem[3]  = build_instruction(4'h6, 5'd3, 5'd0, 5'd0, 13'd99);
            dut.fetch_inst.imem.mem[4]  = build_instruction(4'h6, 5'd3, 5'd0, 5'd0, 13'd42);
            dut.fetch_inst.imem.mem[5]  = build_instruction(4'ha, 5'd0, 5'd0, 5'd0, 13'd2);
            dut.fetch_inst.imem.mem[6]  = build_instruction(4'h6, 5'd4, 5'd0, 5'd0, 13'd99);
            dut.fetch_inst.imem.mem[7]  = build_instruction(4'h6, 5'd4, 5'd0, 5'd0, 13'd77);
            dut.fetch_inst.imem.mem[8]  = build_instruction(4'h0, 5'd0, 5'd0, 5'd0, 13'd0);

            // Not-taken BEQ path.
            dut.fetch_inst.imem.mem[9]  = build_instruction(4'h6, 5'd5, 5'd0, 5'd0, 13'd1);
            dut.fetch_inst.imem.mem[10] = build_instruction(4'h6, 5'd6, 5'd0, 5'd0, 13'd2);
            dut.fetch_inst.imem.mem[11] = build_instruction(4'h9, 5'd0, 5'd5, 5'd6, 13'd2);
            dut.fetch_inst.imem.mem[12] = build_instruction(4'h6, 5'd7, 5'd0, 5'd0, 13'd55);
            dut.fetch_inst.imem.mem[13] = build_instruction(4'h0, 5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("cpu_core_branch_tb.vcd");
        $dumpvars(0, cpu_core_branch_tb);

        $display("Starting CPU core branch/jump simulation...");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        preload_branch_jump_program();
        run_program(14);

        check_reg("ADDI x1, x0, 5",              5'd1, 32'd5);
        check_reg("ADDI x2, x0, 5",              5'd2, 32'd5);
        check_reg("Taken BEQ skips x3=99",       5'd3, 32'd42);
        check_reg("JUMP skips x4=99",            5'd4, 32'd77);
        check_reg("x0 remains hardwired to zero", 5'd0, 32'd0);
        check_reg_not("x3 is not skipped value 99", 5'd3, 32'd99);
        check_reg_not("x4 is not skipped value 99", 5'd4, 32'd99);
        check_reg("Not-taken BEQ executes x7",   5'd7, 32'd55);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("CPU CORE BRANCH TEST FAILED");
            $fatal(1, "%0d of %0d CPU core branch tests failed.", tests_failed, tests_run);
        end

        $display("CPU CORE BRANCH TEST PASSED");
        $finish;
    end

endmodule
