`timescale 1ns / 1ps

module cpu_core_program_tb;

    logic        clk;
    logic        rst;
    logic        enable;

    logic [31:0] pc;
    logic [31:0] instruction;

    logic [3:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] imm_ext;

    logic        reg_write;
    logic        use_imm;
    logic [2:0]  alu_op;
    logic        valid_instr;
    logic [31:0] alu_result;

    int unsigned tests_run;
    int unsigned tests_failed;

    cpu_core #(
        .IMEM_INIT_FILE("programs/load_store_test.mem")
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .enable      (enable),
        .pc          (pc),
        .instruction (instruction),
        .opcode      (opcode),
        .rd          (rd),
        .rs1         (rs1),
        .rs2         (rs2),
        .imm_ext     (imm_ext),
        .reg_write   (reg_write),
        .use_imm     (use_imm),
        .alu_op      (alu_op),
        .valid_instr (valid_instr),
        .alu_result  (alu_result)
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

    task automatic check_reg(
        input string       case_name,
        input logic [4:0]  reg_index,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        begin
            actual = dut.reg_file_inst.regs[reg_index];
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
            actual = dut.data_mem_inst.mem[word_index];
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
        $dumpfile("cpu_core_program_tb.vcd");
        $dumpvars(0, cpu_core_program_tb);

        $display("Starting CPU core file-loaded program simulation...");

        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        // Allow instruction memory $readmemh initialisation to complete.
        #1;

        $display("Running programs/load_store_test.mem...");
        run_program(9);

        check_reg("LOAD/STORE x1 base address", 5'd1, 32'd64);
        check_reg("LOAD/STORE x2 store data",   5'd2, 32'd123);
        check_reg("LOAD x3 from [x1 + 0]",      5'd3, 32'd123);
        check_reg("ADDI x4, x0, 68",            5'd4, 32'd68);
        check_reg("LOAD x5 from [x4 - 4]",      5'd5, 32'd123);
        check_reg("LOAD x6 from [x1 + 4]",      5'd6, 32'd123);
        check_mem_word("STORE wrote word 16", 16, 32'd123);
        check_mem_word("STORE wrote word 17", 17, 32'd123);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("CPU CORE PROGRAM TEST FAILED");
            $fatal(1, "%0d of %0d CPU core program tests failed.", tests_failed, tests_run);
        end

        $display("CPU CORE PROGRAM TEST PASSED");
        $finish;
    end

endmodule
