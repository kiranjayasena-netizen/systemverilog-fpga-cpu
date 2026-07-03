`timescale 1ns / 1ps

module control_unit_tb;

    localparam logic [2:0] ALU_ADD = 3'b000;
    localparam logic [2:0] ALU_SUB = 3'b001;
    localparam logic [2:0] ALU_AND = 3'b010;
    localparam logic [2:0] ALU_OR  = 3'b011;
    localparam logic [2:0] ALU_XOR = 3'b100;

    logic [3:0] opcode;
    logic       reg_write;
    logic       use_imm;
    logic [2:0] alu_op;
    logic       valid_instr;
    logic       mem_read;
    logic       mem_write;
    logic       mem_to_reg;
    logic       branch;
    logic       jump;
    int unsigned tests_run;
    int unsigned tests_failed;

    control_unit dut (
        .opcode(opcode),
        .reg_write(reg_write),
        .use_imm(use_imm),
        .alu_op(alu_op),
        .valid_instr(valid_instr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jump(jump)
    );

    task automatic check_control(
        input string       case_name,
        input logic [3:0]  test_opcode,
        input logic        expected_reg_write,
        input logic        expected_use_imm,
        input logic [2:0]  expected_alu_op,
        input logic        expected_valid_instr,
        input logic        expected_mem_read,
        input logic        expected_mem_write,
        input logic        expected_mem_to_reg,
        input logic        expected_branch,
        input logic        expected_jump
    );
        begin
            opcode = test_opcode;
            #1;

            tests_run++;

            if (
                reg_write   !== expected_reg_write ||
                use_imm     !== expected_use_imm ||
                alu_op      !== expected_alu_op ||
                valid_instr !== expected_valid_instr ||
                mem_read    !== expected_mem_read ||
                mem_write   !== expected_mem_write ||
                mem_to_reg  !== expected_mem_to_reg ||
                branch      !== expected_branch ||
                jump        !== expected_jump
            ) begin
                tests_failed++;
                $error(
                    "FAIL: %s opcode=0x%0h reg_write=%0b/%0b use_imm=%0b/%0b alu_op=0b%03b/0b%03b valid_instr=%0b/%0b mem_read=%0b/%0b mem_write=%0b/%0b mem_to_reg=%0b/%0b branch=%0b/%0b jump=%0b/%0b",
                    case_name,
                    test_opcode,
                    reg_write,
                    expected_reg_write,
                    use_imm,
                    expected_use_imm,
                    alu_op,
                    expected_alu_op,
                    valid_instr,
                    expected_valid_instr,
                    mem_read,
                    expected_mem_read,
                    mem_write,
                    expected_mem_write,
                    mem_to_reg,
                    expected_mem_to_reg,
                    branch,
                    expected_branch,
                    jump,
                    expected_jump
                );
            end else begin
                $display(
                    "PASS: %s opcode=0x%0h reg_write=%0b use_imm=%0b alu_op=0b%03b valid_instr=%0b mem_read=%0b mem_write=%0b mem_to_reg=%0b branch=%0b jump=%0b",
                    case_name,
                    test_opcode,
                    reg_write,
                    use_imm,
                    alu_op,
                    valid_instr,
                    mem_read,
                    mem_write,
                    mem_to_reg,
                    branch,
                    jump
                );
            end
        end
    endtask

    initial begin
        $dumpfile("control_unit_tb.vcd");
        $dumpvars(0, control_unit_tb);

        $display("Starting control unit simulation...");
        tests_run    = 0;
        tests_failed = 0;

        check_control("NOP",   4'h0, 1'b0, 1'b0, ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("ADD",   4'h1, 1'b1, 1'b0, ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("SUB",   4'h2, 1'b1, 1'b0, ALU_SUB, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("AND",   4'h3, 1'b1, 1'b0, ALU_AND, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("OR",    4'h4, 1'b1, 1'b0, ALU_OR,  1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("XOR",   4'h5, 1'b1, 1'b0, ALU_XOR, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("ADDI",  4'h6, 1'b1, 1'b1, ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("LOAD",  4'h7, 1'b1, 1'b1, ALU_ADD, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
        check_control("STORE", 4'h8, 1'b0, 1'b1, ALU_ADD, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
        check_control("BEQ",   4'h9, 1'b0, 1'b0, ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        check_control("JUMP",  4'ha, 1'b0, 1'b0, ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);

        check_control("INVALID opcode b", 4'hb, 1'b0, 1'b0, ALU_ADD, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_control("INVALID opcode f", 4'hf, 1'b0, 1'b0, ALU_ADD, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("CONTROL UNIT TEST FAILED");
            $fatal(1, "%0d of %0d control unit tests failed.", tests_failed, tests_run);
        end

        $display("CONTROL UNIT TEST PASSED");
        $finish;
    end

endmodule
