import cpu_defs_pkg::*;

module cpu_core_pipeline_targetbuf_reg #(
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256,
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

    output logic        id_ex_valid,
    output logic        ex_mem_valid,
    output logic        mem_wb_valid,
    output logic [31:0] alu_result,
    output logic [31:0] data_addr,
    output logic [31:0] memory_read_data,

    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [3:0]  retire_opcode,
    output logic [4:0]  retire_rd,
    output logic        retire_reg_write,
    output logic [31:0] retire_write_data,
    output logic        retire_mem_write,
    output logic [31:0] retire_mem_addr,
    output logic [31:0] retire_mem_data,

    output logic        reg_write,
    output logic        mem_write,
    output logic        pc_redirect,

    output logic [31:0] total_cycles,
    output logic [31:0] retired_instructions,
    output logic [31:0] pipeline_fill_cycles,
    output logic [31:0] data_hazard_stall_cycles,
    output logic [31:0] load_use_stall_cycles,
    output logic [31:0] control_hazard_flush_cycles,
    output logic [31:0] instruction_fetch_wait_cycles,
    output logic [31:0] memory_wait_cycles,
    output logic [31:0] taken_branches,
    output logic [31:0] not_taken_branches,
    output logic [31:0] jumps,
    output logic [31:0] wrong_path_instructions_flushed,
    output logic [31:0] target_buffer_hits,
    output logic [31:0] target_buffer_misses
);

    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'h0};

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instruction;
    } if_id_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instruction;
        logic [3:0]  opcode;
        logic [4:0]  rd;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [31:0] imm_ext;
        logic [31:0] operand_a;
        logic [31:0] operand_b;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic        mem_to_reg;
        logic        use_imm;
        logic        branch;
        logic        jump;
    } id_ex_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [3:0]  opcode;
        logic [4:0]  rd;
        logic [31:0] alu_result;
        logic [31:0] store_data;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic        mem_to_reg;
    } ex_mem_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [3:0]  opcode;
        logic [4:0]  rd;
        logic [31:0] alu_result;
        logic [31:0] store_data;
        logic        reg_write;
        logic        mem_write;
        logic        mem_to_reg;
    } mem_wb_reg_t;

    if_id_reg_t  if_id_reg;
    id_ex_reg_t  id_ex_reg;
    ex_mem_reg_t ex_mem_reg;
    mem_wb_reg_t mem_wb_reg;

    logic [31:0] regs [0:31];

    logic [31:0] bram_instruction;
    logic [31:0] fetch_pending_pc;
    logic        fetch_pending_valid;
    logic        fetch_buffer_valid;
    logic [31:0] fetch_buffer_pc;
    logic [31:0] fetch_buffer_instruction;
    logic        fetch_buffer_is_target;
    logic        redirect_pending_valid;
    logic [31:0] redirect_pending_target;
    logic        redirect_pending_is_jump;
    logic        jump_response_pending;
    logic [31:0] jump_response_pc;
    logic        fetch_pending_is_target;
    logic        target_buffer_valid;
    logic [31:0] target_buffer_pc;
    logic [31:0] target_buffer_instruction;
    logic        targetbuf_lookup_valid;
    logic        targetbuf_lookup_hit;
    logic [31:0] targetbuf_lookup_pc;
    logic [31:0] targetbuf_lookup_instruction;

    logic [31:0] data_mem_read_data;
    logic        data_mem_read_en;
    logic        data_mem_write_en;
    logic [31:0] data_mem_write_data;

    logic [3:0]  if_id_opcode;
    logic [4:0]  if_id_rd;
    logic [4:0]  if_id_rs1;
    logic [4:0]  if_id_rs2;
    logic [12:0] if_id_imm13;
    logic [31:0] if_id_imm_ext;
    logic        if_id_opcode_valid;
    logic        if_id_uses_rs1;
    logic        if_id_uses_rs2;
    logic        load_use_stall;
    logic        decode_stall;

    logic [31:0] wb_write_data;
    logic [31:0] wb_alu_write_data;
    logic [31:0] wb_load_write_data;
    logic        wb_writes_rd;
    logic        wb_is_load;
    logic        wb_is_alu;
    logic        decode_rs1_wb_match;
    logic        decode_rs2_wb_match;
    logic        decode_rs1_wb_load;
    logic        decode_rs1_wb_alu;
    logic        decode_rs2_wb_load;
    logic        decode_rs2_wb_alu;
    logic [31:0] decode_operand_a;
    logic [31:0] decode_operand_b;

    logic [31:0] ex_operand_a;
    logic [31:0] ex_operand_b_reg;
    logic [31:0] ex_operand_b;
    logic [31:0] ex_store_data;
    logic        ex_rs1_wb_match;
    logic        ex_rs2_wb_match;
    logic        ex_rs1_wb_load;
    logic        ex_rs1_wb_alu;
    logic        ex_rs2_wb_load;
    logic        ex_rs2_wb_alu;
    logic [31:0] ex_alu_result;
    logic        ex_branch_taken;
    logic        ex_jump_taken;
    logic        ex_redirect_taken;
    logic        id_jump_fast_request;
    logic        id_jump_redirect;
    logic        redirect_taken;
    logic [31:0] ex_redirect_target;
    logic [31:0] id_jump_target;
    logic [31:0] redirect_target;

    logic [31:0] next_instruction_addr;
    logic        accept_fetch_response;
    logic [31:0] accepted_fetch_pc;
    logic [31:0] accepted_fetch_instruction;
    logic        accepted_fetch_is_target;
    logic        redirect_target_buffer_hit;

    assign fetch_request_pc    = fetch_pending_pc;
    assign fetch_request_valid = fetch_pending_valid;

    assign if_id_valid       = if_id_reg.valid;
    assign if_id_pc          = if_id_reg.pc;
    assign if_id_instruction = if_id_reg.instruction;
    assign decoded_opcode    = if_id_opcode;
    assign decoded_valid     = if_id_reg.valid && if_id_opcode_valid;

    assign id_ex_valid  = id_ex_reg.valid;
    assign ex_mem_valid = ex_mem_reg.valid;
    assign mem_wb_valid = mem_wb_reg.valid;

    assign alu_result       = ex_mem_reg.alu_result;
    assign data_addr        = ex_mem_reg.alu_result;
    assign memory_read_data = data_mem_read_data;

    assign reg_write = enable &&
                       mem_wb_reg.valid &&
                       mem_wb_reg.reg_write &&
                       (mem_wb_reg.rd != 5'd0);
    assign mem_write = data_mem_write_en;

    assign if_id_opcode = if_id_reg.instruction[31:28];
    assign if_id_rd     = if_id_reg.instruction[27:23];
    assign if_id_rs1    = if_id_reg.instruction[22:18];
    assign if_id_rs2    = if_id_reg.instruction[17:13];
    assign if_id_imm13  = if_id_reg.instruction[12:0];
    assign if_id_imm_ext = {{19{if_id_imm13[12]}}, if_id_imm13};

    assign if_id_opcode_valid = opcode_is_valid(if_id_opcode);
    assign if_id_uses_rs1     = opcode_uses_rs1(if_id_opcode);
    assign if_id_uses_rs2     = opcode_uses_rs2(if_id_opcode);

    assign wb_writes_rd  = mem_wb_reg.valid &&
                           mem_wb_reg.reg_write &&
                           (mem_wb_reg.rd != 5'd0);
    assign wb_alu_write_data  = mem_wb_reg.alu_result;
    assign wb_load_write_data = data_mem_read_data;
    assign wb_is_load = wb_writes_rd && mem_wb_reg.mem_to_reg;
    assign wb_is_alu  = wb_writes_rd && !mem_wb_reg.mem_to_reg;
    assign wb_write_data = wb_is_load ? wb_load_write_data : wb_alu_write_data;

    // Phase 13G keeps the Phase 13C WB-to-ID bypass behaviour, but splits
    // the load and ALU writeback sources before the decode/EX muxes. This
    // preserves CPI while giving Vivado smaller local selects to optimise.
    assign decode_rs1_wb_match = if_id_uses_rs1 &&
                                 wb_writes_rd &&
                                 (mem_wb_reg.rd == if_id_rs1);
    assign decode_rs2_wb_match = if_id_uses_rs2 &&
                                 wb_writes_rd &&
                                 (mem_wb_reg.rd == if_id_rs2);
    assign decode_rs1_wb_load = decode_rs1_wb_match && wb_is_load;
    assign decode_rs1_wb_alu  = decode_rs1_wb_match && wb_is_alu;
    assign decode_rs2_wb_load = decode_rs2_wb_match && wb_is_load;
    assign decode_rs2_wb_alu  = decode_rs2_wb_match && wb_is_alu;

    assign ex_rs1_wb_match = wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rs1);
    assign ex_rs2_wb_match = wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rs2);
    assign ex_rs1_wb_load  = ex_rs1_wb_match && wb_is_load;
    assign ex_rs1_wb_alu   = ex_rs1_wb_match && wb_is_alu;
    assign ex_rs2_wb_load  = ex_rs2_wb_match && wb_is_load;
    assign ex_rs2_wb_alu   = ex_rs2_wb_match && wb_is_alu;

    assign decode_operand_a =
        (if_id_rs1 == 5'd0) ? 32'h0000_0000 :
        decode_rs1_wb_load ? wb_load_write_data :
        decode_rs1_wb_alu  ? wb_alu_write_data :
        regs[if_id_rs1];

    assign decode_operand_b =
        (if_id_rs2 == 5'd0) ? 32'h0000_0000 :
        decode_rs2_wb_load ? wb_load_write_data :
        decode_rs2_wb_alu  ? wb_alu_write_data :
        regs[if_id_rs2];

    assign load_use_stall =
        if_id_reg.valid &&
        if_id_opcode_valid &&
        id_ex_reg.valid &&
        id_ex_reg.mem_read &&
        (id_ex_reg.rd != 5'd0) &&
        ((if_id_uses_rs1 && (if_id_rs1 == id_ex_reg.rd)) ||
         (if_id_uses_rs2 && (if_id_rs2 == id_ex_reg.rd)));

    // A load-use dependency needs one bubble because data BRAM read data is
    // returned after the consuming instruction would otherwise enter EX.
    assign decode_stall = load_use_stall;

    always_comb begin
        ex_operand_a     = id_ex_reg.operand_a;
        ex_operand_b_reg = id_ex_reg.operand_b;

        if (ex_mem_reg.valid &&
            ex_mem_reg.reg_write &&
            !ex_mem_reg.mem_to_reg &&
            (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs1)) begin
            ex_operand_a = ex_mem_reg.alu_result;
        end else if (ex_rs1_wb_load) begin
            ex_operand_a = wb_load_write_data;
        end else if (ex_rs1_wb_alu) begin
            ex_operand_a = wb_alu_write_data;
        end

        if (ex_mem_reg.valid &&
            ex_mem_reg.reg_write &&
            !ex_mem_reg.mem_to_reg &&
            (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs2)) begin
            ex_operand_b_reg = ex_mem_reg.alu_result;
        end else if (ex_rs2_wb_load) begin
            ex_operand_b_reg = wb_load_write_data;
        end else if (ex_rs2_wb_alu) begin
            ex_operand_b_reg = wb_alu_write_data;
        end

        ex_operand_b  = id_ex_reg.use_imm ? id_ex_reg.imm_ext : ex_operand_b_reg;
        ex_store_data = ex_operand_b_reg;
    end

    always_comb begin
        unique case (id_ex_reg.opcode)
            OP_ADD,
            OP_ADDI,
            OP_LOAD,
            OP_STORE: ex_alu_result = ex_operand_a + ex_operand_b;
            OP_SUB:   ex_alu_result = ex_operand_a - ex_operand_b;
            OP_AND:   ex_alu_result = ex_operand_a & ex_operand_b;
            OP_OR:    ex_alu_result = ex_operand_a | ex_operand_b;
            OP_XOR:   ex_alu_result = ex_operand_a ^ ex_operand_b;
            default:  ex_alu_result = 32'h0000_0000;
        endcase
    end

    assign ex_branch_taken = id_ex_reg.valid &&
                             id_ex_reg.branch &&
                             (ex_operand_a == ex_operand_b_reg);
    assign ex_jump_taken   = id_ex_reg.valid && id_ex_reg.jump;
    assign ex_redirect_taken = ex_branch_taken || ex_jump_taken;
    assign ex_redirect_target = id_ex_reg.pc + (id_ex_reg.imm_ext << 2);
    assign id_jump_target = if_id_reg.pc + (if_id_imm_ext << 2);
    // Keep the instruction-BRAM address path timing-friendly by avoiding the
    // forwarded BEQ compare result in the raw fast JUMP request. If an older
    // EX redirect wins, the sequential EX redirect branch discards this
    // wrong-path request before a response can be consumed.
    assign id_jump_fast_request = if_id_reg.valid &&
                                  if_id_opcode_valid &&
                                  (if_id_opcode == OP_JUMP) &&
                                  !decode_stall &&
                                  !jump_response_pending &&
                                  !redirect_pending_valid;
    assign id_jump_redirect = id_jump_fast_request && !ex_redirect_taken;
    assign redirect_taken  = ex_redirect_taken || id_jump_redirect;
    assign redirect_target = ex_redirect_taken ? ex_redirect_target : id_jump_target;
    assign pc_redirect     = enable && redirect_taken;
    // Phase 13G does the target-buffer comparison in the ID-stage JUMP cycle,
    // but registers the hit result before consuming the buffered instruction.
    // This avoids the Phase 13F same-cycle compare -> IF/ID injection path.
    assign redirect_target_buffer_hit = id_jump_redirect &&
                                        target_buffer_valid &&
                                        (target_buffer_pc == id_jump_target);

    assign data_mem_read_en    = enable && ex_mem_reg.valid && ex_mem_reg.mem_read;
    assign data_mem_write_en   = enable && ex_mem_reg.valid && ex_mem_reg.mem_write;
    assign data_mem_write_data = ex_mem_reg.store_data;

    always_comb begin
        if (targetbuf_lookup_valid && targetbuf_lookup_hit) begin
            // Registered target-buffer hit: inject the saved target into
            // IF/ID at this edge and request the following sequential word.
            next_instruction_addr = targetbuf_lookup_pc + 32'd4;
        end else if (id_jump_fast_request) begin
            next_instruction_addr = id_jump_target;
        end else if (jump_response_pending && !enable) begin
            next_instruction_addr = jump_response_pc;
        end else if (redirect_pending_valid) begin
            next_instruction_addr = redirect_pending_target;
        end else if (decode_stall || !enable) begin
            next_instruction_addr = fetch_pending_pc;
        end else begin
            next_instruction_addr = fetch_pc;
        end
    end

    assign instruction_addr = next_instruction_addr;

    always_comb begin
        accept_fetch_response     = 1'b0;
        accepted_fetch_pc         = 32'h0000_0000;
        accepted_fetch_instruction = NOP_INSTRUCTION;
        accepted_fetch_is_target   = 1'b0;

        if (targetbuf_lookup_valid && targetbuf_lookup_hit) begin
            accept_fetch_response      = 1'b1;
            accepted_fetch_pc          = targetbuf_lookup_pc;
            accepted_fetch_instruction = targetbuf_lookup_instruction;
            accepted_fetch_is_target   = 1'b0;
        end else if (fetch_buffer_valid) begin
            accept_fetch_response      = 1'b1;
            accepted_fetch_pc          = fetch_buffer_pc;
            accepted_fetch_instruction = fetch_buffer_instruction;
            accepted_fetch_is_target   = fetch_buffer_is_target;
        end else if (jump_response_pending) begin
            accept_fetch_response      = 1'b1;
            accepted_fetch_pc          = jump_response_pc;
            accepted_fetch_instruction = bram_instruction;
            accepted_fetch_is_target   = 1'b1;
        end else if (fetch_pending_valid) begin
            accept_fetch_response      = 1'b1;
            accepted_fetch_pc          = fetch_pending_pc;
            accepted_fetch_instruction = bram_instruction;
            accepted_fetch_is_target   = fetch_pending_is_target;
        end
    end

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

    bram_data_mem #(
        .DEPTH(DMEM_DEPTH),
        .WIDTH(32)
    ) data_mem_inst (
        .clk(clk),
        .mem_read(data_mem_read_en),
        .mem_write(data_mem_write_en),
        .addr(ex_mem_reg.alu_result),
        .write_data(data_mem_write_data),
        .read_data(data_mem_read_data)
    );

    task automatic clear_id_ex();
        begin
            id_ex_reg.valid       <= 1'b0;
            id_ex_reg.pc          <= 32'h0000_0000;
            id_ex_reg.instruction <= NOP_INSTRUCTION;
            id_ex_reg.opcode      <= OP_NOP;
            id_ex_reg.rd          <= 5'd0;
            id_ex_reg.rs1         <= 5'd0;
            id_ex_reg.rs2         <= 5'd0;
            id_ex_reg.imm_ext     <= 32'h0000_0000;
            id_ex_reg.operand_a   <= 32'h0000_0000;
            id_ex_reg.operand_b   <= 32'h0000_0000;
            id_ex_reg.reg_write   <= 1'b0;
            id_ex_reg.mem_read    <= 1'b0;
            id_ex_reg.mem_write   <= 1'b0;
            id_ex_reg.mem_to_reg  <= 1'b0;
            id_ex_reg.use_imm     <= 1'b0;
            id_ex_reg.branch      <= 1'b0;
            id_ex_reg.jump        <= 1'b0;
        end
    endtask

    task automatic bubble_id_ex();
        begin
            id_ex_reg.valid      <= 1'b0;
            id_ex_reg.reg_write  <= 1'b0;
            id_ex_reg.mem_read   <= 1'b0;
            id_ex_reg.mem_write  <= 1'b0;
            id_ex_reg.mem_to_reg <= 1'b0;
            id_ex_reg.branch     <= 1'b0;
            id_ex_reg.jump       <= 1'b0;
        end
    endtask

    task automatic clear_ex_mem();
        begin
            ex_mem_reg.valid      <= 1'b0;
            ex_mem_reg.pc         <= 32'h0000_0000;
            ex_mem_reg.opcode     <= OP_NOP;
            ex_mem_reg.rd         <= 5'd0;
            ex_mem_reg.alu_result <= 32'h0000_0000;
            ex_mem_reg.store_data <= 32'h0000_0000;
            ex_mem_reg.reg_write  <= 1'b0;
            ex_mem_reg.mem_read   <= 1'b0;
            ex_mem_reg.mem_write  <= 1'b0;
            ex_mem_reg.mem_to_reg <= 1'b0;
        end
    endtask

    task automatic clear_mem_wb();
        begin
            mem_wb_reg.valid      <= 1'b0;
            mem_wb_reg.pc         <= 32'h0000_0000;
            mem_wb_reg.opcode     <= OP_NOP;
            mem_wb_reg.rd         <= 5'd0;
            mem_wb_reg.alu_result <= 32'h0000_0000;
            mem_wb_reg.store_data <= 32'h0000_0000;
            mem_wb_reg.reg_write  <= 1'b0;
            mem_wb_reg.mem_write  <= 1'b0;
            mem_wb_reg.mem_to_reg <= 1'b0;
        end
    endtask

    always_ff @(posedge clk) begin
        if (rst) begin
            fetch_pc                 <= 32'h0000_0000;
            fetch_pending_pc         <= 32'h0000_0000;
            fetch_pending_valid      <= 1'b0;
            fetch_pending_is_target  <= 1'b0;
            fetch_buffer_valid       <= 1'b0;
            fetch_buffer_pc          <= 32'h0000_0000;
            fetch_buffer_instruction <= NOP_INSTRUCTION;
            fetch_buffer_is_target   <= 1'b0;
            redirect_pending_valid   <= 1'b0;
            redirect_pending_target  <= 32'h0000_0000;
            redirect_pending_is_jump <= 1'b0;
            jump_response_pending    <= 1'b0;
            jump_response_pc         <= 32'h0000_0000;
            target_buffer_valid       <= 1'b0;
            target_buffer_pc          <= 32'h0000_0000;
            target_buffer_instruction <= NOP_INSTRUCTION;
            targetbuf_lookup_valid       <= 1'b0;
            targetbuf_lookup_hit         <= 1'b0;
            targetbuf_lookup_pc          <= 32'h0000_0000;
            targetbuf_lookup_instruction <= NOP_INSTRUCTION;

            if_id_reg.valid       <= 1'b0;
            if_id_reg.pc          <= 32'h0000_0000;
            if_id_reg.instruction <= NOP_INSTRUCTION;

            clear_id_ex();
            clear_ex_mem();
            clear_mem_wb();

            retire_valid      <= 1'b0;
            retire_pc         <= 32'h0000_0000;
            retire_opcode     <= OP_NOP;
            retire_rd         <= 5'd0;
            retire_reg_write  <= 1'b0;
            retire_write_data <= 32'h0000_0000;
            retire_mem_write  <= 1'b0;
            retire_mem_addr   <= 32'h0000_0000;
            retire_mem_data   <= 32'h0000_0000;

            total_cycles                    <= 32'd0;
            retired_instructions            <= 32'd0;
            pipeline_fill_cycles            <= 32'd0;
            data_hazard_stall_cycles        <= 32'd0;
            load_use_stall_cycles           <= 32'd0;
            control_hazard_flush_cycles     <= 32'd0;
            instruction_fetch_wait_cycles   <= 32'd0;
            memory_wait_cycles              <= 32'd0;
            taken_branches                  <= 32'd0;
            not_taken_branches              <= 32'd0;
            jumps                           <= 32'd0;
            wrong_path_instructions_flushed <= 32'd0;
            target_buffer_hits              <= 32'd0;
            target_buffer_misses            <= 32'd0;

            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if (enable) begin
            total_cycles <= total_cycles + 32'd1;
            if (retired_instructions == 32'd0) begin
                pipeline_fill_cycles <= pipeline_fill_cycles + 32'd1;
            end

            retire_valid      <= mem_wb_reg.valid;
            retire_pc         <= mem_wb_reg.pc;
            retire_opcode     <= mem_wb_reg.opcode;
            retire_rd         <= mem_wb_reg.rd;
            retire_reg_write  <= mem_wb_reg.valid && mem_wb_reg.reg_write && (mem_wb_reg.rd != 5'd0);
            retire_write_data <= wb_write_data;
            retire_mem_write  <= mem_wb_reg.valid && mem_wb_reg.mem_write;
            retire_mem_addr   <= mem_wb_reg.alu_result;
            retire_mem_data   <= mem_wb_reg.store_data;

            if (mem_wb_reg.valid) begin
                retired_instructions <= retired_instructions + 32'd1;
            end

            if (wb_writes_rd) begin
                regs[mem_wb_reg.rd] <= wb_write_data;
            end
            regs[0] <= 32'h0000_0000;

            if (decode_stall) begin
                data_hazard_stall_cycles <= data_hazard_stall_cycles + 32'd1;
                memory_wait_cycles       <= memory_wait_cycles + 32'd1;
            end
            if (load_use_stall) begin
                load_use_stall_cycles <= load_use_stall_cycles + 32'd1;
            end

            if (redirect_taken) begin
                control_hazard_flush_cycles <= control_hazard_flush_cycles + 32'd1;
                if (id_jump_redirect && redirect_target_buffer_hit) begin
                    target_buffer_hits <= target_buffer_hits + 32'd1;
                end else if (id_jump_redirect) begin
                    target_buffer_misses <= target_buffer_misses + 32'd1;
                end
                if (ex_redirect_taken) begin
                    wrong_path_instructions_flushed <= wrong_path_instructions_flushed +
                        {31'd0, if_id_reg.valid} +
                        {31'd0, fetch_pending_valid} +
                        {31'd0, fetch_buffer_valid};
                end else begin
                    wrong_path_instructions_flushed <= wrong_path_instructions_flushed +
                        {31'd0, fetch_pending_valid} +
                        {31'd0, fetch_buffer_valid};
                end
            end

            if (id_ex_reg.valid && id_ex_reg.branch) begin
                if (ex_branch_taken) begin
                    taken_branches <= taken_branches + 32'd1;
                end else begin
                    not_taken_branches <= not_taken_branches + 32'd1;
                end
            end

            if ((id_ex_reg.valid && id_ex_reg.jump) || id_jump_redirect) begin
                jumps <= jumps + 32'd1;
            end

            mem_wb_reg.valid      <= ex_mem_reg.valid;
            mem_wb_reg.pc         <= ex_mem_reg.pc;
            mem_wb_reg.opcode     <= ex_mem_reg.opcode;
            mem_wb_reg.rd         <= ex_mem_reg.rd;
            mem_wb_reg.alu_result <= ex_mem_reg.alu_result;
            mem_wb_reg.store_data <= ex_mem_reg.store_data;
            mem_wb_reg.reg_write  <= ex_mem_reg.reg_write;
            mem_wb_reg.mem_write  <= ex_mem_reg.mem_write;
            mem_wb_reg.mem_to_reg <= ex_mem_reg.mem_to_reg;

            ex_mem_reg.valid      <= id_ex_reg.valid;
            ex_mem_reg.pc         <= id_ex_reg.pc;
            ex_mem_reg.opcode     <= id_ex_reg.opcode;
            ex_mem_reg.rd         <= id_ex_reg.rd;
            ex_mem_reg.alu_result <= ex_alu_result;
            ex_mem_reg.store_data <= ex_store_data;
            ex_mem_reg.reg_write  <= id_ex_reg.reg_write;
            ex_mem_reg.mem_read   <= id_ex_reg.mem_read;
            ex_mem_reg.mem_write  <= id_ex_reg.mem_write;
            ex_mem_reg.mem_to_reg <= id_ex_reg.mem_to_reg;

            if (ex_redirect_taken || decode_stall) begin
                bubble_id_ex();
            end else if (if_id_reg.valid && if_id_opcode_valid) begin
                id_ex_reg.valid       <= 1'b1;
                id_ex_reg.pc          <= if_id_reg.pc;
                id_ex_reg.instruction <= if_id_reg.instruction;
                id_ex_reg.opcode      <= if_id_opcode;
                id_ex_reg.rd          <= if_id_rd;
                id_ex_reg.rs1         <= if_id_rs1;
                id_ex_reg.rs2         <= if_id_rs2;
                id_ex_reg.imm_ext     <= if_id_imm_ext;
                id_ex_reg.operand_a   <= decode_operand_a;
                id_ex_reg.operand_b   <= decode_operand_b;
                id_ex_reg.reg_write   <= opcode_writes_rd(if_id_opcode);
                id_ex_reg.mem_read    <= (if_id_opcode == OP_LOAD);
                id_ex_reg.mem_write   <= (if_id_opcode == OP_STORE);
                id_ex_reg.mem_to_reg  <= (if_id_opcode == OP_LOAD);
                id_ex_reg.use_imm     <= (if_id_opcode == OP_ADDI) ||
                                         (if_id_opcode == OP_LOAD) ||
                                         (if_id_opcode == OP_STORE);
                id_ex_reg.branch      <= (if_id_opcode == OP_BEQ);
                id_ex_reg.jump        <= (if_id_opcode == OP_JUMP) && !id_jump_redirect;
            end else begin
                bubble_id_ex();
            end

            // Timing optimisation: redirected and empty frontend entries are
            // bubbles, so only their valid bits need to be cleared. Leaving
            // stale PC/instruction data ignored avoids routing redirect/flush
            // control onto wide data-register reset paths.
            if (ex_redirect_taken) begin
                if_id_reg.valid       <= 1'b0;

                fetch_buffer_valid       <= 1'b0;
                fetch_buffer_is_target   <= 1'b0;
                fetch_pending_valid      <= 1'b0;
                fetch_pending_is_target  <= 1'b0;
                redirect_pending_valid   <= 1'b1;
                redirect_pending_target  <= redirect_target;
                redirect_pending_is_jump <= ex_jump_taken;
                jump_response_pending    <= 1'b0;
                targetbuf_lookup_valid   <= 1'b0;
            end else if (id_jump_redirect) begin
                if_id_reg.valid       <= 1'b0;

                fetch_buffer_valid       <= 1'b0;
                fetch_buffer_is_target   <= 1'b0;
                fetch_pending_valid      <= 1'b0;
                fetch_pending_is_target  <= 1'b0;
                jump_response_pending    <= 1'b1;
                jump_response_pc         <= id_jump_target;
                fetch_pc                 <= id_jump_target + 32'd4;

                targetbuf_lookup_valid       <= 1'b1;
                targetbuf_lookup_hit         <= redirect_target_buffer_hit;
                targetbuf_lookup_pc          <= id_jump_target;
                targetbuf_lookup_instruction <= redirect_target_buffer_hit ?
                                                target_buffer_instruction :
                                                NOP_INSTRUCTION;
            end else if (redirect_pending_valid) begin
                if_id_reg.valid       <= 1'b0;

                fetch_buffer_valid       <= 1'b0;
                fetch_buffer_is_target   <= 1'b0;
                fetch_pending_pc         <= redirect_pending_target;
                fetch_pending_valid      <= 1'b1;
                fetch_pending_is_target  <= redirect_pending_is_jump;
                fetch_pc                 <= redirect_pending_target + 32'd4;
                redirect_pending_valid   <= 1'b0;
                redirect_pending_is_jump <= 1'b0;
                jump_response_pending    <= 1'b0;
                targetbuf_lookup_valid   <= 1'b0;
            end else if (decode_stall) begin
                if (fetch_pending_valid) begin
                    fetch_buffer_valid       <= 1'b1;
                    fetch_buffer_pc          <= fetch_pending_pc;
                    fetch_buffer_instruction <= bram_instruction;
                    fetch_buffer_is_target   <= fetch_pending_is_target;
                end

                fetch_pending_valid     <= 1'b0;
                fetch_pending_is_target <= 1'b0;
                instruction_fetch_wait_cycles <= instruction_fetch_wait_cycles + 32'd1;
            end else begin
                if (accept_fetch_response) begin
                    if_id_reg.valid       <= opcode_is_valid(accepted_fetch_instruction[31:28]);
                    if_id_reg.pc          <= accepted_fetch_pc;
                    if_id_reg.instruction <= accepted_fetch_instruction;
                    if (accepted_fetch_is_target) begin
                        target_buffer_valid       <= 1'b1;
                        target_buffer_pc          <= accepted_fetch_pc;
                        target_buffer_instruction <= accepted_fetch_instruction;
                    end
                end else begin
                    if_id_reg.valid       <= 1'b0;
                end

                if (fetch_buffer_valid) begin
                    fetch_buffer_valid       <= 1'b0;
                    fetch_buffer_is_target   <= 1'b0;
                end

                if (targetbuf_lookup_valid && targetbuf_lookup_hit) begin
                    fetch_pending_pc        <= targetbuf_lookup_pc + 32'd4;
                    fetch_pending_valid     <= 1'b1;
                    fetch_pending_is_target <= 1'b0;
                    fetch_pc                <= targetbuf_lookup_pc + 32'd8;
                    jump_response_pending   <= 1'b0;
                    targetbuf_lookup_valid  <= 1'b0;
                end else begin
                    fetch_pending_pc        <= fetch_pc;
                    fetch_pending_valid     <= 1'b1;
                    fetch_pending_is_target <= 1'b0;
                    fetch_pc                <= fetch_pc + 32'd4;
                    if (jump_response_pending) begin
                        jump_response_pending <= 1'b0;
                    end
                    if (targetbuf_lookup_valid) begin
                        targetbuf_lookup_valid <= 1'b0;
                    end
                end
            end
        end else begin
            retire_valid     <= 1'b0;
            retire_reg_write <= 1'b0;
            retire_mem_write <= 1'b0;
        end
    end

endmodule
