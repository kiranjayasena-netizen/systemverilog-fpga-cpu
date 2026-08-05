package cpu_defs_pkg;

    localparam logic [3:0] OP_NOP   = 4'h0;
    localparam logic [3:0] OP_ADD   = 4'h1;
    localparam logic [3:0] OP_SUB   = 4'h2;
    localparam logic [3:0] OP_AND   = 4'h3;
    localparam logic [3:0] OP_OR    = 4'h4;
    localparam logic [3:0] OP_XOR   = 4'h5;
    localparam logic [3:0] OP_ADDI  = 4'h6;
    localparam logic [3:0] OP_LOAD  = 4'h7;
    localparam logic [3:0] OP_STORE = 4'h8;
    localparam logic [3:0] OP_BEQ   = 4'h9;
    localparam logic [3:0] OP_JUMP  = 4'ha;
    // Phase 12 AI extension. Cores that do not explicitly implement MAC8
    // continue to reject this opcode through opcode_is_valid().
    localparam logic [3:0] OP_MAC8  = 4'hb;

    localparam logic [2:0] ALU_ADD = 3'b000;
    localparam logic [2:0] ALU_SUB = 3'b001;
    localparam logic [2:0] ALU_AND = 3'b010;
    localparam logic [2:0] ALU_OR  = 3'b011;
    localparam logic [2:0] ALU_XOR = 3'b100;

    function automatic logic opcode_is_valid(input logic [3:0] opcode);
        unique case (opcode)
            OP_NOP,
            OP_ADD,
            OP_SUB,
            OP_AND,
            OP_OR,
            OP_XOR,
            OP_ADDI,
            OP_LOAD,
            OP_STORE,
            OP_BEQ,
            OP_JUMP: opcode_is_valid = 1'b1;
            default: opcode_is_valid = 1'b0;
        endcase
    endfunction

    function automatic logic opcode_is_arithmetic(input logic [3:0] opcode);
        unique case (opcode)
            OP_ADD,
            OP_SUB,
            OP_AND,
            OP_OR,
            OP_XOR,
            OP_ADDI: opcode_is_arithmetic = 1'b1;
            default: opcode_is_arithmetic = 1'b0;
        endcase
    endfunction

    function automatic logic opcode_writes_rd(input logic [3:0] opcode);
        unique case (opcode)
            OP_ADD,
            OP_SUB,
            OP_AND,
            OP_OR,
            OP_XOR,
            OP_ADDI,
            OP_LOAD: opcode_writes_rd = 1'b1;
            default: opcode_writes_rd = 1'b0;
        endcase
    endfunction

    function automatic logic opcode_uses_rs1(input logic [3:0] opcode);
        unique case (opcode)
            OP_ADD,
            OP_SUB,
            OP_AND,
            OP_OR,
            OP_XOR,
            OP_ADDI,
            OP_LOAD,
            OP_STORE,
            OP_BEQ: opcode_uses_rs1 = 1'b1;
            default: opcode_uses_rs1 = 1'b0;
        endcase
    endfunction

    function automatic logic opcode_uses_rs2(input logic [3:0] opcode);
        unique case (opcode)
            OP_ADD,
            OP_SUB,
            OP_AND,
            OP_OR,
            OP_XOR,
            OP_STORE,
            OP_BEQ: opcode_uses_rs2 = 1'b1;
            default: opcode_uses_rs2 = 1'b0;
        endcase
    endfunction

endpackage
