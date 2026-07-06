module control_unit (
    input  logic [3:0] opcode,
    output logic       reg_write,
    output logic       use_imm,
    output logic [2:0] alu_op,
    output logic       valid_instr,
    output logic       mem_read,
    output logic       mem_write,
    output logic       mem_to_reg,
    output logic       branch,
    output logic       jump
);

    import cpu_defs_pkg::*;

    always_comb begin
        reg_write   = 1'b0;
        use_imm     = 1'b0;
        alu_op      = ALU_ADD;
        valid_instr = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;

        case (opcode)
            OP_NOP: begin
                valid_instr = 1'b1;
            end

            OP_ADD: begin
                reg_write   = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
            end

            OP_SUB: begin
                reg_write   = 1'b1;
                alu_op      = ALU_SUB;
                valid_instr = 1'b1;
            end

            OP_AND: begin
                reg_write   = 1'b1;
                alu_op      = ALU_AND;
                valid_instr = 1'b1;
            end

            OP_OR: begin
                reg_write   = 1'b1;
                alu_op      = ALU_OR;
                valid_instr = 1'b1;
            end

            OP_XOR: begin
                reg_write   = 1'b1;
                alu_op      = ALU_XOR;
                valid_instr = 1'b1;
            end

            OP_ADDI: begin
                reg_write   = 1'b1;
                use_imm     = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
            end

            OP_LOAD: begin
                reg_write   = 1'b1;
                use_imm     = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
                mem_read    = 1'b1;
                mem_to_reg  = 1'b1;
            end

            OP_STORE: begin
                use_imm     = 1'b1;
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
                mem_write   = 1'b1;
            end

            OP_BEQ: begin
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
                branch      = 1'b1;
            end

            OP_JUMP: begin
                alu_op      = ALU_ADD;
                valid_instr = 1'b1;
                jump        = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule
