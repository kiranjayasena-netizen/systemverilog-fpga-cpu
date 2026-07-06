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

    localparam logic [2:0] ALU_ADD = 3'b000;
    localparam logic [2:0] ALU_SUB = 3'b001;
    localparam logic [2:0] ALU_AND = 3'b010;
    localparam logic [2:0] ALU_OR  = 3'b011;
    localparam logic [2:0] ALU_XOR = 3'b100;

endpackage
