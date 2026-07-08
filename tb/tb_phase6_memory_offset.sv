`timescale 1ns / 1ps

module tb_phase6_memory_offset;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] pc;
    logic [31:0] instruction;
    logic [3:0]  opcode;
    logic        valid_instr;
    logic [31:0] alu_result;

    int unsigned tests_run;
    int unsigned tests_failed;

    cpu_top #(
        .PROGRAM_FILE("programs/memory_offset_test.mem")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .pc(pc),
        .instruction(instruction),
        .opcode(opcode),
        .valid_instr(valid_instr),
        .alu_result(alu_result)
    );

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

    task automatic check_reg(
        input string       case_name,
        input logic [4:0]  reg_index,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            actual = dut.cpu_inst.reg_file_inst.regs[reg_index];
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | x%0d expected=0x%08h got=0x%08h",
                    case_name,
                    reg_index,
                    expected,
                    actual
                );
            end else begin
                $display(
                    "PASS: %s | x%0d=0x%08h",
                    case_name,
                    reg_index,
                    actual
                );
            end
        end
    endtask

    task automatic check_mem_word(
        input string       case_name,
        input int unsigned word_index,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            actual = dut.cpu_inst.data_mem_inst.mem[word_index];
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | mem[%0d] expected=0x%08h got=0x%08h",
                    case_name,
                    word_index,
                    expected,
                    actual
                );
            end else begin
                $display(
                    "PASS: %s | mem[%0d]=0x%08h",
                    case_name,
                    word_index,
                    actual
                );
            end
        end
    endtask

    task automatic run_program(input int unsigned instruction_count);
        begin
            @(negedge clk);
            rst    = 1'b1;
            enable = 1'b0;
            clock_tick();

            @(negedge clk);
            rst    = 1'b0;
            enable = 1'b1;

            repeat (instruction_count) begin
                clock_tick();
            end

            @(negedge clk);
            enable = 1'b0;
            #1;
        end
    endtask

    initial begin
        $dumpfile("tb_phase6_memory_offset.vcd");
        $dumpvars(0, tb_phase6_memory_offset);

        $display("Starting Phase 6 memory offset program simulation...");
        $display("Program: base setup, STORE/LOAD +0, STORE/LOAD +4, LOAD -4");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        run_program(9);

        check_reg("ADDI x1, x0, 64 base address", 5'd1, 32'd64);
        check_reg("ADDI x2, x0, 123 store data",  5'd2, 32'd123);
        check_reg("LOAD x3 from [x1 + 0]",        5'd3, 32'd123);
        check_reg("LOAD x4 from [x1 + 4]",        5'd4, 32'd123);
        check_reg("ADDI x5, x0, 68 base plus 4",  5'd5, 32'd68);
        check_reg("LOAD x6 from [x5 - 4]",        5'd6, 32'd123);
        check_mem_word("STORE wrote word 16", 16, 32'd123);
        check_mem_word("STORE wrote word 17", 17, 32'd123);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 6 MEMORY OFFSET TEST FAILED");
            $fatal(1, "%0d of %0d Phase 6 memory offset tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 6 MEMORY OFFSET TEST PASSED");
        $finish;
    end

endmodule
