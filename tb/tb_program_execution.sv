`timescale 1ns / 1ps

module tb_program_execution;

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
        .PROGRAM_FILE("programs/add_test.mem")
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
                    "FAIL: %s expected=0x%08h got=0x%08h",
                    case_name,
                    expected,
                    actual
                );
            end else begin
                $display("PASS: %s value=0x%08h", case_name, actual);
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
        $dumpfile("tb_program_execution.vcd");
        $dumpvars(0, tb_program_execution);

        $display("Starting Phase 5 program execution simulation...");
        $display("Program: ADDI 5, ADDI 7, ADD, STORE result to data memory word 0");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow $readmemh initialisation to complete.
        #1;

        run_program(5);

        check_value("x1 contains 5", dut.cpu_inst.reg_file_inst.regs[1], 32'd5);
        check_value("x2 contains 7", dut.cpu_inst.reg_file_inst.regs[2], 32'd7);
        check_value("x3 contains 12", dut.cpu_inst.reg_file_inst.regs[3], 32'd12);
        check_value("data memory word 0 contains 12", dut.cpu_inst.data_mem_inst.mem[0], 32'd12);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("PHASE 5 PROGRAM EXECUTION TEST FAILED");
            $fatal(1, "%0d of %0d program execution tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 5 PROGRAM EXECUTION TEST PASSED");
        $finish;
    end

endmodule

