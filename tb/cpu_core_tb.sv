`timescale 1ns / 1ps

module cpu_core_tb;

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

    cpu_core dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .pc(pc),
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm_ext(imm_ext),
        .reg_write(reg_write),
        .use_imm(use_imm),
        .alu_op(alu_op),
        .valid_instr(valid_instr),
        .alu_result(alu_result)
    );

    always #5 clk = ~clk;

    function automatic logic [31:0] build_instruction(
        input logic [3:0]  build_opcode,
        input logic [4:0]  build_rd,
        input logic [4:0]  build_rs1,
        input logic [4:0]  build_rs2,
        input logic [12:0] build_imm13
    );
        build_instruction = {
            build_opcode,
            build_rd,
            build_rs1,
            build_rs2,
            build_imm13
        };
    endfunction

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
                    "FAIL: %s x%0d expected=0x%08h got=0x%08h",
                    case_name,
                    reg_index,
                    expected,
                    actual
                );
            end else begin
                $display(
                    "PASS: %s x%0d=0x%08h",
                    case_name,
                    reg_index,
                    actual
                );
            end
        end
    endtask

    initial begin
        $dumpfile("cpu_core_tb.vcd");
        $dumpvars(0, cpu_core_tb);

        $display("Starting CPU core simulation...");

        clk          = 1'b0;
        rst          = 1'b0;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        #1;
        dut.fetch_inst.imem.mem[0] = build_instruction(4'h6, 5'd1, 5'd0, 5'd0, 13'd5);
        dut.fetch_inst.imem.mem[1] = build_instruction(4'h6, 5'd2, 5'd0, 5'd0, 13'd7);
        dut.fetch_inst.imem.mem[2] = build_instruction(4'h1, 5'd3, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[3] = build_instruction(4'h2, 5'd4, 5'd3, 5'd1, 13'd0);
        dut.fetch_inst.imem.mem[4] = build_instruction(4'h5, 5'd5, 5'd1, 5'd2, 13'd0);
        dut.fetch_inst.imem.mem[5] = build_instruction(4'h0, 5'd0, 5'd0, 5'd0, 13'd0);

        @(negedge clk);
        rst    = 1'b1;
        enable = 1'b0;
        clock_tick();

        @(negedge clk);
        rst    = 1'b0;
        enable = 1'b1;

        repeat (5) begin
            clock_tick();
        end

        check_reg("ADDI x1, x0, 5", 5'd1, 32'd5);
        check_reg("ADDI x2, x0, 7", 5'd2, 32'd7);
        check_reg("ADD x3, x1, x2", 5'd3, 32'd12);
        check_reg("SUB x4, x3, x1", 5'd4, 32'd7);
        check_reg("XOR x5, x1, x2", 5'd5, 32'd2);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("CPU CORE TEST FAILED");
            $fatal(1, "%0d of %0d CPU core tests failed.", tests_failed, tests_run);
        end

        $display("CPU CORE TEST PASSED");
        $finish;
    end

endmodule
