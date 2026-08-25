// Stage 7 decoder. ALU field layout remains Stage 4-compatible; memory ops
// use [11:9] as register and [8:4] as a 5-bit vector-memory address.
module vector_memory_instruction_decoder (
    input logic [15:0] instruction,
    output logic [3:0] alu_op,
    output logic [2:0] src_a, src_b, dst,
    output logic [4:0] mem_addr,
    output logic instruction_valid, is_alu, is_vload, is_vstore
);
    always_comb begin
        alu_op=4'h0; src_a='0; src_b='0; dst='0; mem_addr='0;
        instruction_valid=0; is_alu=0; is_vload=0; is_vstore=0;
        case (instruction[15:12])
            4'h0,4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7,4'h8,4'h9: begin
                alu_op=instruction[15:12]; dst=instruction[11:9];
                src_a=instruction[8:6]; src_b=instruction[5:3];
                instruction_valid=1; is_alu=1;
            end
            4'hA: begin
                dst=instruction[11:9]; mem_addr=instruction[8:4];
                instruction_valid=1; is_vload=1;
            end
            4'hB: begin
                src_a=instruction[11:9]; mem_addr=instruction[8:4];
                instruction_valid=1; is_vstore=1;
            end
            default: begin end
        endcase
    end
endmodule
