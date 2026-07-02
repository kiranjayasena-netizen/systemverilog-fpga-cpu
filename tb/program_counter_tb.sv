`timescale 1ns / 1ps

module program_counter_tb;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] next_pc;
    logic [31:0] pc;

    int unsigned tests_run;
    int unsigned tests_failed;

    program_counter dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .next_pc(next_pc),
        .pc(pc)
    );

    always #5 clk = ~clk;

    task automatic check_pc(
        input string case_name,
        input logic [31:0] expected
    );
        begin
            tests_run++;

            if (pc !== expected) begin
                tests_failed++;
                $display(
                    "FAIL: %s expected=0x%08h got=0x%08h",
                    case_name,
                    expected,
                    pc
                );
            end else begin
                $display("PASS: %s pc=0x%08h", case_name, pc);
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
        $dumpfile("program_counter_tb.vcd");
        $dumpvars(0, program_counter_tb);

        $display("Starting program counter simulation...");

        clk          = 1'b0;
        rst          = 1'b0;
        enable       = 1'b0;
        next_pc      = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        @(negedge clk);
        rst     = 1'b1;
        enable  = 1'b0;
        next_pc = 32'hFFFF_FFFF;
        clock_tick();
        check_pc("reset loads RESET_ADDR", 32'h0000_0000);

        @(negedge clk);
        rst     = 1'b0;
        enable  = 1'b1;
        next_pc = 32'h0000_0004;
        clock_tick();
        check_pc("normal update to 0x00000004", 32'h0000_0004);

        @(negedge clk);
        enable  = 1'b1;
        next_pc = pc + 32'd4;
        clock_tick();
        check_pc("increment using pc + 4", 32'h0000_0008);

        @(negedge clk);
        enable  = 1'b0;
        next_pc = 32'h0000_0040;
        clock_tick();
        check_pc("enable low holds pc", 32'h0000_0008);

        @(negedge clk);
        enable  = 1'b1;
        next_pc = 32'h0000_0100;
        clock_tick();
        check_pc("load custom next_pc", 32'h0000_0100);

        @(negedge clk);
        rst     = 1'b1;
        enable  = 1'b1;
        next_pc = 32'h0000_0200;
        clock_tick();
        check_pc("final reset reloads RESET_ADDR", 32'h0000_0000);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed == 0) begin
            $display("PROGRAM COUNTER TEST PASSED");
        end else begin
            $display("PROGRAM COUNTER TEST FAILED");
        end

        $finish;
    end

endmodule
