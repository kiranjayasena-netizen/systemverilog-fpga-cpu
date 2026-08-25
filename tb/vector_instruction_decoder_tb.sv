`timescale 1ns / 1ps

module vector_instruction_decoder_tb;

    logic [15:0] instruction;
    logic [3:0] alu_op;
    logic [2:0] src_a;
    logic [2:0] src_b;
    logic [2:0] dst;
    logic instruction_valid;
    logic execute_enable;
    int unsigned tests_run;
    int unsigned tests_failed;

    vector_instruction_decoder dut (.*);

    function automatic logic [15:0] encode_instruction(
        input logic [3:0] opcode,
        input logic [2:0] test_dst,
        input logic [2:0] test_src_a,
        input logic [2:0] test_src_b,
        input logic [2:0] reserved
    );
        encode_instruction = {opcode, test_dst, test_src_a, test_src_b, reserved};
    endfunction

    task automatic check_valid(
        input string name,
        input logic [3:0] opcode,
        input logic [2:0] test_dst,
        input logic [2:0] test_src_a,
        input logic [2:0] test_src_b,
        input logic [2:0] reserved
    );
        begin
            instruction = encode_instruction(opcode, test_dst, test_src_a,
                                             test_src_b, reserved);
            #1;
            tests_run++;
            if (alu_op !== opcode || dst !== test_dst || src_a !== test_src_a ||
                src_b !== test_src_b || !instruction_valid || !execute_enable) begin
                tests_failed++;
                $error("FAIL: %s instruction=%h decoded op=%h dst=%d a=%d b=%d valid=%b en=%b",
                       name, instruction, alu_op, dst, src_a, src_b,
                       instruction_valid, execute_enable);
            end else begin
                $display("PASS: %s instruction=%h", name, instruction);
            end
        end
    endtask

    task automatic check_invalid(input logic [3:0] opcode);
        begin
            instruction = encode_instruction(opcode, 3'd7, 3'd6, 3'd5, 3'b111);
            #1;
            tests_run++;
            if (alu_op !== 4'h0 || dst !== 3'd0 || src_a !== 3'd0 ||
                src_b !== 3'd0 || instruction_valid || execute_enable) begin
                tests_failed++;
                $error("FAIL: invalid opcode %h controls op=%h dst=%d a=%d b=%d valid=%b en=%b",
                       opcode, alu_op, dst, src_a, src_b,
                       instruction_valid, execute_enable);
            end else begin
                $display("PASS: invalid opcode %h", opcode);
            end
        end
    endtask

    initial begin
        tests_run = 0;
        tests_failed = 0;

        check_valid("VADD V3,V1,V2", 4'h0, 3, 1, 2, 0);
        check_valid("VSUB V7,V6,V5", 4'h1, 7, 6, 5, 0);
        check_valid("VAND V4,V7,V0", 4'h2, 4, 7, 0, 0);
        check_valid("VOR V0,V2,V7", 4'h3, 0, 2, 7, 0);
        check_valid("VXOR V5,V7,V7", 4'h4, 5, 7, 7, 0);
        check_valid("VCMPEQ V6,V0,V7", 4'h5, 6, 0, 7, 0);
        check_valid("VCMPLT V4,V0,V7", 4'h6, 4, 0, 7, 0);
        check_valid("VSLL V1,V1,V2", 4'h7, 1, 1, 2, 0);
        check_valid("VSRL V2,V2,V1", 4'h8, 2, 2, 1, 0);
        check_valid("VSRA V2,V2,V1", 4'h9, 2, 2, 1, 0);

        // Reserved bits are ignored for valid instructions.
        check_valid("VADD reserved bits 111", 4'h0, 3, 1, 2, 3'b111);
        check_valid("VADD reserved bits 101", 4'h0, 3, 1, 2, 3'b101);

        for (int invalid_opcode = 4'ha; invalid_opcode <= 4'hf; invalid_opcode++) begin
            check_invalid(invalid_opcode[3:0]);
        end

        $display("Tests run: %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        if (tests_failed != 0) begin
            $display("VECTOR INSTRUCTION DECODER TEST FAILED");
            $fatal(1, "%0d decoder checks failed", tests_failed);
        end
        $display("VECTOR INSTRUCTION DECODER TEST PASSED");
        $finish;
    end

endmodule
