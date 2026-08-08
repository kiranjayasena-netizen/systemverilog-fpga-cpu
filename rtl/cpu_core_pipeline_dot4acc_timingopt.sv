import cpu_defs_pkg::*;

// Experimental Stage D successor copied from cpu_core_pipeline_dot4acc_issue.
// It adds architectural DOT4ACC writeback and exactly-once retirement while
// preserving the Stage C issue, dependency and accumulator-chain behaviour.
module cpu_core_pipeline_dot4acc_timingopt #(
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

    // DOT4ACC issue, completion, writeback and retirement observation.
    output logic        dot_issue_valid,
    output logic        dot_issue_accept,
    output logic [4:0]  dot_issue_rd,
    output logic [31:0] dot_issue_packed_a,
    output logic [31:0] dot_issue_packed_b,
    output logic [31:0] dot_issue_accumulator,
    output logic        dot_issue_chain,
    output logic [31:0] dot_issue_pc,
    output logic [3:0]  dot_issue_opcode,
    output logic [3:0]  dot_inflight_valid,
    output logic [19:0] dot_inflight_rd,
    output logic        dot_complete_valid,
    output logic        dot_complete_eligible,
    output logic [4:0]  dot_complete_rd,
    output logic [31:0] dot_complete_result,
    output logic [31:0] dot_complete_pc,
    output logic [3:0]  dot_complete_opcode,
    output logic        normal_wb_valid,
    output logic        dot_wb_valid,
    output logic        rf_write_enable,
    output logic [4:0]  rf_write_addr,
    output logic [31:0] rf_write_data,
    output logic        dot_retire_valid,
    output logic        dot_active,
    output logic        dot_frontend_hold,
    output logic        dot_dependency_stall,
    output logic        dot_source_dependency_stall,
    output logic        dot_accumulator_dependency_stall,
    output logic        dot_cancel_event
);

    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'h0};

    // This Phase 12 core is the first implementation of OP_MAC8. Keeping the
    // extension-local predicates here prevents historical CPU variants from
    // accepting an instruction that their execute stages do not implement.
    function automatic logic stagec_instruction_is_valid(input logic [31:0] instruction);
        logic [3:0] opcode;
        begin
            opcode = instruction[31:28];
            stagec_instruction_is_valid =
                opcode_is_valid(opcode) ||
                (opcode == OP_MAC8) ||
                ((opcode == OP_DOT4ACC) && (instruction[12:0] == 13'd0));
        end
    endfunction

    function automatic logic stagec_opcode_writes_rd(input logic [3:0] opcode);
        // DOT4ACC uses its private Stage D writeback path, not EX/MEM.
        stagec_opcode_writes_rd = opcode_writes_rd(opcode) || (opcode == OP_MAC8);
    endfunction

    function automatic logic stagec_opcode_uses_rs1(input logic [3:0] opcode);
        stagec_opcode_uses_rs1 = opcode_uses_rs1(opcode) ||
                                 (opcode == OP_MAC8) ||
                                 (opcode == OP_DOT4ACC);
    endfunction

    function automatic logic stagec_opcode_uses_rs2(input logic [3:0] opcode);
        stagec_opcode_uses_rs2 = opcode_uses_rs2(opcode) ||
                                 (opcode == OP_MAC8) ||
                                 (opcode == OP_DOT4ACC);
    endfunction

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
        logic [31:0] accumulator;
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

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [3:0]  opcode;
        logic [31:0] packed_a;
        logic [31:0] packed_b;
        logic [31:0] accumulator;
        logic [4:0]  rd;
        logic        eligible;
        logic        chain_continue;
    } dot_issue_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [3:0]  opcode;
        logic [4:0]  rd;
        logic        eligible;
        logic        chain_continue;
    } dot_meta_reg_t;

    if_id_reg_t  if_id_reg;
    id_ex_reg_t  id_ex_reg;
    ex_mem_reg_t ex_mem_reg;
    mem_wb_reg_t mem_wb_reg;

    dot_issue_reg_t dot_issue_reg;
    dot_meta_reg_t  dot_meta_stage1_reg;
    dot_meta_reg_t  dot_meta_stage2_reg;
    dot_meta_reg_t  dot_complete_meta_reg;

    logic [31:0] regs [0:31];

    logic [31:0] bram_instruction;
    logic [31:0] fetch_pending_pc;
    logic        fetch_pending_valid;
    logic        fetch_buffer_valid;
    logic [31:0] fetch_buffer_pc;
    logic [31:0] fetch_buffer_instruction;
    logic        redirect_pending_valid;
    logic [31:0] redirect_pending_target;

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
    logic        if_id_uses_accumulator;
    logic        load_use_stall;
    logic        decode_stall;
    logic        frontend_stall;

    logic        if_id_is_dot;
    logic        id_ex_is_dot;
    logic        dot_operands_ready;
    logic        dot_issue_stall;
    logic        dot_younger_non_dot_hold;
    logic        dot_chain_continuation;
    logic        dot_chain_open_reg;
    logic [4:0]  dot_chain_rd_reg;

    logic        dot_rs1_precomplete_dependency;
    logic        dot_rs2_precomplete_dependency;
    logic        dot_acc_precomplete_dependency;
    logic        dot_rs1_completion_dependency;
    logic        dot_rs2_completion_dependency;
    logic        dot_acc_completion_dependency;
    logic        dot_complete_writable;

    logic        dot_raw_output_valid;
    logic [31:0] dot_raw_result;
    logic [31:0] dot_selected_packed_a;
    logic [31:0] dot_selected_packed_b;
    logic [31:0] dot_selected_accumulator;
    logic [31:0] dot_pipeline_accumulator;
    logic [31:0] dot_chain_accumulator_reg;

    logic [31:0] wb_write_data;
    logic        wb_writes_rd;
    logic [31:0] decode_operand_a;
    logic [31:0] decode_operand_b;
    logic [31:0] decode_accumulator;

    logic [31:0] ex_operand_a;
    logic [31:0] ex_operand_b_reg;
    logic [31:0] ex_operand_b;
    logic [31:0] ex_store_data;
    logic [31:0] ex_accumulator;
    logic [31:0] ex_alu_result;
    logic signed [7:0]  ex_mac_operand_a;
    logic signed [7:0]  ex_mac_operand_b;
    logic signed [15:0] ex_mac_product;
    logic signed [31:0] ex_mac_product_ext;
    // Guide Vivado to keep the multiply-add in a DSP resource. This remains
    // inferred RTL and does not instantiate a device-specific primitive.
    (* use_dsp = "yes" *) logic signed [31:0] ex_mac_result;
    logic        ex_branch_taken;
    logic        ex_jump_taken;
    logic        ex_redirect_taken;
    logic        id_jump_redirect;
    logic        redirect_taken;
    logic [31:0] ex_redirect_target;
    logic [31:0] id_jump_target;
    logic [31:0] redirect_target;

    logic [31:0] next_instruction_addr;
    logic        accept_fetch_response;
    logic [31:0] accepted_fetch_pc;
    logic [31:0] accepted_fetch_instruction;

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

    // The conservative Stage C hold makes the two requests structurally
    // exclusive: older normal work drains before a DOT can complete and
    // younger normal work cannot reach MEM/WB until the final DOT is consumed.
    assign normal_wb_valid = mem_wb_reg.valid &&
                             mem_wb_reg.reg_write &&
                             (mem_wb_reg.rd != 5'd0);
    assign dot_wb_valid = dot_complete_valid &&
                          dot_complete_meta_reg.eligible &&
                          (dot_complete_meta_reg.rd != 5'd0);
    assign rf_write_enable = enable && (normal_wb_valid || dot_wb_valid);
    assign rf_write_addr = dot_wb_valid ? dot_complete_rd : mem_wb_reg.rd;
    assign rf_write_data = dot_wb_valid ? dot_complete_result : wb_write_data;
    assign reg_write = rf_write_enable;
    assign mem_write = data_mem_write_en;

    assign if_id_opcode = if_id_reg.instruction[31:28];
    assign if_id_rd     = if_id_reg.instruction[27:23];
    assign if_id_rs1    = if_id_reg.instruction[22:18];
    assign if_id_rs2    = if_id_reg.instruction[17:13];
    assign if_id_imm13  = if_id_reg.instruction[12:0];
    assign if_id_imm_ext = {{19{if_id_imm13[12]}}, if_id_imm13};

    assign if_id_opcode_valid     = stagec_instruction_is_valid(if_id_reg.instruction);
    assign if_id_is_dot           = if_id_opcode_valid && (if_id_opcode == OP_DOT4ACC);
    assign if_id_uses_rs1         = stagec_opcode_uses_rs1(if_id_opcode);
    assign if_id_uses_rs2         = stagec_opcode_uses_rs2(if_id_opcode);
    assign if_id_uses_accumulator = (if_id_opcode == OP_MAC8) ||
                                    (if_id_opcode == OP_DOT4ACC);

    assign wb_write_data = mem_wb_reg.mem_to_reg ? data_mem_read_data : mem_wb_reg.alu_result;
    assign wb_writes_rd  = normal_wb_valid;

    assign decode_operand_a =
        (if_id_rs1 == 5'd0) ? 32'h0000_0000 :
        (wb_writes_rd && (mem_wb_reg.rd == if_id_rs1)) ? wb_write_data :
        regs[if_id_rs1];

    assign decode_operand_b =
        (if_id_rs2 == 5'd0) ? 32'h0000_0000 :
        (wb_writes_rd && (mem_wb_reg.rd == if_id_rs2)) ? wb_write_data :
        regs[if_id_rs2];

    // MAC8 and DOT4ACC use rd as both accumulator source and destination.
    assign decode_accumulator =
        (if_id_rd == 5'd0) ? 32'h0000_0000 :
        (wb_writes_rd && (mem_wb_reg.rd == if_id_rd)) ? wb_write_data :
        regs[if_id_rd];

    assign load_use_stall =
        if_id_reg.valid &&
        if_id_opcode_valid &&
        id_ex_reg.valid &&
        id_ex_reg.mem_read &&
        (id_ex_reg.rd != 5'd0) &&
        ((if_id_uses_rs1 && (if_id_rs1 == id_ex_reg.rd)) ||
         (if_id_uses_rs2 && (if_id_rs2 == id_ex_reg.rd)) ||
         (if_id_uses_accumulator && (if_id_rd == id_ex_reg.rd)));

    // A load-use dependency needs one bubble because data BRAM read data is
    // returned after the consuming instruction would otherwise enter EX.
    assign decode_stall = load_use_stall;

    assign id_ex_is_dot = id_ex_reg.valid &&
                          (id_ex_reg.opcode == OP_DOT4ACC) &&
                          (id_ex_reg.instruction[12:0] == 13'd0);

    assign dot_issue_valid       = dot_issue_reg.valid;
    assign dot_issue_rd          = dot_issue_reg.rd;
    assign dot_issue_packed_a    = dot_issue_reg.packed_a;
    assign dot_issue_packed_b    = dot_issue_reg.packed_b;
    assign dot_issue_accumulator = dot_issue_reg.accumulator;
    assign dot_issue_chain       = dot_issue_reg.chain_continue;
    assign dot_issue_pc          = dot_issue_reg.pc;
    assign dot_issue_opcode      = dot_issue_reg.opcode;

    assign dot_inflight_valid = {
        dot_complete_meta_reg.valid,
        dot_meta_stage2_reg.valid,
        dot_meta_stage1_reg.valid,
        dot_issue_reg.valid
    };
    assign dot_inflight_rd = {
        dot_complete_meta_reg.rd,
        dot_meta_stage2_reg.rd,
        dot_meta_stage1_reg.rd,
        dot_issue_reg.rd
    };

    assign dot_complete_valid = dot_raw_output_valid &&
                                dot_complete_meta_reg.valid;
    assign dot_complete_eligible = dot_complete_valid &&
                                   dot_complete_meta_reg.eligible;
    assign dot_complete_rd = dot_complete_meta_reg.rd;
    assign dot_complete_pc = dot_complete_meta_reg.pc;
    assign dot_complete_opcode = dot_complete_meta_reg.opcode;
    assign dot_complete_result = dot_complete_meta_reg.chain_continue ?
                                 (dot_chain_accumulator_reg + dot_raw_result) :
                                 dot_raw_result;
    assign dot_complete_writable = dot_complete_eligible &&
                                   (dot_complete_rd != 5'd0);
    assign dot_retire_valid = retire_valid && (retire_opcode == OP_DOT4ACC);

    assign dot_chain_continuation = id_ex_is_dot &&
                                    (id_ex_reg.rd != 5'd0) &&
                                    dot_chain_open_reg &&
                                    (dot_chain_rd_reg == id_ex_reg.rd);

    // A completion is usable at this issue edge. Earlier arithmetic stages
    // are not, so dependencies against all three pre-completion slots stall.
    assign dot_rs1_precomplete_dependency =
        id_ex_is_dot && (id_ex_reg.rs1 != 5'd0) &&
        ((dot_issue_reg.valid && dot_issue_reg.eligible &&
          (dot_issue_reg.rd == id_ex_reg.rs1)) ||
         (dot_meta_stage1_reg.valid && dot_meta_stage1_reg.eligible &&
          (dot_meta_stage1_reg.rd == id_ex_reg.rs1)) ||
         (dot_meta_stage2_reg.valid && dot_meta_stage2_reg.eligible &&
          (dot_meta_stage2_reg.rd == id_ex_reg.rs1)));

    assign dot_rs2_precomplete_dependency =
        id_ex_is_dot && (id_ex_reg.rs2 != 5'd0) &&
        ((dot_issue_reg.valid && dot_issue_reg.eligible &&
          (dot_issue_reg.rd == id_ex_reg.rs2)) ||
         (dot_meta_stage1_reg.valid && dot_meta_stage1_reg.eligible &&
          (dot_meta_stage1_reg.rd == id_ex_reg.rs2)) ||
         (dot_meta_stage2_reg.valid && dot_meta_stage2_reg.eligible &&
          (dot_meta_stage2_reg.rd == id_ex_reg.rs2)));

    assign dot_acc_precomplete_dependency =
        id_ex_is_dot && (id_ex_reg.rd != 5'd0) &&
        ((dot_issue_reg.valid && dot_issue_reg.eligible &&
          (dot_issue_reg.rd == id_ex_reg.rd)) ||
         (dot_meta_stage1_reg.valid && dot_meta_stage1_reg.eligible &&
          (dot_meta_stage1_reg.rd == id_ex_reg.rd)) ||
         (dot_meta_stage2_reg.valid && dot_meta_stage2_reg.eligible &&
          (dot_meta_stage2_reg.rd == id_ex_reg.rd)));

    assign dot_rs1_completion_dependency = dot_complete_writable &&
                                            (dot_complete_rd == id_ex_reg.rs1);
    assign dot_rs2_completion_dependency = dot_complete_writable &&
                                            (dot_complete_rd == id_ex_reg.rs2);
    assign dot_acc_completion_dependency = dot_complete_writable &&
                                            (dot_complete_rd == id_ex_reg.rd);

    assign dot_source_dependency_stall = id_ex_is_dot &&
                                         (dot_rs1_precomplete_dependency ||
                                          dot_rs2_precomplete_dependency);
    assign dot_accumulator_dependency_stall = id_ex_is_dot &&
                                              dot_acc_precomplete_dependency &&
                                              !dot_chain_continuation;
    assign dot_dependency_stall = dot_source_dependency_stall ||
                                  dot_accumulator_dependency_stall;
    assign dot_operands_ready = !dot_dependency_stall;

    // The issue register drains into the enabled arithmetic pipe every clock,
    // so it is always available on an advancing edge. An older EX redirect
    // takes priority, and a pending redirect prevents wrong-path issue.
    assign dot_issue_accept = enable && !rst && id_ex_is_dot &&
                              dot_operands_ready &&
                              !ex_redirect_taken &&
                              !redirect_pending_valid;
    assign dot_issue_stall = id_ex_is_dot && !dot_operands_ready;

    assign dot_active = id_ex_is_dot || (|dot_inflight_valid);
    assign dot_younger_non_dot_hold = if_id_reg.valid &&
                                      if_id_opcode_valid &&
                                      !if_id_is_dot &&
                                      dot_active;
    assign dot_frontend_hold = dot_issue_stall || dot_younger_non_dot_hold;
    assign frontend_stall = decode_stall || dot_frontend_hold;

    always_comb begin
        ex_operand_a     = id_ex_reg.operand_a;
        ex_operand_b_reg = id_ex_reg.operand_b;
        ex_accumulator   = id_ex_reg.accumulator;

        if (ex_mem_reg.valid &&
            ex_mem_reg.reg_write &&
            !ex_mem_reg.mem_to_reg &&
            (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs1)) begin
            ex_operand_a = ex_mem_reg.alu_result;
        end else if (wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rs1)) begin
            ex_operand_a = wb_write_data;
        end

        if (dot_rs1_completion_dependency) begin
            ex_operand_a = dot_complete_result;
        end

        if (ex_mem_reg.valid &&
            ex_mem_reg.reg_write &&
            !ex_mem_reg.mem_to_reg &&
            (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs2)) begin
            ex_operand_b_reg = ex_mem_reg.alu_result;
        end else if (wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rs2)) begin
            ex_operand_b_reg = wb_write_data;
        end

        if (dot_rs2_completion_dependency) begin
            ex_operand_b_reg = dot_complete_result;
        end

        if ((id_ex_reg.opcode == OP_MAC8) ||
            (id_ex_reg.opcode == OP_DOT4ACC)) begin
            if (ex_mem_reg.valid &&
                ex_mem_reg.reg_write &&
                !ex_mem_reg.mem_to_reg &&
                (ex_mem_reg.rd != 5'd0) &&
                (ex_mem_reg.rd == id_ex_reg.rd)) begin
                ex_accumulator = ex_mem_reg.alu_result;
            end else if (wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rd)) begin
                ex_accumulator = wb_write_data;
            end
            if (dot_acc_completion_dependency) begin
                ex_accumulator = dot_complete_result;
            end
        end

        ex_operand_b  = id_ex_reg.use_imm ? id_ex_reg.imm_ext : ex_operand_b_reg;
        ex_store_data = ex_operand_b_reg;
    end

    assign dot_selected_packed_a    = ex_operand_a;
    assign dot_selected_packed_b    = ex_operand_b_reg;
    assign dot_selected_accumulator = ex_accumulator;
    assign dot_pipeline_accumulator = dot_chain_continuation ?
                                      32'h0000_0000 :
                                      dot_selected_accumulator;


    // MAC8 consumes the low byte of each source as a signed two's-complement
    // INT8 value. The full 16-bit product is sign-extended before it is added
    // to the 32-bit accumulator; only the final 32-bit sum can wrap.
    always_comb begin
        ex_mac_operand_a  = $signed(ex_operand_a[7:0]);
        ex_mac_operand_b  = $signed(ex_operand_b_reg[7:0]);
        ex_mac_product    = ex_mac_operand_a * ex_mac_operand_b;
        ex_mac_product_ext = {{16{ex_mac_product[15]}}, ex_mac_product};
        ex_mac_result     = $signed(ex_accumulator) + ex_mac_product_ext;
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
            OP_MAC8:  ex_alu_result = ex_mac_result;
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
    assign id_jump_redirect = if_id_reg.valid &&
                              if_id_opcode_valid &&
                              (if_id_opcode == OP_JUMP) &&
                              !frontend_stall &&
                              !dot_active &&
                              !redirect_pending_valid &&
                              !ex_redirect_taken;
    assign redirect_taken  = ex_redirect_taken || id_jump_redirect;
    assign redirect_target = ex_redirect_taken ? ex_redirect_target : id_jump_target;
    assign pc_redirect     = enable && redirect_taken;
    assign dot_cancel_event = enable && redirect_taken &&
                              ((if_id_reg.valid && if_id_is_dot) ||
                               (fetch_buffer_valid &&
                                stagec_instruction_is_valid(fetch_buffer_instruction) &&
                                (fetch_buffer_instruction[31:28] == OP_DOT4ACC)) ||
                               (fetch_pending_valid &&
                                stagec_instruction_is_valid(bram_instruction) &&
                                (bram_instruction[31:28] == OP_DOT4ACC)));

    assign data_mem_read_en    = enable && ex_mem_reg.valid && ex_mem_reg.mem_read;
    assign data_mem_write_en   = enable && ex_mem_reg.valid && ex_mem_reg.mem_write;
    assign data_mem_write_data = ex_mem_reg.store_data;

    always_comb begin
        if (redirect_pending_valid) begin
            next_instruction_addr = redirect_pending_target;
        end else if (frontend_stall || !enable) begin
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

        if (fetch_buffer_valid) begin
            accept_fetch_response      = 1'b1;
            accepted_fetch_pc          = fetch_buffer_pc;
            accepted_fetch_instruction = fetch_buffer_instruction;
        end else if (fetch_pending_valid) begin
            accept_fetch_response      = 1'b1;
            accepted_fetch_pc          = fetch_pending_pc;
            accepted_fetch_instruction = bram_instruction;
        end
    end


    // Registered issue isolation adds one advancing clock ahead of the
    // unchanged Stage A2 arithmetic pipeline. A Stage C issue accepted at I
    // therefore produces its aligned observation at I+3.
    dot4acc_pipeline dot4acc_pipeline_inst (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .input_valid(dot_issue_reg.valid),
        .accumulator(dot_issue_reg.accumulator),
        .packed_a(dot_issue_reg.packed_a),
        .packed_b(dot_issue_reg.packed_b),
        .output_valid(dot_raw_output_valid),
        .result(dot_raw_result)
    );

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
            id_ex_reg.accumulator <= 32'h0000_0000;
            id_ex_reg.reg_write   <= 1'b0;
            id_ex_reg.mem_read    <= 1'b0;
            id_ex_reg.mem_write   <= 1'b0;
            id_ex_reg.mem_to_reg  <= 1'b0;
            id_ex_reg.use_imm     <= 1'b0;
            id_ex_reg.branch      <= 1'b0;
            id_ex_reg.jump        <= 1'b0;
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
            fetch_buffer_valid       <= 1'b0;
            fetch_buffer_pc          <= 32'h0000_0000;
            fetch_buffer_instruction <= NOP_INSTRUCTION;
            redirect_pending_valid   <= 1'b0;
            redirect_pending_target  <= 32'h0000_0000;

            if_id_reg.valid       <= 1'b0;
            if_id_reg.pc          <= 32'h0000_0000;
            if_id_reg.instruction <= NOP_INSTRUCTION;

            clear_id_ex();
            clear_ex_mem();
            clear_mem_wb();

            dot_issue_reg                 <= '0;
            dot_meta_stage1_reg           <= '0;
            dot_meta_stage2_reg           <= '0;
            dot_complete_meta_reg         <= '0;
            dot_chain_open_reg            <= 1'b0;
            dot_chain_rd_reg              <= 5'd0;
            dot_chain_accumulator_reg     <= 32'h0000_0000;

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

            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if (enable) begin
            total_cycles <= total_cycles + 32'd1;
            if (retired_instructions == 32'd0) begin
                pipeline_fill_cycles <= pipeline_fill_cycles + 32'd1;
            end

            // Arithmetic completion is consumed exactly once on this enabled
            // edge. It shares the existing retirement pulse and RF write port.
            // A structural assertion below proves normal and DOT retirement
            // requests never overlap under the conservative Stage C hold.
            retire_valid <= mem_wb_reg.valid || dot_complete_valid;
            if (dot_complete_valid) begin
                retire_pc         <= dot_complete_meta_reg.pc;
                retire_opcode     <= dot_complete_meta_reg.opcode;
                retire_rd         <= dot_complete_meta_reg.rd;
                retire_reg_write  <= dot_wb_valid;
                retire_write_data <= dot_complete_result;
                retire_mem_write  <= 1'b0;
                retire_mem_addr   <= 32'h0000_0000;
                retire_mem_data   <= 32'h0000_0000;
            end else begin
                retire_pc         <= mem_wb_reg.pc;
                retire_opcode     <= mem_wb_reg.opcode;
                retire_rd         <= mem_wb_reg.rd;
                retire_reg_write  <= normal_wb_valid;
                retire_write_data <= wb_write_data;
                retire_mem_write  <= mem_wb_reg.valid && mem_wb_reg.mem_write;
                retire_mem_addr   <= mem_wb_reg.alu_result;
                retire_mem_data   <= mem_wb_reg.store_data;
            end

            if (mem_wb_reg.valid || dot_complete_valid) begin
                retired_instructions <= retired_instructions + 32'd1;
            end

            if (rf_write_enable) begin
                regs[rf_write_addr] <= rf_write_data;
            end
            regs[0] <= 32'h0000_0000;

            // The issue register is an operand-isolation boundary. It emits
            // one bubble when no instruction is accepted and never rewrites
            // its payload except on genuine acceptance.
            dot_issue_reg.valid <= dot_issue_accept;
            if (dot_issue_accept) begin
                dot_issue_reg.pc            <= id_ex_reg.pc;
                dot_issue_reg.opcode        <= id_ex_reg.opcode;
                dot_issue_reg.packed_a      <= dot_selected_packed_a;
                dot_issue_reg.packed_b      <= dot_selected_packed_b;
                dot_issue_reg.accumulator   <= dot_pipeline_accumulator;
                dot_issue_reg.rd            <= id_ex_reg.rd;
                dot_issue_reg.eligible      <= (id_ex_reg.rd != 5'd0);
                dot_issue_reg.chain_continue <= dot_chain_continuation;
            end

            dot_meta_stage1_reg.valid <= dot_issue_reg.valid;
            if (dot_issue_reg.valid) begin
                dot_meta_stage1_reg.pc             <= dot_issue_reg.pc;
                dot_meta_stage1_reg.opcode         <= dot_issue_reg.opcode;
                dot_meta_stage1_reg.rd             <= dot_issue_reg.rd;
                dot_meta_stage1_reg.eligible       <= dot_issue_reg.eligible;
                dot_meta_stage1_reg.chain_continue <= dot_issue_reg.chain_continue;
            end

            dot_meta_stage2_reg.valid <= dot_meta_stage1_reg.valid;
            if (dot_meta_stage1_reg.valid) begin
                dot_meta_stage2_reg.pc             <= dot_meta_stage1_reg.pc;
                dot_meta_stage2_reg.opcode         <= dot_meta_stage1_reg.opcode;
                dot_meta_stage2_reg.rd             <= dot_meta_stage1_reg.rd;
                dot_meta_stage2_reg.eligible       <= dot_meta_stage1_reg.eligible;
                dot_meta_stage2_reg.chain_continue <= dot_meta_stage1_reg.chain_continue;
            end

            dot_complete_meta_reg.valid <= dot_meta_stage2_reg.valid;
            if (dot_meta_stage2_reg.valid) begin
                dot_complete_meta_reg.pc             <= dot_meta_stage2_reg.pc;
                dot_complete_meta_reg.opcode         <= dot_meta_stage2_reg.opcode;
                dot_complete_meta_reg.rd             <= dot_meta_stage2_reg.rd;
                dot_complete_meta_reg.eligible       <= dot_meta_stage2_reg.eligible;
                dot_complete_meta_reg.chain_continue <= dot_meta_stage2_reg.chain_continue;
            end

            // Ordered completion-side recurrence for contiguous same-rd
            // chains. Head outputs already contain A0+dot0. Continuations
            // carry raw doti and are folded here as Ai=Ai-1+doti.
            if (dot_complete_valid) begin
                dot_chain_accumulator_reg <= dot_complete_result;
            end

            // G1: chain contiguity is terminated by the decoded non-DOT
            // instruction boundary. Redirect handling still flushes issue and
            // fetch state, but no longer feeds this late chain-state reset
            // cone. A branch/jump is non-DOT and therefore closes the chain
            // before its EX redirect resolves.
            if (dot_issue_accept) begin
                dot_chain_open_reg <= (id_ex_reg.rd != 5'd0);
                dot_chain_rd_reg   <= id_ex_reg.rd;
            end
            // A real non-DOT instruction ends contiguity. If a DOT is stalled
            // in ID/EX, defer the break until that DOT accepts so its
            // already-established chain classification is preserved.
            if (if_id_reg.valid && if_id_opcode_valid && !if_id_is_dot &&
                (!id_ex_is_dot || dot_issue_accept)) begin
                dot_chain_open_reg <= 1'b0;
                dot_chain_rd_reg   <= 5'd0;
            end

            if (decode_stall) begin
                data_hazard_stall_cycles <= data_hazard_stall_cycles + 32'd1;
                memory_wait_cycles       <= memory_wait_cycles + 32'd1;
            end
            if (load_use_stall) begin
                load_use_stall_cycles <= load_use_stall_cycles + 32'd1;
            end

            if (redirect_taken) begin
                control_hazard_flush_cycles <= control_hazard_flush_cycles + 32'd1;
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

            // DOT4ACC still terminates before EX/MEM; Stage D writeback and
            // retirement are driven only by the aligned private completion.
            ex_mem_reg.valid      <= id_ex_reg.valid && !id_ex_is_dot;
            ex_mem_reg.pc         <= id_ex_reg.pc;
            ex_mem_reg.opcode     <= id_ex_reg.opcode;
            ex_mem_reg.rd         <= id_ex_reg.rd;
            ex_mem_reg.alu_result <= ex_alu_result;
            ex_mem_reg.store_data <= ex_store_data;
            ex_mem_reg.reg_write  <= id_ex_reg.reg_write;
            ex_mem_reg.mem_read   <= id_ex_reg.mem_read;
            ex_mem_reg.mem_write  <= id_ex_reg.mem_write;
            ex_mem_reg.mem_to_reg <= id_ex_reg.mem_to_reg;

            if (ex_redirect_taken) begin
                clear_id_ex();
            end else if (dot_issue_stall) begin
                // Preserve the waiting DOT exactly once until every operand
                // dependency is ready.
                id_ex_reg <= id_ex_reg;
            end else if (decode_stall || dot_younger_non_dot_hold) begin
                clear_id_ex();
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
                id_ex_reg.accumulator <= decode_accumulator;
                id_ex_reg.reg_write   <= stagec_opcode_writes_rd(if_id_opcode);
                id_ex_reg.mem_read    <= (if_id_opcode == OP_LOAD);
                id_ex_reg.mem_write   <= (if_id_opcode == OP_STORE);
                id_ex_reg.mem_to_reg  <= (if_id_opcode == OP_LOAD);
                id_ex_reg.use_imm     <= (if_id_opcode == OP_ADDI) ||
                                         (if_id_opcode == OP_LOAD) ||
                                         (if_id_opcode == OP_STORE);
                id_ex_reg.branch      <= (if_id_opcode == OP_BEQ);
                id_ex_reg.jump        <= (if_id_opcode == OP_JUMP) && !id_jump_redirect;
            end else begin
                clear_id_ex();
            end

            if (redirect_taken) begin
                if_id_reg.valid <= 1'b0;

                fetch_buffer_valid     <= 1'b0;
                fetch_pending_valid      <= 1'b0;
                redirect_pending_valid   <= 1'b1;
                redirect_pending_target  <= redirect_target;
            end else if (redirect_pending_valid) begin
                if_id_reg.valid <= 1'b0;

                fetch_buffer_valid      <= 1'b0;
                fetch_pending_pc         <= redirect_pending_target;
                fetch_pending_valid      <= 1'b1;
                fetch_pc                 <= redirect_pending_target + 32'd4;
                redirect_pending_valid   <= 1'b0;
                redirect_pending_target  <= 32'h0000_0000;
            end else if (frontend_stall) begin
                if (fetch_pending_valid) begin
                    fetch_buffer_valid       <= 1'b1;
                    fetch_buffer_pc          <= fetch_pending_pc;
                    fetch_buffer_instruction <= bram_instruction;
                end

                fetch_pending_valid <= 1'b0;
                instruction_fetch_wait_cycles <= instruction_fetch_wait_cycles + 32'd1;
            end else begin
                if (accept_fetch_response) begin
                    if_id_reg.valid       <= stagec_instruction_is_valid(accepted_fetch_instruction);
                    if_id_reg.pc          <= accepted_fetch_pc;
                    if_id_reg.instruction <= accepted_fetch_instruction;
                end else begin
                    if_id_reg.valid <= 1'b0;
                end

                if (fetch_buffer_valid) begin
                    fetch_buffer_valid <= 1'b0;
                end

                fetch_pending_pc    <= fetch_pc;
                fetch_pending_valid <= 1'b1;
                fetch_pc            <= fetch_pc + 32'd4;
            end
        end else begin
            retire_valid     <= 1'b0;
            retire_reg_write <= 1'b0;
            retire_mem_write <= 1'b0;
        end
    end

`ifndef SYNTHESIS
    logic        dot_assert_shadow_valid = 1'b0;
    logic [3:0]  dot_assert_inflight_valid;
    logic [19:0] dot_assert_inflight_rd;
    logic        dot_assert_complete_valid;
    logic [31:0] dot_assert_complete_result;
    logic        dot_assert_previous_accept = 1'b0;
    logic [31:0] dot_assert_previous_accept_pc;
    logic        dot_assert_previous_completion_valid = 1'b0;
    logic [4:0]  dot_assert_previous_completion_rd;
    logic        dot_assert_consumed_valid;
    logic [31:0] dot_assert_consumed_pc;
    logic [3:0]  dot_assert_consumed_opcode;
    logic [4:0]  dot_assert_consumed_rd;
    logic [31:0] dot_assert_consumed_result;
    logic        dot_assert_normal_wb_request;
    logic        dot_assert_dot_wb_request;
    logic        dot_assert_normal_retire_request;

    // G1 hypothesis: a valid DOT cannot also be an EX branch or jump.
    property g1_dot_never_redirects;
        @(posedge clk) disable iff (rst)
            id_ex_is_dot |-> !ex_redirect_taken;
    endproperty
    assert property (g1_dot_never_redirects)
        else $fatal(1, "G1 invariant violated: DOT also redirects");

    // These checks are deliberately outside synthesizable behaviour. The
    // focused testbench supplies the transaction scoreboard and arithmetic
    // oracle; these local assertions defend the issue-control invariants.
    always @(posedge clk) begin
        dot_assert_consumed_valid = !rst && enable && dot_complete_valid;
        dot_assert_consumed_pc = dot_complete_pc;
        dot_assert_consumed_opcode = dot_complete_opcode;
        dot_assert_consumed_rd = dot_complete_rd;
        dot_assert_consumed_result = dot_complete_result;
        dot_assert_normal_wb_request = !rst && enable && normal_wb_valid;
        dot_assert_dot_wb_request = !rst && enable && dot_wb_valid;
        dot_assert_normal_retire_request = !rst && enable && mem_wb_reg.valid;
        #1;
        if (!rst) begin
            assert (!(dot_assert_normal_wb_request && dot_assert_dot_wb_request))
                else $fatal(1, "normal and DOT writeback collided at consumption edge");
            assert (!(dot_assert_normal_retire_request && dot_assert_consumed_valid))
                else $fatal(1, "normal and DOT retirement collided at consumption edge");
            assert (!(normal_wb_valid && dot_wb_valid))
                else $fatal(1, "normal and DOT writeback requests collided");
            assert (!(mem_wb_reg.valid && dot_complete_valid))
                else $fatal(1, "normal and DOT retirement requests collided");
            assert (!rf_write_enable ||
                    ((normal_wb_valid || dot_wb_valid) && (rf_write_addr != 5'd0)))
                else $fatal(1, "register-file write lacks a valid non-x0 source");
            assert (!dot_wb_valid ||
                    (dot_complete_valid && dot_complete_eligible &&
                     (dot_complete_rd != 5'd0)))
                else $fatal(1, "invalid DOT writeback request");
            assert (!dot_retire_valid ||
                    (retire_opcode == OP_DOT4ACC))
                else $fatal(1, "DOT retirement opcode mismatch");
            if (dot_assert_consumed_valid) begin
                assert (dot_retire_valid &&
                        (retire_pc == dot_assert_consumed_pc) &&
                        (retire_opcode == dot_assert_consumed_opcode) &&
                        (retire_rd == dot_assert_consumed_rd) &&
                        (retire_write_data == dot_assert_consumed_result))
                    else $fatal(1, "DOT retirement metadata misaligned");
            end
            assert (!dot_issue_accept ||
                    (enable && id_ex_is_dot && dot_operands_ready &&
                     !ex_redirect_taken && !redirect_pending_valid))
                else $fatal(1, "DOT issue accepted without readiness");
            assert (!dot_issue_reg.eligible || (dot_issue_reg.rd != 5'd0))
                else $fatal(1, "x0 tracked as a writable DOT destination");
            assert (!dot_issue_reg.chain_continue ||
                    (dot_issue_reg.eligible && (dot_issue_reg.rd != 5'd0)))
                else $fatal(1, "illegal DOT accumulator-chain bypass");
            assert (!dot_complete_valid || dot_complete_meta_reg.valid)
                else $fatal(1, "DOT result lacks aligned completion metadata");
            assert (!dot_complete_meta_reg.chain_continue ||
                    !dot_complete_valid ||
                    (dot_assert_previous_completion_valid &&
                     (dot_assert_previous_completion_rd == dot_complete_rd)))
                else $fatal(1, "DOT chain recurrence destination mismatch");
            assert (!(dot_assert_previous_accept && dot_issue_accept &&
                      (dot_assert_previous_accept_pc == id_ex_reg.pc)))
                else $fatal(1, "same DOT instruction accepted twice");

            if (!enable && dot_assert_shadow_valid) begin
                assert ((dot_inflight_valid == dot_assert_inflight_valid) &&
                        (dot_inflight_rd == dot_assert_inflight_rd) &&
                        (dot_complete_valid == dot_assert_complete_valid) &&
                        (dot_complete_result == dot_assert_complete_result))
                    else $fatal(1, "DOT pipeline metadata changed while disabled");
            end
        end else begin
            assert ((dot_inflight_valid == 4'b0000) && !dot_complete_valid)
                else $fatal(1, "reset did not clear DOT valid state");
        end

        dot_assert_previous_accept = !rst && dot_issue_accept;
        dot_assert_previous_accept_pc = id_ex_reg.pc;
        if (rst) begin
            dot_assert_previous_completion_valid = 1'b0;
            dot_assert_previous_completion_rd = 5'd0;
        end else if (enable && dot_complete_valid) begin
            dot_assert_previous_completion_valid = 1'b1;
            dot_assert_previous_completion_rd = dot_complete_rd;
        end
        dot_assert_inflight_valid = dot_inflight_valid;
        dot_assert_inflight_rd = dot_inflight_rd;
        dot_assert_complete_valid = dot_complete_valid;
        dot_assert_complete_result = dot_complete_result;
        dot_assert_shadow_valid = !rst;
    end
`endif

endmodule
