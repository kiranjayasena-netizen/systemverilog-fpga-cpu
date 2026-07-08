`timescale 1ns / 1ps

module cpu_core_multicycle (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    input  logic [31:0] fetched_instruction,
    output logic [31:0] instruction_addr,
    output logic [2:0]  state,
    output logic [31:0] pc,
    output logic [31:0] instruction_reg,
    output logic [31:0] instruction_pc,
    output logic [3:0]  opcode_reg,
    output logic [4:0]  rd_reg,
    output logic [4:0]  rs1_reg,
    output logic [4:0]  rs2_reg,
    output logic [12:0] imm13_reg,
    output logic [31:0] imm_ext_reg,
    output logic        valid_instr,
    output logic        reg_write,
    output logic        mem_write
);

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH     = 3'd0;
    localparam logic [2:0] STATE_DECODE    = 3'd1;
    localparam logic [2:0] STATE_EXECUTE   = 3'd2;
    localparam logic [2:0] STATE_MEMORY    = 3'd3;
    localparam logic [2:0] STATE_WRITEBACK = 3'd4;

    logic [2:0] state_next;

    assign instruction_addr = pc;

    function automatic logic opcode_is_valid(input logic [3:0] opcode);
        begin
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
        end
    endfunction

    always_comb begin
        state_next = state;

        unique case (state)
            STATE_FETCH: begin
                state_next = STATE_DECODE;
            end

            STATE_DECODE: begin
                unique case (instruction_reg[31:28])
                    OP_NOP: begin
                        state_next = STATE_FETCH;
                    end

                    OP_ADD,
                    OP_SUB,
                    OP_AND,
                    OP_OR,
                    OP_XOR,
                    OP_ADDI,
                    OP_BEQ,
                    OP_JUMP: begin
                        state_next = STATE_EXECUTE;
                    end

                    OP_LOAD,
                    OP_STORE: begin
                        state_next = STATE_EXECUTE;
                    end

                    default: begin
                        state_next = STATE_FETCH;
                    end
                endcase
            end

            STATE_EXECUTE: begin
                unique case (opcode_reg)
                    OP_LOAD,
                    OP_STORE: begin
                        state_next = STATE_MEMORY;
                    end

                    OP_ADD,
                    OP_SUB,
                    OP_AND,
                    OP_OR,
                    OP_XOR,
                    OP_ADDI: begin
                        state_next = STATE_WRITEBACK;
                    end

                    OP_BEQ,
                    OP_JUMP: begin
                        state_next = STATE_FETCH;
                    end

                    default: begin
                        state_next = STATE_FETCH;
                    end
                endcase
            end

            STATE_MEMORY: begin
                if (opcode_reg == OP_LOAD) begin
                    state_next = STATE_WRITEBACK;
                end else begin
                    state_next = STATE_FETCH;
                end
            end

            STATE_WRITEBACK: begin
                state_next = STATE_FETCH;
            end

            default: begin
                state_next = STATE_FETCH;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= STATE_FETCH;
            pc              <= 32'h0000_0000;
            instruction_reg <= 32'h0000_0000;
            instruction_pc  <= 32'h0000_0000;
            opcode_reg      <= OP_NOP;
            rd_reg          <= 5'd0;
            rs1_reg         <= 5'd0;
            rs2_reg         <= 5'd0;
            imm13_reg       <= 13'd0;
            imm_ext_reg     <= 32'h0000_0000;
            valid_instr     <= 1'b0;
            reg_write       <= 1'b0;
            mem_write       <= 1'b0;
        end else begin
            reg_write <= 1'b0;
            mem_write <= 1'b0;

            if (enable) begin
                state <= state_next;

                unique case (state)
                    STATE_FETCH: begin
                        instruction_reg <= fetched_instruction;
                        instruction_pc  <= pc;
                        pc              <= pc + 32'd4;
                        valid_instr     <= 1'b0;
                    end

                    STATE_DECODE: begin
                        opcode_reg  <= instruction_reg[31:28];
                        rd_reg      <= instruction_reg[27:23];
                        rs1_reg     <= instruction_reg[22:18];
                        rs2_reg     <= instruction_reg[17:13];
                        imm13_reg   <= instruction_reg[12:0];
                        imm_ext_reg <= {{19{instruction_reg[12]}}, instruction_reg[12:0]};
                        valid_instr <= opcode_is_valid(instruction_reg[31:28]);
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
