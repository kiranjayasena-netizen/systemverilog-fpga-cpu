import cpu_defs_pkg::*;

module cpu_core_pipeline6 #(
    parameter int unsigned IMEM_DEPTH = 256,
    parameter string       IMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    output logic [31:0] debug_fetch_pc,
    output logic [31:0] debug_instruction_addr,
    output logic        debug_fetch_request_valid,
    output logic [31:0] debug_fetch_request_pc,

    output logic        debug_if_id_valid,
    output logic        debug_id_op_valid,
    output logic        debug_op_ex_valid,
    output logic        debug_ex_mem_valid,
    output logic        debug_mem_wb_valid,

    output logic [31:0] debug_if_id_pc,
    output logic [31:0] debug_id_op_pc,
    output logic [31:0] debug_op_ex_pc,
    output logic [31:0] debug_ex_mem_pc,
    output logic [31:0] debug_mem_wb_pc,

    output logic [31:0] debug_if_id_instr,
    output logic [31:0] debug_id_op_instr,
    output logic [31:0] debug_op_ex_instr,
    output logic [31:0] debug_ex_mem_instr,
    output logic [31:0] debug_mem_wb_instr,

    output logic [3:0]  debug_if_id_opcode,
    output logic [3:0]  debug_id_op_opcode,
    output logic [3:0]  debug_op_ex_opcode,
    output logic [3:0]  debug_ex_mem_opcode,
    output logic [3:0]  debug_mem_wb_opcode,

    output logic        debug_if_id_decoded_valid,
    output logic        debug_id_op_decoded_valid,
    output logic        debug_op_ex_decoded_valid,
    output logic        debug_ex_mem_decoded_valid,
    output logic        debug_mem_wb_decoded_valid,

    output logic [31:0] debug_retired_count,
    output logic        debug_retire_valid,
    output logic [31:0] debug_retire_pc,
    output logic [3:0]  debug_retire_opcode,
    output logic        debug_reg_write,
    output logic        debug_mem_write,

    output logic        debug_writeback_valid,
    output logic [4:0]  debug_writeback_rd,
    output logic [31:0] debug_writeback_data,
    output logic        debug_stall_active,

    output logic [31:0] debug_x0,
    output logic [31:0] debug_x1,
    output logic [31:0] debug_x2,
    output logic [31:0] debug_x3,
    output logic [31:0] debug_x4,
    output logic [31:0] debug_x5,
    output logic [31:0] debug_x6,
    output logic [31:0] debug_x7,
    output logic [31:0] debug_x8,
    output logic [31:0] debug_x9,
    output logic [31:0] debug_x10,
    output logic [31:0] debug_x11,
    output logic [31:0] debug_x12,
    output logic [31:0] debug_x13
);

    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'd0};

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instruction;
        logic [3:0]  opcode;
        logic [4:0]  rd;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [31:0] imm_ext;
        logic        decoded_valid;
        logic        writes_rd;
        logic        uses_rs1;
        logic        uses_rs2;
        logic [31:0] operand_a;
        logic [31:0] operand_b;
        logic [31:0] alu_result;
        logic [31:0] writeback_data;
        logic        reg_write;
        logic        mem_write;
    } pipe_stage_t;

    logic [31:0] bram_instruction;
    logic [31:0] fetch_pc_reg;
    logic [31:0] fetch_request_pc_reg;
    logic        fetch_request_valid_reg;
    logic        paused_response_valid_reg;
    logic [31:0] paused_response_pc_reg;
    logic [31:0] paused_response_instruction_reg;

    pipe_stage_t if_id_reg;
    pipe_stage_t id_op_reg;
    pipe_stage_t op_ex_reg;
    pipe_stage_t ex_mem_reg;
    pipe_stage_t mem_wb_reg;

    logic [31:0] regs [0:31];
    logic [31:0] retired_count_reg;
    logic [31:0] op_ex_alu_result;

    assign debug_fetch_pc            = fetch_pc_reg;
    assign debug_instruction_addr    = fetch_pc_reg;
    assign debug_fetch_request_valid = fetch_request_valid_reg;
    assign debug_fetch_request_pc    = fetch_request_pc_reg;

    assign debug_if_id_valid         = if_id_reg.valid;
    assign debug_id_op_valid         = id_op_reg.valid;
    assign debug_op_ex_valid         = op_ex_reg.valid;
    assign debug_ex_mem_valid        = ex_mem_reg.valid;
    assign debug_mem_wb_valid        = mem_wb_reg.valid;

    assign debug_if_id_pc            = if_id_reg.pc;
    assign debug_id_op_pc            = id_op_reg.pc;
    assign debug_op_ex_pc            = op_ex_reg.pc;
    assign debug_ex_mem_pc           = ex_mem_reg.pc;
    assign debug_mem_wb_pc           = mem_wb_reg.pc;

    assign debug_if_id_instr         = if_id_reg.instruction;
    assign debug_id_op_instr         = id_op_reg.instruction;
    assign debug_op_ex_instr         = op_ex_reg.instruction;
    assign debug_ex_mem_instr        = ex_mem_reg.instruction;
    assign debug_mem_wb_instr        = mem_wb_reg.instruction;

    assign debug_if_id_opcode        = if_id_reg.opcode;
    assign debug_id_op_opcode        = id_op_reg.opcode;
    assign debug_op_ex_opcode        = op_ex_reg.opcode;
    assign debug_ex_mem_opcode       = ex_mem_reg.opcode;
    assign debug_mem_wb_opcode       = mem_wb_reg.opcode;

    assign debug_if_id_decoded_valid  = if_id_reg.decoded_valid;
    assign debug_id_op_decoded_valid  = id_op_reg.decoded_valid;
    assign debug_op_ex_decoded_valid  = op_ex_reg.decoded_valid;
    assign debug_ex_mem_decoded_valid = ex_mem_reg.decoded_valid;
    assign debug_mem_wb_decoded_valid = mem_wb_reg.decoded_valid;

    assign debug_retired_count = retired_count_reg;
    assign debug_stall_active  = 1'b0;
    assign debug_mem_write     = 1'b0;

    assign debug_x0  = 32'h0000_0000;
    assign debug_x1  = regs[1];
    assign debug_x2  = regs[2];
    assign debug_x3  = regs[3];
    assign debug_x4  = regs[4];
    assign debug_x5  = regs[5];
    assign debug_x6  = regs[6];
    assign debug_x7  = regs[7];
    assign debug_x8  = regs[8];
    assign debug_x9  = regs[9];
    assign debug_x10 = regs[10];
    assign debug_x11 = regs[11];
    assign debug_x12 = regs[12];
    assign debug_x13 = regs[13];

    bram_instr_mem #(
        .DEPTH(IMEM_DEPTH),
        .WIDTH(32),
        .INIT_FILE(IMEM_INIT_FILE),
        .NOP_INSTRUCTION(NOP_INSTRUCTION)
    ) instr_mem_inst (
        .clk(clk),
        .addr(debug_instruction_addr),
        .instruction(bram_instruction)
    );

    function automatic pipe_stage_t empty_stage();
        pipe_stage_t stage;

        stage.valid         = 1'b0;
        stage.pc            = 32'h0000_0000;
        stage.instruction   = NOP_INSTRUCTION;
        stage.opcode        = OP_NOP;
        stage.rd            = 5'd0;
        stage.rs1           = 5'd0;
        stage.rs2           = 5'd0;
        stage.imm_ext       = 32'h0000_0000;
        stage.decoded_valid = 1'b0;
        stage.writes_rd     = 1'b0;
        stage.uses_rs1      = 1'b0;
        stage.uses_rs2      = 1'b0;
        stage.operand_a      = 32'h0000_0000;
        stage.operand_b      = 32'h0000_0000;
        stage.alu_result     = 32'h0000_0000;
        stage.writeback_data = 32'h0000_0000;
        stage.reg_write      = 1'b0;
        stage.mem_write      = 1'b0;

        return stage;
    endfunction

    function automatic logic opcode_supported_phase14c(input logic [3:0] opcode);
        unique case (opcode)
            OP_NOP,
            OP_ADD,
            OP_SUB,
            OP_AND,
            OP_OR,
            OP_XOR,
            OP_ADDI: opcode_supported_phase14c = 1'b1;
            default: opcode_supported_phase14c = 1'b0;
        endcase
    endfunction

    function automatic logic [31:0] sign_extend_imm13(input logic [12:0] imm13);
        sign_extend_imm13 = {{19{imm13[12]}}, imm13};
    endfunction

    function automatic logic [31:0] alu_result_for_stage(input pipe_stage_t stage);
        unique case (stage.opcode)
            OP_ADD,
            OP_ADDI: alu_result_for_stage = stage.operand_a + stage.operand_b;
            OP_SUB:  alu_result_for_stage = stage.operand_a - stage.operand_b;
            OP_AND:  alu_result_for_stage = stage.operand_a & stage.operand_b;
            OP_OR:   alu_result_for_stage = stage.operand_a | stage.operand_b;
            OP_XOR:  alu_result_for_stage = stage.operand_a ^ stage.operand_b;
            default: alu_result_for_stage = 32'h0000_0000;
        endcase
    endfunction

    assign op_ex_alu_result = alu_result_for_stage(op_ex_reg);

    function automatic logic [31:0] read_reg_or_forward(
        input logic [4:0] source_reg,
        input logic       source_used
    );
        if (!source_used || (source_reg == 5'd0)) begin
            read_reg_or_forward = 32'h0000_0000;
        end else if (op_ex_reg.valid && op_ex_reg.writes_rd &&
                     (op_ex_reg.rd != 5'd0) && (op_ex_reg.rd == source_reg)) begin
            read_reg_or_forward = op_ex_alu_result;
        end else if (ex_mem_reg.valid && ex_mem_reg.writes_rd &&
                     (ex_mem_reg.rd != 5'd0) && (ex_mem_reg.rd == source_reg)) begin
            read_reg_or_forward = ex_mem_reg.writeback_data;
        end else if (mem_wb_reg.valid && mem_wb_reg.writes_rd &&
                     (mem_wb_reg.rd != 5'd0) && (mem_wb_reg.rd == source_reg)) begin
            read_reg_or_forward = mem_wb_reg.writeback_data;
        end else begin
            read_reg_or_forward = regs[source_reg];
        end
    endfunction

    function automatic pipe_stage_t decoded_stage(
        input logic        accept_response,
        input logic [31:0] response_pc,
        input logic [31:0] response_instruction
    );
        pipe_stage_t stage;
        logic [3:0] opcode;
        logic       supported_opcode;

        stage            = empty_stage();
        opcode           = response_instruction[31:28];
        supported_opcode = opcode_is_valid(opcode) && opcode_supported_phase14c(opcode);

        if (accept_response && supported_opcode) begin
            stage.valid         = 1'b1;
            stage.pc            = response_pc;
            stage.instruction   = response_instruction;
            stage.opcode        = opcode;
            stage.rd            = response_instruction[27:23];
            stage.rs1           = response_instruction[22:18];
            stage.rs2           = response_instruction[17:13];
            stage.imm_ext       = sign_extend_imm13(response_instruction[12:0]);
            stage.decoded_valid = 1'b1;
            stage.writes_rd     = opcode_writes_rd(opcode) && opcode_is_arithmetic(opcode);
            stage.uses_rs1      = opcode_uses_rs1(opcode);
            stage.uses_rs2      = opcode_uses_rs2(opcode);
        end

        return stage;
    endfunction

    function automatic pipe_stage_t prepare_operands(input pipe_stage_t stage_in);
        pipe_stage_t stage;

        stage = stage_in;
        stage.operand_a = read_reg_or_forward(stage_in.rs1, stage_in.uses_rs1);

        if (stage_in.opcode == OP_ADDI) begin
            stage.operand_b = stage_in.imm_ext;
        end else begin
            stage.operand_b = read_reg_or_forward(stage_in.rs2, stage_in.uses_rs2);
        end

        return stage;
    endfunction

    function automatic pipe_stage_t execute_stage(input pipe_stage_t stage_in);
        pipe_stage_t stage;

        stage = stage_in;
        stage.alu_result     = alu_result_for_stage(stage_in);
        stage.writeback_data = alu_result_for_stage(stage_in);
        stage.reg_write      = stage_in.valid && stage_in.writes_rd && (stage_in.rd != 5'd0);
        stage.mem_write      = 1'b0;

        return stage;
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            fetch_pc_reg            <= 32'h0000_0000;
            fetch_request_pc_reg    <= 32'h0000_0000;
            fetch_request_valid_reg <= 1'b0;
            paused_response_valid_reg <= 1'b0;
            paused_response_pc_reg    <= 32'h0000_0000;
            paused_response_instruction_reg <= NOP_INSTRUCTION;
            if_id_reg               <= empty_stage();
            id_op_reg               <= empty_stage();
            op_ex_reg               <= empty_stage();
            ex_mem_reg              <= empty_stage();
            mem_wb_reg              <= empty_stage();
            retired_count_reg       <= 32'd0;
            debug_retire_valid      <= 1'b0;
            debug_retire_pc         <= 32'h0000_0000;
            debug_retire_opcode     <= OP_NOP;
            debug_reg_write         <= 1'b0;
            debug_writeback_valid   <= 1'b0;
            debug_writeback_rd      <= 5'd0;
            debug_writeback_data    <= 32'h0000_0000;

            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if (enable) begin
            // bram_instruction is the synchronous response for the request
            // metadata saved on the previous enabled cycle.
            mem_wb_reg         <= ex_mem_reg;
            ex_mem_reg         <= execute_stage(op_ex_reg);
            op_ex_reg          <= prepare_operands(id_op_reg);
            id_op_reg          <= if_id_reg;
            if_id_reg          <= decoded_stage(
                paused_response_valid_reg || fetch_request_valid_reg,
                paused_response_valid_reg ? paused_response_pc_reg : fetch_request_pc_reg,
                paused_response_valid_reg ? paused_response_instruction_reg : bram_instruction
            );
            paused_response_valid_reg <= 1'b0;

            debug_retire_valid <= ex_mem_reg.valid;
            debug_retire_pc    <= ex_mem_reg.pc;
            debug_retire_opcode <= ex_mem_reg.opcode;
            debug_reg_write <= ex_mem_reg.valid && ex_mem_reg.reg_write;
            debug_writeback_valid <= ex_mem_reg.valid && ex_mem_reg.reg_write;
            debug_writeback_rd <= ex_mem_reg.rd;
            debug_writeback_data <= ex_mem_reg.writeback_data;

            if (ex_mem_reg.valid) begin
                retired_count_reg <= retired_count_reg + 32'd1;
            end

            if (ex_mem_reg.valid && ex_mem_reg.reg_write) begin
                regs[ex_mem_reg.rd] <= ex_mem_reg.writeback_data;
            end
            regs[0] <= 32'h0000_0000;

            fetch_request_pc_reg    <= fetch_pc_reg;
            fetch_request_valid_reg <= 1'b1;
            fetch_pc_reg            <= fetch_pc_reg + 32'd4;
        end else begin
            debug_retire_valid <= 1'b0;
            debug_reg_write <= 1'b0;
            debug_writeback_valid <= 1'b0;
            regs[0] <= 32'h0000_0000;

            if (fetch_request_valid_reg && !paused_response_valid_reg) begin
                paused_response_valid_reg       <= 1'b1;
                paused_response_pc_reg          <= fetch_request_pc_reg;
                paused_response_instruction_reg <= bram_instruction;
            end
        end
    end

endmodule
