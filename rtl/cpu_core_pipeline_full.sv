import cpu_defs_pkg::*;

module cpu_core_pipeline_full #(
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
    output logic [31:0] wrong_path_instructions_flushed
);

    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'h0};

    // This Phase 12 core is the first implementation of OP_MAC8. Keeping the
    // extension-local predicates here prevents historical CPU variants from
    // accepting an instruction that their execute stages do not implement.
    function automatic logic phase12_opcode_is_valid(input logic [3:0] opcode);
        phase12_opcode_is_valid = opcode_is_valid(opcode) || (opcode == OP_MAC8);
    endfunction

    function automatic logic phase12_opcode_writes_rd(input logic [3:0] opcode);
        phase12_opcode_writes_rd = opcode_writes_rd(opcode) || (opcode == OP_MAC8);
    endfunction

    function automatic logic phase12_opcode_uses_rs1(input logic [3:0] opcode);
        phase12_opcode_uses_rs1 = opcode_uses_rs1(opcode) || (opcode == OP_MAC8);
    endfunction

    function automatic logic phase12_opcode_uses_rs2(input logic [3:0] opcode);
        phase12_opcode_uses_rs2 = opcode_uses_rs2(opcode) || (opcode == OP_MAC8);
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

    assign if_id_opcode_valid     = phase12_opcode_is_valid(if_id_opcode);
    assign if_id_uses_rs1         = phase12_opcode_uses_rs1(if_id_opcode);
    assign if_id_uses_rs2         = phase12_opcode_uses_rs2(if_id_opcode);
    assign if_id_uses_accumulator = (if_id_opcode == OP_MAC8);

    assign wb_write_data = mem_wb_reg.mem_to_reg ? data_mem_read_data : mem_wb_reg.alu_result;
    assign wb_writes_rd  = mem_wb_reg.valid &&
                           mem_wb_reg.reg_write &&
                           (mem_wb_reg.rd != 5'd0);

    assign decode_operand_a =
        (if_id_rs1 == 5'd0) ? 32'h0000_0000 :
        (wb_writes_rd && (mem_wb_reg.rd == if_id_rs1)) ? wb_write_data :
        regs[if_id_rs1];

    assign decode_operand_b =
        (if_id_rs2 == 5'd0) ? 32'h0000_0000 :
        (wb_writes_rd && (mem_wb_reg.rd == if_id_rs2)) ? wb_write_data :
        regs[if_id_rs2];

    // MAC8 uses rd as both its 32-bit accumulator source and destination.
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

        if (ex_mem_reg.valid &&
            ex_mem_reg.reg_write &&
            !ex_mem_reg.mem_to_reg &&
            (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs2)) begin
            ex_operand_b_reg = ex_mem_reg.alu_result;
        end else if (wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rs2)) begin
            ex_operand_b_reg = wb_write_data;
        end

        if (id_ex_reg.opcode == OP_MAC8) begin
            if (ex_mem_reg.valid &&
                ex_mem_reg.reg_write &&
                !ex_mem_reg.mem_to_reg &&
                (ex_mem_reg.rd != 5'd0) &&
                (ex_mem_reg.rd == id_ex_reg.rd)) begin
                ex_accumulator = ex_mem_reg.alu_result;
            end else if (wb_writes_rd && (mem_wb_reg.rd == id_ex_reg.rd)) begin
                ex_accumulator = wb_write_data;
            end
        end

        ex_operand_b  = id_ex_reg.use_imm ? id_ex_reg.imm_ext : ex_operand_b_reg;
        ex_store_data = ex_operand_b_reg;
    end


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
                              !decode_stall &&
                              !redirect_pending_valid &&
                              !ex_redirect_taken;
    assign redirect_taken  = ex_redirect_taken || id_jump_redirect;
    assign redirect_target = ex_redirect_taken ? ex_redirect_target : id_jump_target;
    assign pc_redirect     = enable && redirect_taken;

    assign data_mem_read_en    = enable && ex_mem_reg.valid && ex_mem_reg.mem_read;
    assign data_mem_write_en   = enable && ex_mem_reg.valid && ex_mem_reg.mem_write;
    assign data_mem_write_data = ex_mem_reg.store_data;

    always_comb begin
        if (redirect_pending_valid) begin
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
                id_ex_reg.reg_write   <= phase12_opcode_writes_rd(if_id_opcode);
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
                if_id_reg.valid       <= 1'b0;
                if_id_reg.pc          <= 32'h0000_0000;
                if_id_reg.instruction <= NOP_INSTRUCTION;

                fetch_buffer_valid       <= 1'b0;
                fetch_buffer_pc          <= 32'h0000_0000;
                fetch_buffer_instruction <= NOP_INSTRUCTION;
                fetch_pending_valid      <= 1'b0;
                redirect_pending_valid   <= 1'b1;
                redirect_pending_target  <= redirect_target;
            end else if (redirect_pending_valid) begin
                if_id_reg.valid       <= 1'b0;
                if_id_reg.pc          <= 32'h0000_0000;
                if_id_reg.instruction <= NOP_INSTRUCTION;

                fetch_buffer_valid       <= 1'b0;
                fetch_buffer_pc          <= 32'h0000_0000;
                fetch_buffer_instruction <= NOP_INSTRUCTION;
                fetch_pending_pc         <= redirect_pending_target;
                fetch_pending_valid      <= 1'b1;
                fetch_pc                 <= redirect_pending_target + 32'd4;
                redirect_pending_valid   <= 1'b0;
                redirect_pending_target  <= 32'h0000_0000;
            end else if (decode_stall) begin
                if (fetch_pending_valid) begin
                    fetch_buffer_valid       <= 1'b1;
                    fetch_buffer_pc          <= fetch_pending_pc;
                    fetch_buffer_instruction <= bram_instruction;
                end

                fetch_pending_valid <= 1'b0;
                instruction_fetch_wait_cycles <= instruction_fetch_wait_cycles + 32'd1;
            end else begin
                if (accept_fetch_response) begin
                    if_id_reg.valid       <= phase12_opcode_is_valid(accepted_fetch_instruction[31:28]);
                    if_id_reg.pc          <= accepted_fetch_pc;
                    if_id_reg.instruction <= accepted_fetch_instruction;
                end else begin
                    if_id_reg.valid       <= 1'b0;
                    if_id_reg.pc          <= 32'h0000_0000;
                    if_id_reg.instruction <= NOP_INSTRUCTION;
                end

                if (fetch_buffer_valid) begin
                    fetch_buffer_valid       <= 1'b0;
                    fetch_buffer_pc          <= 32'h0000_0000;
                    fetch_buffer_instruction <= NOP_INSTRUCTION;
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

endmodule
