`timescale 1ns / 1ps

module tb_bram_instr_mem;

    logic        clk;
    logic [31:0] addr;
    logic [31:0] instruction;

    int unsigned tests_run;
    int unsigned tests_failed;

    bram_instr_mem #(
        .INIT_FILE("programs/add_test.mem")
    ) dut (
        .clk(clk),
        .addr(addr),
        .instruction(instruction)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_instruction(
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
                $display("PASS: %s | instruction=0x%08h", case_name, actual);
            end
        end
    endtask

    task automatic read_instruction(
        input string       case_name,
        input logic [31:0] test_addr,
        input logic [31:0] expected
    );
        begin
            @(negedge clk);
            addr = test_addr;
            @(posedge clk);
            #1;
            check_instruction(case_name, instruction, expected);
        end
    endtask

    initial begin
        $dumpfile("tb_bram_instr_mem.vcd");
        $dumpvars(0, tb_bram_instr_mem);

        $display("Starting Phase 10C BRAM-style instruction memory simulation...");

        addr         = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        read_instruction("word 0 loaded from add_test.mem", 32'h0000_0000, 32'h6080_0005);

        @(negedge clk);
        addr = 32'h0000_0004;
        #1;
        check_instruction("output holds previous word before clock edge", instruction, 32'h6080_0005);
        @(posedge clk);
        #1;
        check_instruction("word 1 visible after synchronous read edge", instruction, 32'h6100_0007);

        read_instruction("word 2 loaded from add_test.mem", 32'h0000_0008, 32'h1184_4000);
        read_instruction("word 3 loaded from add_test.mem", 32'h0000_000c, 32'h8000_6000);
        read_instruction("word 4 NOP loaded from add_test.mem", 32'h0000_0010, 32'h0000_0000);
        read_instruction("unaligned address 1 maps to word 0", 32'h0000_0001, 32'h6080_0005);
        read_instruction("unaligned address 5 maps to word 1", 32'h0000_0005, 32'h6100_0007);
        read_instruction("out-of-range address returns NOP", 32'h0000_0400, 32'h0000_0000);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 10C BRAM INSTRUCTION MEMORY TEST FAILED");
            $fatal(1, "%0d of %0d BRAM instruction memory tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 10C BRAM INSTRUCTION MEMORY TEST PASSED");
        $finish;
    end

endmodule
