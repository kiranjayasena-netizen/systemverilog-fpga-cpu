module instruction_decoder (
    input  logic [31:0] instruction,
    output logic [3:0]  opcode,
    output logic [4:0]  rd,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [12:0] imm13,
    output logic [31:0] imm_ext
);

    assign opcode  = instruction[31:28];
    assign rd      = instruction[27:23];
    assign rs1     = instruction[22:18];
    assign rs2     = instruction[17:13];
    assign imm13   = instruction[12:0];
    assign imm_ext = {{19{instruction[12]}}, instruction[12:0]};

endmodule
