`timescale 1ns / 1ps

module instruction_memory_tb;

    logic [31:0] addr;
    logic [31:0] instruction;

    int unsigned tests_run;
    int unsigned tests_failed;

    instruction_memory dut (
        .addr(addr),
        .instruction(instruction)
    );

    task automatic check_instruction(
        input string case_name,
        input logic [31:0] test_addr,
        input logic [31:0] expected
    );
        begin
            addr = test_addr;
            #1;
            tests_run++;

            if (instruction !== expected) begin
                tests_failed++;
                $display(
                    "FAIL: %s addr=0x%08h expected=0x%08h got=0x%08h",
                    case_name,
                    test_addr,
                    expected,
                    instruction
                );
            end else begin
                $display(
                    "PASS: %s addr=0x%08h instruction=0x%08h",
                    case_name,
                    test_addr,
                    instruction
                );
            end
        end
    endtask

    initial begin
        $dumpfile("instruction_memory_tb.vcd");
        $dumpvars(0, instruction_memory_tb);

        $display("Starting instruction memory simulation...");

        addr         = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        dut.mem[0] = 32'h1111_1111;
        dut.mem[1] = 32'h2222_2222;
        dut.mem[2] = 32'h3333_3333;
        dut.mem[3] = 32'h4444_4444;
        #1;

        check_instruction("byte address 0 maps to word 0", 32'h0000_0000, 32'h1111_1111);
        check_instruction("byte address 4 maps to word 1", 32'h0000_0004, 32'h2222_2222);
        check_instruction("byte address 8 maps to word 2", 32'h0000_0008, 32'h3333_3333);
        check_instruction("byte address 12 maps to word 3", 32'h0000_000c, 32'h4444_4444);

        check_instruction("unaligned byte address 1 maps to word 0", 32'h0000_0001, 32'h1111_1111);
        check_instruction("unaligned byte address 2 maps to word 0", 32'h0000_0002, 32'h1111_1111);
        check_instruction("unaligned byte address 5 maps to word 1", 32'h0000_0005, 32'h2222_2222);

        check_instruction("unwritten memory location reads zero", 32'h0000_0010, 32'h0000_0000);
        check_instruction("out-of-range address reads zero", 32'h0000_0400, 32'h0000_0000);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed == 0) begin
            $display("INSTRUCTION MEMORY TEST PASSED");
        end else begin
            $display("INSTRUCTION MEMORY TEST FAILED");
            $fatal(1, "%0d instruction memory tests failed.", tests_failed);
        end

        $finish;
    end

endmodule
