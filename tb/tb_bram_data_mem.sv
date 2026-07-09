`timescale 1ns / 1ps

module tb_bram_data_mem;

    logic        clk;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] addr;
    logic [31:0] write_data;
    logic [31:0] read_data;

    int unsigned tests_run;
    int unsigned tests_failed;

    bram_data_mem dut (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_data(
        input string       case_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected=0x%08h got=0x%08h",
                    case_name,
                    expected,
                    actual
                );
            end else begin
                $display("PASS: %s | read_data=0x%08h", case_name, actual);
            end
        end
    endtask

    task automatic write_word(
        input logic [31:0] test_addr,
        input logic [31:0] test_data
    );
        begin
            @(negedge clk);
            mem_read   = 1'b0;
            mem_write  = 1'b1;
            addr       = test_addr;
            write_data = test_data;
            @(posedge clk);
            #1;
            mem_write = 1'b0;
        end
    endtask

    task automatic disabled_write_word(
        input logic [31:0] test_addr,
        input logic [31:0] test_data
    );
        begin
            @(negedge clk);
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            addr       = test_addr;
            write_data = test_data;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic read_word(
        input string       case_name,
        input logic [31:0] test_addr,
        input logic [31:0] expected
    );
        begin
            @(negedge clk);
            mem_read  = 1'b1;
            mem_write = 1'b0;
            addr      = test_addr;
            @(posedge clk);
            #1;
            check_data(case_name, read_data, expected);
        end
    endtask

    initial begin
        $dumpfile("tb_bram_data_mem.vcd");
        $dumpvars(0, tb_bram_data_mem);

        $display("Starting Phase 10C BRAM-style data memory simulation...");

        mem_read     = 1'b0;
        mem_write    = 1'b0;
        addr         = 32'h0000_0000;
        write_data   = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        @(posedge clk);
        #1;
        check_data("mem_read low drives zero on first clock edge", read_data, 32'h0000_0000);

        write_word(32'h0000_0000, 32'h1111_2222);
        check_data("write cycle with mem_read low leaves output zero", read_data, 32'h0000_0000);
        read_word("read word 0 after synchronous read edge", 32'h0000_0000, 32'h1111_2222);

        @(negedge clk);
        mem_read  = 1'b1;
        mem_write = 1'b0;
        addr      = 32'h0000_0004;
        #1;
        check_data("output holds previous word before next read edge", read_data, 32'h1111_2222);

        write_word(32'h0000_0004, 32'h3333_4444);
        read_word("read word 1 after write", 32'h0000_0004, 32'h3333_4444);
        read_word("word 0 unchanged after word 1 write", 32'h0000_0000, 32'h1111_2222);
        read_word("unaligned address 1 maps to word 0", 32'h0000_0001, 32'h1111_2222);
        read_word("unaligned address 5 maps to word 1", 32'h0000_0005, 32'h3333_4444);

        @(negedge clk);
        mem_read  = 1'b0;
        mem_write = 1'b0;
        addr      = 32'h0000_0000;
        @(posedge clk);
        #1;
        check_data("mem_read low returns zero after clock edge", read_data, 32'h0000_0000);

        disabled_write_word(32'h0000_0004, 32'hdead_beef);
        read_word("disabled write does not update word 1", 32'h0000_0004, 32'h3333_4444);

        write_word(32'h0000_0400, 32'hffff_0000);
        read_word("out-of-range read returns zero", 32'h0000_0400, 32'h0000_0000);
        read_word("out-of-range write does not corrupt word 0", 32'h0000_0000, 32'h1111_2222);
        read_word("out-of-range write does not corrupt word 1", 32'h0000_0004, 32'h3333_4444);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 10C BRAM DATA MEMORY TEST FAILED");
            $fatal(1, "%0d of %0d BRAM data memory tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 10C BRAM DATA MEMORY TEST PASSED");
        $finish;
    end

endmodule
