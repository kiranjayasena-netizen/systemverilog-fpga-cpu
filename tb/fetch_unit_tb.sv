`timescale 1ns / 1ps

module fetch_unit_tb;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] pc;
    logic [31:0] instruction;

    int unsigned tests_run;
    int unsigned tests_failed;

    fetch_unit dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .pc(pc),
        .instruction(instruction)
    );

    always #5 clk = ~clk;

    task automatic check_fetch(
        input string case_name,
        input logic [31:0] expected_pc,
        input logic [31:0] expected_instruction
    );
        begin
            tests_run++;

            if ((pc !== expected_pc) || (instruction !== expected_instruction)) begin
                tests_failed++;
                $display(
                    "FAIL: %s expected_pc=0x%08h got_pc=0x%08h expected_instruction=0x%08h got_instruction=0x%08h",
                    case_name,
                    expected_pc,
                    pc,
                    expected_instruction,
                    instruction
                );
            end else begin
                $display(
                    "PASS: %s pc=0x%08h instruction=0x%08h",
                    case_name,
                    pc,
                    instruction
                );
            end
        end
    endtask

    task automatic clock_tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $dumpfile("fetch_unit_tb.vcd");
        $dumpvars(0, fetch_unit_tb);

        $display("Starting fetch unit simulation...");

        clk          = 1'b0;
        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        dut.imem.mem[0] = 32'h1111_1111;
        dut.imem.mem[1] = 32'h2222_2222;
        dut.imem.mem[2] = 32'h3333_3333;
        dut.imem.mem[3] = 32'h4444_4444;

        @(negedge clk);
        rst    = 1'b1;
        enable = 1'b0;
        clock_tick();
        check_fetch("reset fetches first instruction", 32'h0000_0000, 32'h1111_1111);

        @(negedge clk);
        rst    = 1'b0;
        enable = 1'b1;
        clock_tick();
        check_fetch("fetch word 1", 32'h0000_0004, 32'h2222_2222);

        clock_tick();
        check_fetch("fetch word 2", 32'h0000_0008, 32'h3333_3333);

        clock_tick();
        check_fetch("fetch word 3", 32'h0000_000c, 32'h4444_4444);

        @(negedge clk);
        enable = 1'b0;
        clock_tick();
        check_fetch("enable low holds fetch state", 32'h0000_000c, 32'h4444_4444);

        @(negedge clk);
        rst    = 1'b1;
        enable = 1'b1;
        clock_tick();
        check_fetch("final reset returns to first instruction", 32'h0000_0000, 32'h1111_1111);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed == 0) begin
            $display("FETCH UNIT TEST PASSED");
        end else begin
            $display("FETCH UNIT TEST FAILED");
            $fatal(1, "%0d fetch unit tests failed.", tests_failed);
        end

        $finish;
    end

endmodule
