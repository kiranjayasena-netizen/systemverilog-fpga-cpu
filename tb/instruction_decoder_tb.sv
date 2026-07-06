`timescale 1ns / 1ps

module instruction_decoder_tb;

    import cpu_defs_pkg::*;

    logic [31:0] instruction;
    logic [3:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [12:0] imm13;
    logic [31:0] imm_ext;
    int unsigned tests_run;
    int unsigned tests_failed;

    instruction_decoder dut (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm13(imm13),
        .imm_ext(imm_ext)
    );

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

    function automatic logic [31:0] sign_extend_imm13(
        input logic [12:0] value
    );
        sign_extend_imm13 = {{19{value[12]}}, value};
    endfunction

    task automatic check_instruction(
        input string       case_name,
        input logic [3:0]  expected_opcode,
        input logic [4:0]  expected_rd,
        input logic [4:0]  expected_rs1,
        input logic [4:0]  expected_rs2,
        input logic [12:0] expected_imm13
    );
        logic [31:0] expected_instruction;
        logic [31:0] expected_imm_ext;
        begin
            expected_instruction = build_instruction(
                expected_opcode,
                expected_rd,
                expected_rs1,
                expected_rs2,
                expected_imm13
            );
            expected_imm_ext = sign_extend_imm13(expected_imm13);

            instruction = expected_instruction;
            #1;

            tests_run++;

            if (
                opcode  !== expected_opcode ||
                rd      !== expected_rd ||
                rs1     !== expected_rs1 ||
                rs2     !== expected_rs2 ||
                imm13   !== expected_imm13 ||
                imm_ext !== expected_imm_ext
            ) begin
                tests_failed++;
                $error(
                    "FAIL: %s instruction=0x%08h opcode=0x%0h/0x%0h rd=%0d/%0d rs1=%0d/%0d rs2=%0d/%0d imm13=0x%04h/0x%04h imm_ext=0x%08h/0x%08h",
                    case_name,
                    expected_instruction,
                    opcode,
                    expected_opcode,
                    rd,
                    expected_rd,
                    rs1,
                    expected_rs1,
                    rs2,
                    expected_rs2,
                    imm13,
                    expected_imm13,
                    imm_ext,
                    expected_imm_ext
                );
            end else begin
                $display(
                    "PASS: %s instruction=0x%08h opcode=0x%0h rd=%0d rs1=%0d rs2=%0d imm13=0x%04h imm_ext=0x%08h",
                    case_name,
                    expected_instruction,
                    opcode,
                    rd,
                    rs1,
                    rs2,
                    imm13,
                    imm_ext
                );
            end
        end
    endtask

    initial begin
        $dumpfile("instruction_decoder_tb.vcd");
        $dumpvars(0, instruction_decoder_tb);

        $display("Starting instruction decoder simulation...");
        tests_run    = 0;
        tests_failed = 0;

        check_instruction("NOP", OP_NOP, 5'd0, 5'd0, 5'd0, 13'h0000);
        check_instruction("ADD", OP_ADD, 5'd1, 5'd2, 5'd3, 13'h0000);
        check_instruction("SUB", OP_SUB, 5'd4, 5'd5, 5'd6, 13'h0000);
        check_instruction("AND", OP_AND, 5'd7, 5'd8, 5'd9, 13'h0000);
        check_instruction("OR", OP_OR, 5'd10, 5'd11, 5'd12, 13'h0000);
        check_instruction("XOR", OP_XOR, 5'd13, 5'd14, 5'd15, 13'h0000);
        check_instruction("ADDI positive immediate", OP_ADDI, 5'd16, 5'd17, 5'd0, 13'h0005);
        check_instruction("ADDI negative immediate", OP_ADDI, 5'd18, 5'd19, 5'd0, 13'h1fff);
        check_instruction("Edge register values", OP_ADD, 5'd31, 5'd31, 5'd31, 13'h0000);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("INSTRUCTION DECODER TEST FAILED");
            $fatal(1, "%0d of %0d instruction decoder tests failed.", tests_failed, tests_run);
        end

        $display("INSTRUCTION DECODER TEST PASSED");
        $finish;
    end

endmodule
