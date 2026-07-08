`timescale 1ns / 1ps

module tb_phase6_jump_control;

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
        .PROGRAM_FILE("programs/jump_test.mem")
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
        $dumpfile("tb_phase6_jump_control.vcd");
        $dumpvars(0, tb_phase6_jump_control);

        $display("Starting Phase 6D jump control program simulation...");
        $display("Program: JUMP skips x2=99 and x4=99");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        run_program(9);

        check_reg("x0 remains hardwired to zero", 5'd0, 32'd0);
        check_reg("ADDI x1, x0, 11",              5'd1, 32'd11);
        check_reg("First JUMP skips x2=99",       5'd2, 32'd22);
        check_reg("ADDI x3, x0, 33",              5'd3, 32'd33);
        check_reg("Second JUMP skips x4=99",      5'd4, 32'd44);
        check_reg_not("x2 is not skipped value 99", 5'd2, 32'd99);
        check_reg_not("x4 is not skipped value 99", 5'd4, 32'd99);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 6D JUMP CONTROL TEST FAILED");
            $fatal(1, "%0d of %0d Phase 6D jump control tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 6D JUMP CONTROL TEST PASSED");
        $finish;
    end

endmodule
