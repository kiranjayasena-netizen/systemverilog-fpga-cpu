`timescale 1ns / 1ps

module tb_phase6_branch_control;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] pc;
    logic [31:0] instruction;
    logic [3:0]  opcode;
    logic        valid_instr;
    logic [31:0] alu_result;

    int unsigned tests_run;
    int unsigned tests_failed;

    cpu_top #(
        .PROGRAM_FILE("programs/branch_taken_not_taken_test.mem")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .pc(pc),
        .instruction(instruction),
        .opcode(opcode),
        .valid_instr(valid_instr),
        .alu_result(alu_result)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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
            actual = dut.cpu_inst.reg_file_inst.regs[reg_index];
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
            actual = dut.cpu_inst.reg_file_inst.regs[reg_index];
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

    initial begin
        $dumpfile("tb_phase6_branch_control.vcd");
        $dumpvars(0, tb_phase6_branch_control);

        $display("Starting Phase 6C branch control program simulation...");
        $display("Program: BEQ taken skips x3=99, BEQ not-taken executes x6 and x7");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        run_program(11);

        check_reg("ADDI x1, x0, 5",                 5'd1, 32'd5);
        check_reg("ADDI x2, x0, 5",                 5'd2, 32'd5);
        check_reg("Taken BEQ leaves x3 at 42",      5'd3, 32'd42);
        check_reg("ADDI x4, x0, 1",                 5'd4, 32'd1);
        check_reg("ADDI x5, x0, 2",                 5'd5, 32'd2);
        check_reg("Not-taken BEQ executes x6 = 77", 5'd6, 32'd77);
        check_reg("Fall-through executes x7 = 88",  5'd7, 32'd88);
        check_reg("x0 remains hardwired to zero",   5'd0, 32'd0);
        check_reg_not("x3 is not skipped value 99", 5'd3, 32'd99);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 6C BRANCH CONTROL TEST FAILED");
            $fatal(1, "%0d of %0d Phase 6C branch control tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 6C BRANCH CONTROL TEST PASSED");
        $finish;
    end

endmodule
