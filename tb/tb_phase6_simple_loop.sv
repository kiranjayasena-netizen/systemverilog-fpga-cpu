`timescale 1ns / 1ps

module tb_phase6_simple_loop;

    localparam int unsigned MAX_CYCLES = 24;

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
        .PROGRAM_FILE("programs/simple_loop_test.mem")
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

    task automatic check_mem_word(
        input string       case_name,
        input int unsigned word_index,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            actual = dut.cpu_inst.data_mem_inst.mem[word_index];
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

    task automatic run_program(input int unsigned cycle_count);
        begin
            @(negedge clk);
            rst    = 1'b1;
            enable = 1'b0;
            clock_tick();

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            // Fixed maximum cycle count prevents a bad loop from hanging simulation.
            repeat (cycle_count) begin
                clock_tick();
            end

            @(negedge clk);
            enable = 1'b0;
            #1;
        end
    endtask

    initial begin
        $dumpfile("tb_phase6_simple_loop.vcd");
        $dumpvars(0, tb_phase6_simple_loop);

        $display("Starting Phase 6E simple loop program simulation...");
        $display("Program: increment x1 and decrement x2 until x2 reaches zero");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        run_program(MAX_CYCLES);

        check_reg("x0 remains hardwired to zero", 5'd0, 32'd0);
        check_reg("Loop accumulator x1",          5'd1, 32'd3);
        check_reg("Loop counter x2 reaches zero", 5'd2, 32'd0);
        check_reg("Loop step x3 remains one",     5'd3, 32'd1);
        check_mem_word("STORE writes result to data memory word 0", 0, 32'd3);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 6E SIMPLE LOOP TEST FAILED");
            $fatal(1, "%0d of %0d Phase 6E simple loop tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 6E SIMPLE LOOP TEST PASSED");
        $finish;
    end

endmodule
