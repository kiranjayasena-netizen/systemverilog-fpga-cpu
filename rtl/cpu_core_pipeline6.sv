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
    output logic        debug_mem_write
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

    logic [31:0] retired_count_reg;

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

    // Phase 14B is a structural skeleton. It intentionally exposes no
    // architectural register-file or data-memory side effects yet.
    assign debug_reg_write = 1'b0;
    assign debug_mem_write = 1'b0;

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

        return stage;
    endfunction

    function automatic logic [31:0] sign_extend_imm13(input logic [12:0] imm13);
        sign_extend_imm13 = {{19{imm13[12]}}, imm13};
    endfunction

    function automatic pipe_stage_t decoded_stage(
        input logic        accept_response,
        input logic [31:0] response_pc,
        input logic [31:0] response_instruction
    );
        pipe_stage_t stage;
        logic [3:0] opcode;
        logic       valid_opcode;

        stage        = empty_stage();
        opcode       = response_instruction[31:28];
        valid_opcode = opcode_is_valid(opcode);

        if (accept_response && valid_opcode) begin
            stage.valid         = 1'b1;
            stage.pc            = response_pc;
            stage.instruction   = response_instruction;
            stage.opcode        = opcode;
            stage.rd            = response_instruction[27:23];
            stage.rs1           = response_instruction[22:18];
            stage.rs2           = response_instruction[17:13];
            stage.imm_ext       = sign_extend_imm13(response_instruction[12:0]);
            stage.decoded_valid = 1'b1;
            stage.writes_rd     = opcode_writes_rd(opcode);
            stage.uses_rs1      = opcode_uses_rs1(opcode);
            stage.uses_rs2      = opcode_uses_rs2(opcode);
        end

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
        end else if (enable) begin
            // bram_instruction is the synchronous response for the request
            // metadata saved on the previous enabled cycle.
            mem_wb_reg         <= ex_mem_reg;
            ex_mem_reg         <= op_ex_reg;
            op_ex_reg          <= id_op_reg;
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

            if (ex_mem_reg.valid) begin
                retired_count_reg <= retired_count_reg + 32'd1;
            end

            fetch_request_pc_reg    <= fetch_pc_reg;
            fetch_request_valid_reg <= 1'b1;
            fetch_pc_reg            <= fetch_pc_reg + 32'd4;
        end else begin
            debug_retire_valid <= 1'b0;

            if (fetch_request_valid_reg && !paused_response_valid_reg) begin
                paused_response_valid_reg       <= 1'b1;
                paused_response_pc_reg          <= fetch_request_pc_reg;
                paused_response_instruction_reg <= bram_instruction;
            end
        end
    end

endmodule
