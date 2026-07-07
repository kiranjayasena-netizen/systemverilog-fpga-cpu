`timescale 1ns / 1ps

module tb_data_mem;

    logic        clk;
    logic        rst;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] addr;
    logic [31:0] write_data;
    logic [31:0] read_data;

    int unsigned tests_run;
    int unsigned tests_failed;

    data_mem dut (
        .clk(clk),
        .rst(rst),
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

    task automatic apply_reset;
        begin
            @(negedge clk);
            rst        = 1'b1;
            mem_read   = 1'b0;
            mem_write  = 1'b0;
            addr       = 32'h0000_0000;
            write_data = 32'h0000_0000;
            @(posedge clk);
            #1;
            @(negedge clk);
            rst = 1'b0;
            #1;
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

    task automatic check_read(
        input string       case_name,
        input logic [31:0] test_addr,
        input logic        test_mem_read,
        input logic [31:0] expected
    );
        begin
            @(negedge clk);
            mem_read  = test_mem_read;
            mem_write = 1'b0;
            addr      = test_addr;
            #1;
            tests_run++;

            if (read_data !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s addr=0x%08h expected=0x%08h got=0x%08h",
                    case_name,
                    test_addr,
                    expected,
                    read_data
                );
            end else begin
                $display(
                    "PASS: %s addr=0x%08h read_data=0x%08h",
                    case_name,
                    test_addr,
                    read_data
                );
            end
        end
    endtask

    initial begin
        $dumpfile("tb_data_mem.vcd");
        $dumpvars(0, tb_data_mem);

        $display("Starting Phase 5 data memory simulation...");

        rst          = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        addr         = 32'h0000_0000;
        write_data   = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        apply_reset();

        check_read("reset clears word 0", 32'h0000_0000, 1'b1, 32'h0000_0000);
        write_word(32'h0000_0000, 32'h0000_000c);
        check_read("read written word 0", 32'h0000_0000, 1'b1, 32'h0000_000c);
        check_read("unaligned address maps to word 0", 32'h0000_0003, 1'b1, 32'h0000_000c);
        check_read("mem_read low returns zero", 32'h0000_0000, 1'b0, 32'h0000_0000);
        write_word(32'h0000_0400, 32'hffff_ffff);
        check_read("out-of-range write does not corrupt word 0", 32'h0000_0000, 1'b1, 32'h0000_000c);
        check_read("out-of-range read returns zero", 32'h0000_0400, 1'b1, 32'h0000_0000);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("PHASE 5 DATA MEMORY TEST FAILED");
            $fatal(1, "%0d of %0d data memory tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 5 DATA MEMORY TEST PASSED");
        $finish;
    end

endmodule

