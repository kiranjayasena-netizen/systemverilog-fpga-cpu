`timescale 1ns / 1ps

module tb_instr_mem;

    logic [31:0] addr;
    logic [31:0] instruction;

    int unsigned tests_run;
    int unsigned tests_failed;

    instr_mem #(
        .INIT_FILE("programs/add_test.mem")
    ) dut (
        .addr(addr),
        .instruction(instruction)
    );

    task automatic check_instruction(
        input string       case_name,
        input logic [31:0] test_addr,
        input logic [31:0] expected
    );
        begin
            addr = test_addr;
            #1;
            tests_run++;

            if (instruction !== expected) begin
                tests_failed++;
                $error(
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
        $dumpfile("tb_instr_mem.vcd");
        $dumpvars(0, tb_instr_mem);

        $display("Starting Phase 5 instruction memory simulation...");

        addr         = 32'h0000_0000;
        tests_run    = 0;
        tests_failed = 0;

        #1;

        check_instruction("word 0 ADDI x1, x0, 5", 32'h0000_0000, 32'h6080_0005);
        check_instruction("word 1 ADDI x2, x0, 7", 32'h0000_0004, 32'h6100_0007);
        check_instruction("word 2 ADD x3, x1, x2", 32'h0000_0008, 32'h1184_4000);
        check_instruction("word 3 STORE x3, [x0 + 0]", 32'h0000_000c, 32'h8000_6000);
        check_instruction("word 4 NOP", 32'h0000_0010, 32'h0000_0000);
        check_instruction("unaligned address maps to word 0", 32'h0000_0001, 32'h6080_0005);
        check_instruction("out-of-range address returns zero", 32'h0000_0400, 32'h0000_0000);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("PHASE 5 INSTRUCTION MEMORY TEST FAILED");
            $fatal(1, "%0d of %0d instruction memory tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 5 INSTRUCTION MEMORY TEST PASSED");
        $finish;
    end

endmodule

