module control_unit (
    input  logic [3:0] opcode,
    output logic       reg_write,
    output logic       use_imm,
    output logic [2:0] alu_op,
    output logic       valid_instr,
    output logic       mem_read,
    output logic       mem_write,
    output logic       mem_to_reg
);

    localparam logic [2:0] ALU_ADD = 3'b000;
    localparam logic [2:0] ALU_SUB = 3'b001;
    localparam logic [2:0] ALU_AND = 3'b010;
    localparam logic [2:0] ALU_OR  = 3'b011;
    localparam logic [2:0] ALU_XOR = 3'b100;

    always_comb begin
        reg_write   = 1'b0;
        use_imm     = 1'b0;
        alu_op      = ALU_ADD;
        valid_instr = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;

        case (opcode)
            4'h0: begin
                valid_instr = 1'b1;
            end

            4'h1: begin
                reg_write   = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
            end

            4'h2: begin
                reg_write   = 1'b1;
                alu_op      = ALU_SUB;
                valid_instr = 1'b1;
            end

            4'h3: begin
                reg_write   = 1'b1;
                alu_op      = ALU_AND;
                valid_instr = 1'b1;
            end

            4'h4: begin
                reg_write   = 1'b1;
                alu_op      = ALU_OR;
                valid_instr = 1'b1;
            end

            4'h5: begin
                reg_write   = 1'b1;
                alu_op      = ALU_XOR;
                valid_instr = 1'b1;
            end

            4'h6: begin
                reg_write   = 1'b1;
                use_imm     = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
            end

            4'h7: begin
                reg_write   = 1'b1;
                use_imm     = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
                mem_read    = 1'b1;
                mem_to_reg  = 1'b1;
            end

            4'h8: begin
                use_imm     = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
                mem_write   = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule
