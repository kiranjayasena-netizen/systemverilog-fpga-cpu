`timescale 1ns / 1ps

module fpga_top_tb;

    logic        clk;
    logic        rst_btn;
    logic        enable_sw;
    logic [15:0] led;

    int unsigned tests_run;
    int unsigned tests_failed;

    fpga_top #(
        .SLOW_TICK_DIVISOR(4)
    ) dut (
        .clk       (clk),
        .rst_btn   (rst_btn),
        .enable_sw (enable_sw),
        .led       (led)
    );

    // 100 MHz clock: 10 ns period, matching the Basys 3 board clock.
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

    task automatic check_no_unknown_leds(input string case_name);
        begin
            tests_run++;

            if ($isunknown(led)) begin
                tests_failed++;
                $error("FAIL: %s | led contains unknown bits: %b", case_name, led);
            end else begin
                $display("PASS: %s | led=%b", case_name, led);
            end
        end
    endtask

    task automatic check_led_changes(
        input string       case_name,
        input int unsigned actual_changes,
        input int unsigned minimum_changes
    );
        begin
            tests_run++;

            if (actual_changes < minimum_changes) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected at least %0d LED changes, saw %0d",
                    case_name,
                    minimum_changes,
                    actual_changes
                );
            end else begin
                $display(
                    "PASS: %s | saw %0d LED changes",
                    case_name,
                    actual_changes
                );
            end
        end
    endtask

    initial begin
        logic [15:0] previous_led;
        int unsigned led_changes;

        $dumpfile("fpga_top_tb.vcd");
        $dumpvars(0, fpga_top_tb);

        $display("Starting FPGA top wrapper simulation...");

        rst_btn      = 1'b0;
        enable_sw    = 1'b0;
        tests_run    = 0;
        tests_failed = 0;
        led_changes  = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        @(negedge clk);
        rst_btn   = 1'b1;
        enable_sw = 1'b0;
        clock_tick();
        check_no_unknown_leds("LED outputs are known during reset");

        @(negedge clk);
        rst_btn      = 1'b0;
        enable_sw    = 1'b1;
        previous_led = led;

        repeat (80) begin
            clock_tick();

            if (led !== previous_led) begin
                led_changes++;
                $display("INFO: LED changed from 0x%04h to 0x%04h", previous_led, led);
                previous_led = led;
            end
        end

        check_no_unknown_leds("LED outputs remain known while CPU is enabled");
        check_led_changes("FPGA wrapper exposes changing CPU debug state", led_changes, 4);

        @(negedge clk);
        enable_sw = 1'b0;
        clock_tick();
        check_no_unknown_leds("LED outputs remain known after CPU is disabled");

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("FPGA TOP TEST FAILED");
            $fatal(1, "%0d of %0d FPGA top tests failed.", tests_failed, tests_run);
        end

        $display("FPGA TOP TEST PASSED");
        $finish;
    end

endmodule
