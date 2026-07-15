module fpga_top_cpu_mips_compare #(
    // CPU_SELECT:
    // 0 = Phase 8G multi-cycle
    // 1 = Phase 10H BRAM multi-cycle
    // 2 = Phase 11E BRAM prefetch ctrlopt multi-cycle
    // 3 = Phase 12 five-stage pipeline
    // 4 = Phase 13E/13I forwarding-timing pipeline
    // 5 = Phase 14G six-stage pipeline
    parameter int unsigned CPU_SELECT = 5,
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256,
    parameter int unsigned CLOCK_HZ = 100_000_000,
    parameter int unsigned MIPS_DIVISOR = 1_000_000
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [1:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);

    import cpu_defs_pkg::*;

    localparam int unsigned MILLION_REMAINDER_WIDTH = $clog2(MIPS_DIVISOR);
    localparam logic [15:0] CPU_SELECT_DISPLAY = CPU_SELECT;

    logic rst_meta;
    logic rst_sync;
    logic [1:0] sw_meta;
    logic [1:0] sw_sync;
    logic cpu_enable;

    logic [31:0] selected_pc;
    logic [4:0]  selected_stage_valids;
    logic        selected_complete_valid;
    logic        selected_reg_write;
    logic        selected_mem_write;
    logic        selected_redirect;

    logic [31:0] cycle_counter;
    logic [31:0] retired_counter;
    logic [31:0] last_retired_count;
    logic [MILLION_REMAINDER_WIDTH-1:0] retired_million_remainder;
    logic [15:0] mips_accumulator;
    logic [15:0] mips_value;
    logic        measurement_window_seen;

    logic [MILLION_REMAINDER_WIDTH-1:0] retired_million_remainder_next;
    logic [15:0] mips_accumulator_next;
    logic        retire_million_wrap;
    logic [31:0] retired_counter_next;

    logic redirect_seen;
    logic retire_seen;
    logic reg_write_seen;
    logic mem_write_seen;

    logic [16:0] refresh_counter;
    logic [1:0]  digit_select;
    logic [15:0] display_value;
    logic [13:0] display_clamped;
    logic [15:0] bcd_digits;
    logic [3:0]  active_digit;

    function automatic logic [15:0] bin14_to_bcd4(input logic [13:0] bin_value);
        logic [29:0] shift_reg;
        int i;
        begin
            shift_reg = 30'd0;
            shift_reg[13:0] = bin_value;
            for (i = 0; i < 14; i++) begin
                if (shift_reg[17:14] >= 4'd5) begin
                    shift_reg[17:14] = shift_reg[17:14] + 4'd3;
                end
                if (shift_reg[21:18] >= 4'd5) begin
                    shift_reg[21:18] = shift_reg[21:18] + 4'd3;
                end
                if (shift_reg[25:22] >= 4'd5) begin
                    shift_reg[25:22] = shift_reg[25:22] + 4'd3;
                end
                if (shift_reg[29:26] >= 4'd5) begin
                    shift_reg[29:26] = shift_reg[29:26] + 4'd3;
                end
                shift_reg = shift_reg << 1;
            end
            bin14_to_bcd4 = shift_reg[29:14];
        end
    endfunction

    function automatic logic [6:0] seven_segment_active_low(input logic [3:0] digit);
        begin
            unique case (digit)
                4'd0: seven_segment_active_low = 7'b1000000;
                4'd1: seven_segment_active_low = 7'b1111001;
                4'd2: seven_segment_active_low = 7'b0100100;
                4'd3: seven_segment_active_low = 7'b0110000;
                4'd4: seven_segment_active_low = 7'b0011001;
                4'd5: seven_segment_active_low = 7'b0010010;
                4'd6: seven_segment_active_low = 7'b0000010;
                4'd7: seven_segment_active_low = 7'b1111000;
                4'd8: seven_segment_active_low = 7'b0000000;
                4'd9: seven_segment_active_low = 7'b0010000;
                default: seven_segment_active_low = 7'b1111111;
            endcase
        end
    endfunction

    function automatic logic multicycle_done(
        input logic [2:0] state,
        input logic [3:0] opcode,
        input logic       valid_instr
    );
        begin
            multicycle_done =
                valid_instr &&
                (((state == 3'd1) && (opcode == OP_NOP)) ||
                 ((state == 3'd2) && ((opcode == OP_BEQ) || (opcode == OP_JUMP))) ||
                 ((state == 3'd3) && (opcode == OP_STORE)) ||
                 ((state == 3'd4) && (opcode_is_arithmetic(opcode) || (opcode == OP_LOAD))));
        end
    endfunction

    function automatic logic bram_multicycle_done(
        input logic [2:0] state,
        input logic [3:0] opcode,
        input logic       valid_instr
    );
        begin
            bram_multicycle_done =
                valid_instr &&
                (((state == 3'd2) && (opcode == OP_NOP)) ||
                 ((state == 3'd3) && ((opcode == OP_BEQ) || (opcode == OP_JUMP))) ||
                 ((state == 3'd4) && (opcode == OP_STORE)) ||
                 ((state == 3'd6) && (opcode_is_arithmetic(opcode) || (opcode == OP_LOAD))));
        end
    endfunction

    always_ff @(posedge clk) begin
        rst_meta <= rst_btn;
        rst_sync <= rst_meta;
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
    end

    assign cpu_enable = sw_sync[0];

    assign retire_million_wrap = selected_complete_valid &&
                                 (retired_million_remainder == MIPS_DIVISOR - 1);
    assign retired_million_remainder_next = selected_complete_valid
                                          ? (retire_million_wrap
                                             ? '0
                                             : retired_million_remainder + {{(MILLION_REMAINDER_WIDTH-1){1'b0}}, 1'b1})
                                          : retired_million_remainder;
    assign mips_accumulator_next = mips_accumulator + {15'd0, retire_million_wrap};
    assign retired_counter_next = retired_counter + {31'd0, selected_complete_valid};

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            cycle_counter             <= 32'd0;
            retired_counter           <= 32'd0;
            last_retired_count        <= 32'd0;
            retired_million_remainder <= '0;
            mips_accumulator          <= 16'd0;
            mips_value                <= 16'd0;
            measurement_window_seen   <= 1'b0;
        end else if (cpu_enable) begin
            if (cycle_counter == CLOCK_HZ - 1) begin
                cycle_counter             <= 32'd0;
                last_retired_count        <= retired_counter_next;
                retired_counter           <= 32'd0;
                retired_million_remainder <= '0;
                mips_accumulator          <= 16'd0;
                mips_value                <= mips_accumulator_next;
                measurement_window_seen   <= 1'b1;
            end else begin
                cycle_counter             <= cycle_counter + 32'd1;
                retired_counter           <= retired_counter_next;
                retired_million_remainder <= retired_million_remainder_next;
                mips_accumulator          <= mips_accumulator_next;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            redirect_seen  <= 1'b0;
            retire_seen    <= 1'b0;
            reg_write_seen <= 1'b0;
            mem_write_seen <= 1'b0;
        end else begin
            if (selected_redirect) begin
                redirect_seen <= 1'b1;
            end
            if (selected_complete_valid) begin
                retire_seen <= 1'b1;
            end
            if (selected_reg_write) begin
                reg_write_seen <= 1'b1;
            end
            if (selected_mem_write) begin
                mem_write_seen <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            refresh_counter <= 17'd0;
        end else begin
            refresh_counter <= refresh_counter + 17'd1;
        end
    end

    generate
        if (CPU_SELECT == 0) begin : gen_phase8
            logic [31:0] fetched_instruction;
            logic [31:0] instruction_addr;
            logic [2:0]  state;
            logic [31:0] instruction_reg;
            logic [31:0] instruction_pc;
            logic [3:0]  opcode_reg;
            logic [4:0]  rd_reg;
            logic [4:0]  rs1_reg;
            logic [4:0]  rs2_reg;
            logic [12:0] imm13_reg;
            logic [31:0] imm_ext_reg;
            logic        valid_instr;
            logic        reg_write;
            logic        mem_write;
            logic [31:0] alu_result;
            logic [31:0] memory_read_data;
            logic [31:0] imem [0:IMEM_DEPTH-1];

            integer imem_index;

            initial begin
                for (imem_index = 0; imem_index < IMEM_DEPTH; imem_index = imem_index + 1) begin
                    imem[imem_index] = 32'h0000_0000;
                end
                if (IMEM_INIT_FILE != "") begin
                    $readmemh(IMEM_INIT_FILE, imem);
                end
            end

            assign fetched_instruction = imem[instruction_addr[9:2]];

            cpu_core_multicycle cpu_inst (
                .clk(clk),
                .rst(rst_sync),
                .enable(cpu_enable),
                .fetched_instruction(fetched_instruction),
                .instruction_addr(instruction_addr),
                .state(state),
                .pc(selected_pc),
                .instruction_reg(instruction_reg),
                .instruction_pc(instruction_pc),
                .opcode_reg(opcode_reg),
                .rd_reg(rd_reg),
                .rs1_reg(rs1_reg),
                .rs2_reg(rs2_reg),
                .imm13_reg(imm13_reg),
                .imm_ext_reg(imm_ext_reg),
                .valid_instr(valid_instr),
                .reg_write(reg_write),
                .mem_write(mem_write),
                .alu_result(alu_result),
                .memory_read_data(memory_read_data)
            );

            assign selected_stage_valids   = {2'b00, state};
            assign selected_complete_valid = cpu_enable && multicycle_done(state, opcode_reg, valid_instr);
            assign selected_reg_write      = reg_write;
            assign selected_mem_write      = mem_write;
            assign selected_redirect       = cpu_enable && valid_instr && (state == 3'd2) &&
                                             ((opcode_reg == OP_BEQ) || (opcode_reg == OP_JUMP));
        end else if (CPU_SELECT == 1) begin : gen_phase10h
            logic [2:0]  state;
            logic [31:0] instruction_reg;
            logic [31:0] instruction_pc;
            logic [3:0]  opcode_reg;
            logic [4:0]  rd_reg;
            logic [4:0]  rs1_reg;
            logic [4:0]  rs2_reg;
            logic [12:0] imm13_reg;
            logic [31:0] imm_ext_reg;
            logic        valid_instr;
            logic        reg_write;
            logic        mem_write;
            logic [31:0] alu_result;
            logic [31:0] memory_read_data;
            logic [31:0] instruction_addr;
            logic [31:0] data_addr;

            cpu_core_multicycle_bram #(
                .IMEM_DEPTH(IMEM_DEPTH),
                .DMEM_DEPTH(DMEM_DEPTH),
                .IMEM_INIT_FILE(IMEM_INIT_FILE)
            ) cpu_inst (
                .clk(clk),
                .rst(rst_sync),
                .enable(cpu_enable),
                .state(state),
                .pc(selected_pc),
                .instruction_reg(instruction_reg),
                .instruction_pc(instruction_pc),
                .opcode_reg(opcode_reg),
                .rd_reg(rd_reg),
                .rs1_reg(rs1_reg),
                .rs2_reg(rs2_reg),
                .imm13_reg(imm13_reg),
                .imm_ext_reg(imm_ext_reg),
                .valid_instr(valid_instr),
                .reg_write(reg_write),
                .mem_write(mem_write),
                .alu_result(alu_result),
                .memory_read_data(memory_read_data),
                .instruction_addr(instruction_addr),
                .data_addr(data_addr)
            );

            assign selected_stage_valids   = {2'b00, state};
            assign selected_complete_valid = cpu_enable && bram_multicycle_done(state, opcode_reg, valid_instr);
            assign selected_reg_write      = reg_write;
            assign selected_mem_write      = mem_write;
            assign selected_redirect       = cpu_enable && valid_instr && (state == 3'd3) &&
                                             ((opcode_reg == OP_BEQ) || (opcode_reg == OP_JUMP));
        end else if (CPU_SELECT == 2) begin : gen_phase11e
            logic [2:0]  state;
            logic [31:0] instruction_reg;
            logic [31:0] instruction_pc;
            logic [3:0]  opcode_reg;
            logic [4:0]  rd_reg;
            logic [4:0]  rs1_reg;
            logic [4:0]  rs2_reg;
            logic [12:0] imm13_reg;
            logic [31:0] imm_ext_reg;
            logic        valid_instr;
            logic        reg_write;
            logic        mem_write;
            logic [31:0] alu_result;
            logic [31:0] memory_read_data;
            logic [31:0] instruction_addr;
            logic [31:0] data_addr;
            logic        prefetch_valid;
            logic [31:0] prefetch_pc;
            logic [31:0] prefetch_instruction;

            cpu_core_multicycle_bram_prefetch_ctrlopt #(
                .IMEM_DEPTH(IMEM_DEPTH),
                .DMEM_DEPTH(DMEM_DEPTH),
                .IMEM_INIT_FILE(IMEM_INIT_FILE)
            ) cpu_inst (
                .clk(clk),
                .rst(rst_sync),
                .enable(cpu_enable),
                .state(state),
                .pc(selected_pc),
                .instruction_reg(instruction_reg),
                .instruction_pc(instruction_pc),
                .opcode_reg(opcode_reg),
                .rd_reg(rd_reg),
                .rs1_reg(rs1_reg),
                .rs2_reg(rs2_reg),
                .imm13_reg(imm13_reg),
                .imm_ext_reg(imm_ext_reg),
                .valid_instr(valid_instr),
                .reg_write(reg_write),
                .mem_write(mem_write),
                .alu_result(alu_result),
                .memory_read_data(memory_read_data),
                .instruction_addr(instruction_addr),
                .data_addr(data_addr),
                .prefetch_valid(prefetch_valid),
                .prefetch_pc(prefetch_pc),
                .prefetch_instruction(prefetch_instruction)
            );

            assign selected_stage_valids   = {2'b00, state};
            assign selected_complete_valid = cpu_enable && bram_multicycle_done(state, opcode_reg, valid_instr);
            assign selected_reg_write      = reg_write;
            assign selected_mem_write      = mem_write;
            assign selected_redirect       = cpu_enable && valid_instr && (state == 3'd3) &&
                                             ((opcode_reg == OP_BEQ) || (opcode_reg == OP_JUMP));
        end else if (CPU_SELECT == 3) begin : gen_phase12
            logic [31:0] instruction_addr;
            logic [31:0] fetch_request_pc;
            logic        fetch_request_valid;
            logic        if_id_valid;
            logic [31:0] if_id_pc;
            logic [31:0] if_id_instruction;
            logic [3:0]  decoded_opcode;
            logic        decoded_valid;
            logic        id_ex_valid;
            logic        ex_mem_valid;
            logic        mem_wb_valid;
            logic [31:0] alu_result;
            logic [31:0] data_addr;
            logic [31:0] memory_read_data;
            logic        retire_valid;
            logic [31:0] retire_pc;
            logic [3:0]  retire_opcode;
            logic [4:0]  retire_rd;
            logic        retire_reg_write;
            logic [31:0] retire_write_data;
            logic        retire_mem_write;
            logic [31:0] retire_mem_addr;
            logic [31:0] retire_mem_data;
            logic        reg_write;
            logic        mem_write;
            logic        pc_redirect;
            logic [31:0] total_cycles;
            logic [31:0] retired_instructions;
            logic [31:0] pipeline_fill_cycles;
            logic [31:0] data_hazard_stall_cycles;
            logic [31:0] load_use_stall_cycles;
            logic [31:0] control_hazard_flush_cycles;
            logic [31:0] instruction_fetch_wait_cycles;
            logic [31:0] memory_wait_cycles;
            logic [31:0] taken_branches;
            logic [31:0] not_taken_branches;
            logic [31:0] jumps;
            logic [31:0] wrong_path_instructions_flushed;

            cpu_core_pipeline_full #(
                .IMEM_DEPTH(IMEM_DEPTH),
                .DMEM_DEPTH(DMEM_DEPTH),
                .IMEM_INIT_FILE(IMEM_INIT_FILE)
            ) cpu_inst (
                .clk(clk),
                .rst(rst_sync),
                .enable(cpu_enable),
                .fetch_pc(selected_pc),
                .instruction_addr(instruction_addr),
                .fetch_request_pc(fetch_request_pc),
                .fetch_request_valid(fetch_request_valid),
                .if_id_valid(if_id_valid),
                .if_id_pc(if_id_pc),
                .if_id_instruction(if_id_instruction),
                .decoded_opcode(decoded_opcode),
                .decoded_valid(decoded_valid),
                .id_ex_valid(id_ex_valid),
                .ex_mem_valid(ex_mem_valid),
                .mem_wb_valid(mem_wb_valid),
                .alu_result(alu_result),
                .data_addr(data_addr),
                .memory_read_data(memory_read_data),
                .retire_valid(retire_valid),
                .retire_pc(retire_pc),
                .retire_opcode(retire_opcode),
                .retire_rd(retire_rd),
                .retire_reg_write(retire_reg_write),
                .retire_write_data(retire_write_data),
                .retire_mem_write(retire_mem_write),
                .retire_mem_addr(retire_mem_addr),
                .retire_mem_data(retire_mem_data),
                .reg_write(reg_write),
                .mem_write(mem_write),
                .pc_redirect(pc_redirect),
                .total_cycles(total_cycles),
                .retired_instructions(retired_instructions),
                .pipeline_fill_cycles(pipeline_fill_cycles),
                .data_hazard_stall_cycles(data_hazard_stall_cycles),
                .load_use_stall_cycles(load_use_stall_cycles),
                .control_hazard_flush_cycles(control_hazard_flush_cycles),
                .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
                .memory_wait_cycles(memory_wait_cycles),
                .taken_branches(taken_branches),
                .not_taken_branches(not_taken_branches),
                .jumps(jumps),
                .wrong_path_instructions_flushed(wrong_path_instructions_flushed)
            );

            assign selected_stage_valids   = {2'b00, id_ex_valid, ex_mem_valid, mem_wb_valid};
            assign selected_complete_valid = retire_valid;
            assign selected_reg_write      = reg_write;
            assign selected_mem_write      = mem_write;
            assign selected_redirect       = pc_redirect;
        end else if (CPU_SELECT == 4) begin : gen_phase13e
            logic [31:0] instruction_addr;
            logic [31:0] fetch_request_pc;
            logic        fetch_request_valid;
            logic        if_id_valid;
            logic [31:0] if_id_pc;
            logic [31:0] if_id_instruction;
            logic [3:0]  decoded_opcode;
            logic        decoded_valid;
            logic        id_ex_valid;
            logic        ex_mem_valid;
            logic        mem_wb_valid;
            logic [31:0] alu_result;
            logic [31:0] data_addr;
            logic [31:0] memory_read_data;
            logic        retire_valid;
            logic [31:0] retire_pc;
            logic [3:0]  retire_opcode;
            logic [4:0]  retire_rd;
            logic        retire_reg_write;
            logic [31:0] retire_write_data;
            logic        retire_mem_write;
            logic [31:0] retire_mem_addr;
            logic [31:0] retire_mem_data;
            logic        reg_write;
            logic        mem_write;
            logic        pc_redirect;
            logic [31:0] total_cycles;
            logic [31:0] retired_instructions;
            logic [31:0] pipeline_fill_cycles;
            logic [31:0] data_hazard_stall_cycles;
            logic [31:0] load_use_stall_cycles;
            logic [31:0] control_hazard_flush_cycles;
            logic [31:0] instruction_fetch_wait_cycles;
            logic [31:0] memory_wait_cycles;
            logic [31:0] taken_branches;
            logic [31:0] not_taken_branches;
            logic [31:0] jumps;
            logic [31:0] wrong_path_instructions_flushed;

            cpu_core_pipeline_forwardtiming #(
                .IMEM_DEPTH(IMEM_DEPTH),
                .DMEM_DEPTH(DMEM_DEPTH),
                .IMEM_INIT_FILE(IMEM_INIT_FILE)
            ) cpu_inst (
                .clk(clk),
                .rst(rst_sync),
                .enable(cpu_enable),
                .fetch_pc(selected_pc),
                .instruction_addr(instruction_addr),
                .fetch_request_pc(fetch_request_pc),
                .fetch_request_valid(fetch_request_valid),
                .if_id_valid(if_id_valid),
                .if_id_pc(if_id_pc),
                .if_id_instruction(if_id_instruction),
                .decoded_opcode(decoded_opcode),
                .decoded_valid(decoded_valid),
                .id_ex_valid(id_ex_valid),
                .ex_mem_valid(ex_mem_valid),
                .mem_wb_valid(mem_wb_valid),
                .alu_result(alu_result),
                .data_addr(data_addr),
                .memory_read_data(memory_read_data),
                .retire_valid(retire_valid),
                .retire_pc(retire_pc),
                .retire_opcode(retire_opcode),
                .retire_rd(retire_rd),
                .retire_reg_write(retire_reg_write),
                .retire_write_data(retire_write_data),
                .retire_mem_write(retire_mem_write),
                .retire_mem_addr(retire_mem_addr),
                .retire_mem_data(retire_mem_data),
                .reg_write(reg_write),
                .mem_write(mem_write),
                .pc_redirect(pc_redirect),
                .total_cycles(total_cycles),
                .retired_instructions(retired_instructions),
                .pipeline_fill_cycles(pipeline_fill_cycles),
                .data_hazard_stall_cycles(data_hazard_stall_cycles),
                .load_use_stall_cycles(load_use_stall_cycles),
                .control_hazard_flush_cycles(control_hazard_flush_cycles),
                .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
                .memory_wait_cycles(memory_wait_cycles),
                .taken_branches(taken_branches),
                .not_taken_branches(not_taken_branches),
                .jumps(jumps),
                .wrong_path_instructions_flushed(wrong_path_instructions_flushed)
            );

            assign selected_stage_valids   = {2'b00, id_ex_valid, ex_mem_valid, mem_wb_valid};
            assign selected_complete_valid = retire_valid;
            assign selected_reg_write      = reg_write;
            assign selected_mem_write      = mem_write;
            assign selected_redirect       = pc_redirect;
        end else begin : gen_phase14g
            logic [31:0] instruction_addr;
            logic        fetch_request_valid;
            logic [31:0] fetch_request_pc;
            logic        if_id_valid;
            logic        id_op_valid;
            logic        op_ex_valid;
            logic        ex_mem_valid;
            logic        mem_wb_valid;
            logic        retire_valid;
            logic        reg_write;
            logic        mem_write;
            logic        redirect_valid;

            cpu_core_pipeline6 #(
                .IMEM_DEPTH(IMEM_DEPTH),
                .IMEM_INIT_FILE(IMEM_INIT_FILE)
            ) cpu_inst (
                .clk(clk),
                .rst(rst_sync),
                .enable(cpu_enable),
                .debug_fetch_pc(selected_pc),
                .debug_instruction_addr(instruction_addr),
                .debug_fetch_request_valid(fetch_request_valid),
                .debug_fetch_request_pc(fetch_request_pc),
                .debug_if_id_valid(if_id_valid),
                .debug_id_op_valid(id_op_valid),
                .debug_op_ex_valid(op_ex_valid),
                .debug_ex_mem_valid(ex_mem_valid),
                .debug_mem_wb_valid(mem_wb_valid),
                .debug_if_id_pc(),
                .debug_id_op_pc(),
                .debug_op_ex_pc(),
                .debug_ex_mem_pc(),
                .debug_mem_wb_pc(),
                .debug_if_id_instr(),
                .debug_id_op_instr(),
                .debug_op_ex_instr(),
                .debug_ex_mem_instr(),
                .debug_mem_wb_instr(),
                .debug_if_id_opcode(),
                .debug_id_op_opcode(),
                .debug_op_ex_opcode(),
                .debug_ex_mem_opcode(),
                .debug_mem_wb_opcode(),
                .debug_if_id_decoded_valid(),
                .debug_id_op_decoded_valid(),
                .debug_op_ex_decoded_valid(),
                .debug_ex_mem_decoded_valid(),
                .debug_mem_wb_decoded_valid(),
                .debug_retired_count(),
                .debug_retire_valid(retire_valid),
                .debug_retire_pc(),
                .debug_retire_opcode(),
                .debug_reg_write(reg_write),
                .debug_mem_write(mem_write),
                .debug_mem_read(),
                .debug_mem_addr(),
                .debug_mem_write_data(),
                .debug_mem_read_data(),
                .debug_load_use_stall(),
                .debug_redirect_valid(redirect_valid),
                .debug_redirect_pc(),
                .debug_flush_valid(),
                .debug_branch_taken(),
                .debug_jump_taken(),
                .debug_writeback_valid(),
                .debug_writeback_rd(),
                .debug_writeback_data(),
                .debug_stall_active(),
                .debug_x0(),
                .debug_x1(),
                .debug_x2(),
                .debug_x3(),
                .debug_x4(),
                .debug_x5(),
                .debug_x6(),
                .debug_x7(),
                .debug_x8(),
                .debug_x9(),
                .debug_x10(),
                .debug_x11(),
                .debug_x12(),
                .debug_x13()
            );

            assign selected_stage_valids   = {if_id_valid, id_op_valid, op_ex_valid, ex_mem_valid, mem_wb_valid};
            assign selected_complete_valid = retire_valid;
            assign selected_reg_write      = reg_write;
            assign selected_mem_write      = mem_write;
            assign selected_redirect       = redirect_valid;
        end
    endgenerate

    // SW1 selects a small CPU ID display for board sanity checking. SW1 low
    // displays measured integer MIPS; SW1 high displays CPU_SELECT.
    assign display_value = sw_sync[1] ? CPU_SELECT_DISPLAY : mips_value;
    assign display_clamped = (display_value > 16'd9999) ? 14'd9999 : display_value[13:0];
    assign bcd_digits = bin14_to_bcd4(display_clamped);
    assign digit_select = refresh_counter[16:15];

    always_comb begin
        unique case (digit_select)
            2'd0: begin
                an = 4'b1110;
                active_digit = bcd_digits[3:0];
            end
            2'd1: begin
                an = 4'b1101;
                active_digit = bcd_digits[7:4];
            end
            2'd2: begin
                an = 4'b1011;
                active_digit = bcd_digits[11:8];
            end
            default: begin
                an = 4'b0111;
                active_digit = bcd_digits[15:12];
            end
        endcase

        seg = seven_segment_active_low(active_digit);
        dp  = 1'b1;

        led[3:0] = selected_pc[5:2];
        led[8:4] = selected_stage_valids;
        led[9]   = measurement_window_seen;
        led[10]  = redirect_seen;
        led[11]  = retire_seen;
        led[12]  = reg_write_seen;
        led[13]  = mem_write_seen;
        led[14]  = sw_sync[1];
        led[15]  = cpu_enable;
    end

endmodule
