`timescale 1ns / 1ps

module cpu_core_multicycle_bram #(
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256,
    parameter string       IMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
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
    output logic        mem_write,
    output logic [31:0] alu_result,
    output logic [31:0] memory_read_data,
    output logic [31:0] instruction_addr,
    output logic [31:0] data_addr
);

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH_ADDR    = 3'd0;
    localparam logic [2:0] STATE_FETCH_CAPTURE = 3'd1;
    localparam logic [2:0] STATE_DECODE        = 3'd2;
    localparam logic [2:0] STATE_EXECUTE       = 3'd3;
    localparam logic [2:0] STATE_MEMORY_ADDR   = 3'd4;
    localparam logic [2:0] STATE_MEMORY_CAPTURE = 3'd5;
    localparam logic [2:0] STATE_WRITEBACK     = 3'd6;

    logic [2:0]  state_next;
    logic [31:0] bram_instruction;
    logic [31:0] data_mem_read_data;
    logic        data_mem_read_en;
    logic [31:0] data_mem_write_data;

    logic [31:0] regs [0:31];
    logic [31:0] operand_a_reg;
    logic [31:0] operand_b_reg;
    logic [31:0] alu_result_reg;
    logic [31:0] memory_read_data_reg;

    integer reg_index;

    assign instruction_addr    = pc;
    assign data_addr           = alu_result_reg;
    assign data_mem_read_en    = enable && (state == STATE_MEMORY_ADDR) && valid_instr && (opcode_reg == OP_LOAD);
    assign mem_write           = enable && (state == STATE_MEMORY_ADDR) && valid_instr && (opcode_reg == OP_STORE);
    assign data_mem_write_data = operand_b_reg;
    assign reg_write           = enable &&
                                 (state == STATE_WRITEBACK) &&
                                 valid_instr &&
                                 (rd_reg != 5'd0) &&
                                 (opcode_is_arithmetic(opcode_reg) || (opcode_reg == OP_LOAD));
    assign alu_result          = alu_result_reg;
    assign memory_read_data    = memory_read_data_reg;

    bram_instr_mem #(
        .DEPTH(IMEM_DEPTH),
        .WIDTH(32),
        .INIT_FILE(IMEM_INIT_FILE),
        .NOP_INSTRUCTION(32'h0000_0000)
    ) instr_mem_inst (
        .clk(clk),
        .addr(instruction_addr),
        .instruction(bram_instruction)
    );

    bram_data_mem #(
        .DEPTH(DMEM_DEPTH),
        .WIDTH(32)
    ) data_mem_inst (
        .clk(clk),
        .mem_read(data_mem_read_en),
        .mem_write(mem_write),
        .addr(data_addr),
        .write_data(data_mem_write_data),
        .read_data(data_mem_read_data)
    );

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

    function automatic logic opcode_is_arithmetic(input logic [3:0] opcode);
        begin
            unique case (opcode)
                OP_ADD,
                OP_SUB,
                OP_AND,
                OP_OR,
                OP_XOR,
                OP_ADDI: opcode_is_arithmetic = 1'b1;
                default: opcode_is_arithmetic = 1'b0;
            endcase
        end
    endfunction

    function automatic logic [31:0] alu_execute(
        input logic [3:0]  opcode,
        input logic [31:0] operand_a,
        input logic [31:0] operand_b,
        input logic [31:0] immediate
    );
        begin
            unique case (opcode)
                OP_ADD: begin
                    alu_execute = operand_a + operand_b;
                end

                OP_SUB: begin
                    alu_execute = operand_a - operand_b;
                end

                OP_AND: begin
                    alu_execute = operand_a & operand_b;
                end

                OP_OR: begin
                    alu_execute = operand_a | operand_b;
                end

                OP_XOR: begin
                    alu_execute = operand_a ^ operand_b;
                end

                OP_ADDI: begin
                    alu_execute = operand_a + immediate;
                end

                default: begin
                    alu_execute = 32'h0000_0000;
                end
            endcase
        end
    endfunction

    always_comb begin
        state_next = state;

        unique case (state)
            STATE_FETCH_ADDR: begin
                state_next = STATE_FETCH_CAPTURE;
            end

            STATE_FETCH_CAPTURE: begin
                state_next = STATE_DECODE;
            end

            STATE_DECODE: begin
                unique case (instruction_reg[31:28])
                    OP_NOP: begin
                        state_next = STATE_FETCH_ADDR;
                    end

                    OP_ADD,
                    OP_SUB,
                    OP_AND,
                    OP_OR,
                    OP_XOR,
                    OP_ADDI,
                    OP_LOAD,
                    OP_STORE,
                    OP_BEQ,
                    OP_JUMP: begin
                        state_next = STATE_EXECUTE;
                    end

                    default: begin
                        state_next = STATE_FETCH_ADDR;
                    end
                endcase
            end

            STATE_EXECUTE: begin
                unique case (opcode_reg)
                    OP_LOAD,
                    OP_STORE: begin
                        state_next = STATE_MEMORY_ADDR;
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
                        state_next = STATE_FETCH_ADDR;
                    end

                    default: begin
                        state_next = STATE_FETCH_ADDR;
                    end
                endcase
            end

            STATE_MEMORY_ADDR: begin
                if (opcode_reg == OP_LOAD) begin
                    state_next = STATE_MEMORY_CAPTURE;
                end else begin
                    state_next = STATE_FETCH_ADDR;
                end
            end

            STATE_MEMORY_CAPTURE: begin
                state_next = STATE_WRITEBACK;
            end

            STATE_WRITEBACK: begin
                state_next = STATE_FETCH_ADDR;
            end

            default: begin
                state_next = STATE_FETCH_ADDR;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state                <= STATE_FETCH_ADDR;
            pc                   <= 32'h0000_0000;
            instruction_reg      <= 32'h0000_0000;
            instruction_pc       <= 32'h0000_0000;
            opcode_reg           <= OP_NOP;
            rd_reg               <= 5'd0;
            rs1_reg              <= 5'd0;
            rs2_reg              <= 5'd0;
            imm13_reg            <= 13'd0;
            imm_ext_reg          <= 32'h0000_0000;
            operand_a_reg        <= 32'h0000_0000;
            operand_b_reg        <= 32'h0000_0000;
            alu_result_reg       <= 32'h0000_0000;
            memory_read_data_reg <= 32'h0000_0000;
            valid_instr          <= 1'b0;

            for (reg_index = 0; reg_index < 32; reg_index = reg_index + 1) begin
                regs[reg_index] <= 32'h0000_0000;
            end
        end else begin
            regs[0] <= 32'h0000_0000;

            if (enable) begin
                state <= state_next;

                unique case (state)
                    STATE_FETCH_ADDR: begin
                        valid_instr <= 1'b0;
                    end

                    STATE_FETCH_CAPTURE: begin
                        instruction_reg <= bram_instruction;
                        instruction_pc  <= pc;
                        pc              <= pc + 32'd4;
                    end

                    STATE_DECODE: begin
                        opcode_reg  <= instruction_reg[31:28];
                        rd_reg      <= instruction_reg[27:23];
                        rs1_reg     <= instruction_reg[22:18];
                        rs2_reg     <= instruction_reg[17:13];
                        imm13_reg   <= instruction_reg[12:0];
                        imm_ext_reg <= {{19{instruction_reg[12]}}, instruction_reg[12:0]};
                        valid_instr <= opcode_is_valid(instruction_reg[31:28]);

                        if (instruction_reg[22:18] == 5'd0) begin
                            operand_a_reg <= 32'h0000_0000;
                        end else begin
                            operand_a_reg <= regs[instruction_reg[22:18]];
                        end

                        if (instruction_reg[17:13] == 5'd0) begin
                            operand_b_reg <= 32'h0000_0000;
                        end else begin
                            operand_b_reg <= regs[instruction_reg[17:13]];
                        end
                    end

                    STATE_EXECUTE: begin
                        if (valid_instr && opcode_is_arithmetic(opcode_reg)) begin
                            alu_result_reg <= alu_execute(
                                opcode_reg,
                                operand_a_reg,
                                operand_b_reg,
                                imm_ext_reg
                            );
                        end else if (valid_instr && ((opcode_reg == OP_LOAD) || (opcode_reg == OP_STORE))) begin
                            alu_result_reg <= operand_a_reg + imm_ext_reg;
                        end else if (valid_instr && (opcode_reg == OP_BEQ)) begin
                            alu_result_reg <= instruction_pc + (imm_ext_reg << 2);

                            if (operand_a_reg == operand_b_reg) begin
                                pc <= instruction_pc + (imm_ext_reg << 2);
                            end
                        end else if (valid_instr && (opcode_reg == OP_JUMP)) begin
                            alu_result_reg <= instruction_pc + (imm_ext_reg << 2);
                            pc             <= instruction_pc + (imm_ext_reg << 2);
                        end else begin
                            alu_result_reg <= 32'h0000_0000;
                        end
                    end

                    STATE_MEMORY_ADDR: begin
                    end

                    STATE_MEMORY_CAPTURE: begin
                        if (valid_instr && (opcode_reg == OP_LOAD)) begin
                            memory_read_data_reg <= data_mem_read_data;
                        end
                    end

                    STATE_WRITEBACK: begin
                        if (reg_write) begin
                            if (opcode_reg == OP_LOAD) begin
                                regs[rd_reg] <= memory_read_data_reg;
                            end else begin
                                regs[rd_reg] <= alu_result_reg;
                            end
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
