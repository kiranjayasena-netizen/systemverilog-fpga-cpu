`timescale 1ns / 1ps

module slow_tick_generator_tb;

    localparam int unsigned TEST_DIVISOR = 4;

    logic clk;
    logic rst;
    logic tick;

    int unsigned tests_run;
    int unsigned tests_failed;

    slow_tick_generator #(
        .DIVISOR(TEST_DIVISOR)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .tick (tick)
    );

    // 100 MHz clock: 10 ns period.
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

    task automatic check_tick(
        input string case_name,
        input logic  expected
    );
        begin
            tests_run++;

            if (tick !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected tick=%0b got tick=%0b",
                    case_name,
                    expected,
                    tick
                );
            end else begin
                $display("PASS: %s | tick=%0b", case_name, tick);
            end
        end
    endtask

    initial begin
        $dumpfile("slow_tick_generator_tb.vcd");
        $dumpvars(0, slow_tick_generator_tb);

        $display("Starting slow tick generator simulation...");

        rst          = 1'b1;
        tests_run    = 0;
        tests_failed = 0;

        clock_tick();
        check_tick("reset holds tick low", 1'b0);

        clock_tick();
        check_tick("reset continues to hold tick low", 1'b0);

        @(negedge clk);
        rst = 1'b0;

        clock_tick();
        check_tick("cycle 1 after reset is low", 1'b0);

        clock_tick();
        check_tick("cycle 2 after reset is low", 1'b0);

        clock_tick();
        check_tick("cycle 3 after reset is low", 1'b0);

        clock_tick();
        check_tick("cycle 4 produces one-cycle tick", 1'b1);

        clock_tick();
        check_tick("tick returns low after one cycle", 1'b0);

        clock_tick();
        check_tick("next cycle remains low", 1'b0);

        clock_tick();
        check_tick("cycle before second tick remains low", 1'b0);

        clock_tick();
        check_tick("second tick occurs after another divisor interval", 1'b1);

        @(negedge clk);
        rst = 1'b1;
        clock_tick();
        check_tick("reset clears tick after pulses", 1'b0);

        @(negedge clk);
        rst = 1'b0;
        clock_tick();
        check_tick("counter restarts after reset", 1'b0);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("SLOW TICK GENERATOR TEST FAILED");
            $fatal(1, "%0d of %0d slow tick tests failed.", tests_failed, tests_run);
        end

        $display("SLOW TICK GENERATOR TEST PASSED");
        $finish;
    end

endmodule
