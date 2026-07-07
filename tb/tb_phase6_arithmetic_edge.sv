`timescale 1ns / 1ps

module tb_phase6_arithmetic_edge;

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
        .PROGRAM_FILE("programs/arithmetic_edge_test.mem")
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
        $dumpfile("tb_phase6_arithmetic_edge.vcd");
        $dumpvars(0, tb_phase6_arithmetic_edge);

        $display("Starting Phase 6 arithmetic edge program simulation...");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        run_program(10);

        check_reg("x0 ignores attempted ADDI write", 5'd0, 32'h0000_0000);
        check_reg("ADDI x1, x0, 10",                5'd1, 32'd10);
        check_reg("ADDI x2, x0, 20",                5'd2, 32'd20);
        check_reg("ADD x3, x1, x2",                 5'd3, 32'd30);
        check_reg("SUB x4, x2, x1",                 5'd4, 32'd10);
        check_reg("ADDI x5, x0, -1",                5'd5, 32'hffff_ffff);
        check_reg("ADD x6, x5, x1 wraps to 9",      5'd6, 32'd9);
        check_reg("SUB x7, x0, x1 underflows",      5'd7, 32'hffff_fff6);
        check_reg("ADD x8, x0, x3 after x0 write",  5'd8, 32'd30);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 6 ARITHMETIC EDGE TEST FAILED");
            $fatal(1, "%0d of %0d Phase 6 arithmetic edge tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 6 ARITHMETIC EDGE TEST PASSED");
        $finish;
    end

endmodule

