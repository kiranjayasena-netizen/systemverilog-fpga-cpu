`timescale 1ns / 1ps

module data_memory_tb;

    localparam int unsigned DEPTH = 256;

    logic        clk;
    logic        rst;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] addr;
    logic [31:0] write_data;
    logic [31:0] read_data;
    int unsigned tests_run;
    int unsigned tests_failed;

    data_memory #(
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
    );

    always #5 clk = ~clk;

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
                    "FAIL: %s addr=0x%08h mem_read=%0b expected=0x%08h got=0x%08h",
                    case_name,
                    test_addr,
                    test_mem_read,
                    expected,
                    read_data
                );
            end else begin
                $display(
                    "PASS: %s addr=0x%08h mem_read=%0b read_data=0x%08h",
                    case_name,
                    test_addr,
                    test_mem_read,
                    read_data
                );
            end
        end
    endtask

    task automatic write_word(
        input string       case_name,
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

            $display(
                "WRITE: %s addr=0x%08h write_data=0x%08h",
                case_name,
                test_addr,
                test_data
            );
        end
    endtask

    task automatic disabled_write(
        input string       case_name,
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

            $display(
                "WRITE DISABLED: %s addr=0x%08h write_data=0x%08h",
                case_name,
                test_addr,
                test_data
            );
        end
    endtask

    initial begin
        $dumpfile("data_memory_tb.vcd");
        $dumpvars(0, data_memory_tb);

        $display("Starting data memory simulation...");

        clk          = 1'b0;
        rst          = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        addr         = 32'h0000_0000;
        write_data   = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        dut.mem[0] = 32'hffff_ffff;
        dut.mem[1] = 32'hffff_ffff;
        apply_reset();

        check_read("reset clears word 0", 32'h0000_0000, 1'b1, 32'h0000_0000);
        check_read("reset clears word 1", 32'h0000_0004, 1'b1, 32'h0000_0000);

        write_word("write word 0", 32'h0000_0000, 32'h1111_2222);
        check_read("read word 0", 32'h0000_0000, 1'b1, 32'h1111_2222);

        write_word("write word 1", 32'h0000_0004, 32'h3333_4444);
        check_read("read word 1", 32'h0000_0004, 1'b1, 32'h3333_4444);
        check_read("word 0 unchanged after word 1 write", 32'h0000_0000, 1'b1, 32'h1111_2222);

        write_word("overwrite word 0", 32'h0000_0000, 32'haaaa_5555);
        check_read("read overwritten word 0", 32'h0000_0000, 1'b1, 32'haaaa_5555);

        check_read("unaligned address 1 maps to word 0", 32'h0000_0001, 1'b1, 32'haaaa_5555);
        check_read("unaligned address 5 maps to word 1", 32'h0000_0005, 1'b1, 32'h3333_4444);

        check_read("mem_read low returns zero", 32'h0000_0000, 1'b0, 32'h0000_0000);

        disabled_write("disabled write word 1", 32'h0000_0004, 32'hdead_beef);
        check_read("disabled write does not update memory", 32'h0000_0004, 1'b1, 32'h3333_4444);

        check_read("out-of-range read returns zero", 32'h0000_0400, 1'b1, 32'h0000_0000);

        write_word("out-of-range write ignored", 32'h0000_0400, 32'hffff_0000);
        check_read("word 0 unchanged after out-of-range write", 32'h0000_0000, 1'b1, 32'haaaa_5555);
        check_read("word 1 unchanged after out-of-range write", 32'h0000_0004, 1'b1, 32'h3333_4444);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("DATA MEMORY TEST FAILED");
            $fatal(1, "%0d of %0d data memory tests failed.", tests_failed, tests_run);
        end

        $display("DATA MEMORY TEST PASSED");
        $finish;
    end

endmodule
