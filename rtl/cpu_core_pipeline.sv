import cpu_defs_pkg::*;

module cpu_core_pipeline #(
    parameter int unsigned IMEM_DEPTH = 256,
    parameter string       IMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    output logic [31:0] fetch_pc,
    output logic [31:0] instruction_addr,
    output logic [31:0] fetch_request_pc,
    output logic        fetch_request_valid,

    output logic        if_id_valid,
    output logic [31:0] if_id_pc,
    output logic [31:0] if_id_instruction,
    output logic [3:0]  decoded_opcode,
    output logic        decoded_valid,

    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [3:0]  retire_opcode,

    output logic        reg_write,
    output logic        mem_write,
    output logic        pc_redirect
);

    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'h0};

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instruction;
    } if_id_reg_t;

    if_id_reg_t if_id_reg;

    logic [31:0] bram_instruction;
    logic [3:0]  response_opcode;
    logic        response_opcode_valid;

    assign response_opcode       = bram_instruction[31:28];
    assign response_opcode_valid = opcode_is_valid(response_opcode);

    // The BRAM is synchronous: the instruction output belongs to the address
    // sampled on the previous clock edge.  When paused, hold the outstanding
    // request address on the BRAM port so its response stays paired with the
    // saved request PC until the pipeline is re-enabled.
    assign instruction_addr = enable ? fetch_pc : fetch_request_pc;

    assign if_id_valid       = if_id_reg.valid;
    assign if_id_pc          = if_id_reg.pc;
    assign if_id_instruction = if_id_reg.instruction;
    assign decoded_opcode    = if_id_reg.instruction[31:28];
    assign decoded_valid     = if_id_reg.valid && opcode_is_valid(decoded_opcode);

    // Phase 12B only proves fetch/decode/retirement safety. Architectural
    // side effects are intentionally disabled until later pipeline phases.
    assign reg_write   = 1'b0;
    assign mem_write   = 1'b0;
    assign pc_redirect = 1'b0;

    bram_instr_mem #(
        .DEPTH(IMEM_DEPTH),
        .WIDTH(32),
        .INIT_FILE(IMEM_INIT_FILE),
        .NOP_INSTRUCTION(NOP_INSTRUCTION)
    ) instr_mem_inst (
        .clk(clk),
        .addr(instruction_addr),
        .instruction(bram_instruction)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            fetch_pc            <= 32'h0000_0000;
            fetch_request_pc    <= 32'h0000_0000;
            fetch_request_valid <= 1'b0;

            if_id_reg.valid       <= 1'b0;
            if_id_reg.pc          <= 32'h0000_0000;
            if_id_reg.instruction <= NOP_INSTRUCTION;

            retire_valid  <= 1'b0;
            retire_pc     <= 32'h0000_0000;
            retire_opcode <= OP_NOP;
        end else if (enable) begin
            // Retire the previous IF/ID entry before replacing it. In Phase
            // 12B, only valid software NOPs retire; invalid instructions and
            // hardware bubbles never produce retirement events.
            retire_valid  <= if_id_reg.valid && (if_id_reg.instruction[31:28] == OP_NOP);
            retire_pc     <= if_id_reg.pc;
            retire_opcode <= if_id_reg.instruction[31:28];

            // Accept the BRAM response from the request metadata saved on the
            // previous enabled cycle. Invalid opcodes are converted into a
            // safe hardware bubble by clearing valid while retaining the
            // returned bits for debug visibility.
            if (fetch_request_valid) begin
                if_id_reg.valid       <= response_opcode_valid;
                if_id_reg.pc          <= fetch_request_pc;
                if_id_reg.instruction <= bram_instruction;
            end else begin
                if_id_reg.valid       <= 1'b0;
                if_id_reg.pc          <= 32'h0000_0000;
                if_id_reg.instruction <= NOP_INSTRUCTION;
            end

            // Launch one sequential fetch request. Later pipeline phases can
            // replace this unconditional accept with a stall-aware enable.
            fetch_request_pc    <= fetch_pc;
            fetch_request_valid <= 1'b1;
            fetch_pc            <= fetch_pc + 32'd4;
        end else begin
            // Pause freezes fetch and IF/ID state. Retirement is a pulse, so
            // it is deasserted while paused to avoid duplicate retire events.
            retire_valid <= 1'b0;
        end
    end

endmodule
