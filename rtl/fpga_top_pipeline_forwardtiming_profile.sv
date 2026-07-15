module fpga_top_pipeline_forwardtiming_profile #(
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

    localparam int unsigned MILLION_REMAINDER_WIDTH = $clog2(MIPS_DIVISOR);

    logic rst_meta;
    logic rst_sync;
    logic [1:0] sw_meta;
    logic [1:0] sw_sync;
    logic cpu_enable;

    logic [31:0] fetch_pc;
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

    logic [31:0] cycle_counter;
    logic [31:0] retired_counter;
    logic [31:0] last_retired_count;
    logic [MILLION_REMAINDER_WIDTH-1:0] retired_million_remainder;
    logic [15:0] mips_accumulator;
    logic [15:0] mips_value;
    logic [15:0] cpi_x100_value;
    logic        measurement_window_seen;

    logic [MILLION_REMAINDER_WIDTH-1:0] retired_million_remainder_next;
    logic [15:0] mips_accumulator_next;
    logic        retire_million_wrap;
    logic [31:0] retired_counter_next;

    logic [31:0] total_cycles_prev;
    logic [31:0] retired_instructions_prev;
    logic [31:0] load_use_stall_cycles_prev;
    logic [31:0] control_hazard_flush_cycles_prev;
    logic [31:0] instruction_fetch_wait_cycles_prev;
    logic [31:0] memory_wait_cycles_prev;
    logic [31:0] taken_branches_prev;
    logic [31:0] not_taken_branches_prev;
    logic [31:0] jumps_prev;
    logic [31:0] wrong_path_flushed_prev;

    (* keep = "true" *) logic [31:0] last_total_cycles_window;
    (* keep = "true" *) logic [31:0] last_retired_window;
    (* keep = "true" *) logic [31:0] last_load_use_stalls_window;
    (* keep = "true" *) logic [31:0] last_control_flushes_window;
    (* keep = "true" *) logic [31:0] last_fetch_waits_window;
    (* keep = "true" *) logic [31:0] last_memory_waits_window;
    (* keep = "true" *) logic [31:0] last_taken_branches_window;
    (* keep = "true" *) logic [31:0] last_not_taken_branches_window;
    (* keep = "true" *) logic [31:0] last_jumps_window;
    (* keep = "true" *) logic [31:0] last_wrong_path_flushed_window;

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

    always_ff @(posedge clk) begin
        rst_meta <= rst_btn;
        rst_sync <= rst_meta;
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
    end

    assign cpu_enable = sw_sync[0];

    assign retire_million_wrap = retire_valid &&
                                 (retired_million_remainder == MIPS_DIVISOR - 1);
    assign retired_million_remainder_next = retire_valid
                                          ? (retire_million_wrap
                                             ? '0
                                             : retired_million_remainder + {{(MILLION_REMAINDER_WIDTH-1){1'b0}}, 1'b1})
                                          : retired_million_remainder;
    assign mips_accumulator_next = mips_accumulator + {15'd0, retire_million_wrap};
    assign retired_counter_next = retired_counter + {31'd0, retire_valid};

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            cycle_counter              <= 32'd0;
            retired_counter            <= 32'd0;
            last_retired_count         <= 32'd0;
            retired_million_remainder  <= '0;
            mips_accumulator           <= 16'd0;
            mips_value                 <= 16'd0;
            cpi_x100_value             <= 16'd0;
            measurement_window_seen    <= 1'b0;

            total_cycles_prev                  <= 32'd0;
            retired_instructions_prev          <= 32'd0;
            load_use_stall_cycles_prev         <= 32'd0;
            control_hazard_flush_cycles_prev   <= 32'd0;
            instruction_fetch_wait_cycles_prev <= 32'd0;
            memory_wait_cycles_prev            <= 32'd0;
            taken_branches_prev                <= 32'd0;
            not_taken_branches_prev            <= 32'd0;
            jumps_prev                         <= 32'd0;
            wrong_path_flushed_prev            <= 32'd0;

            last_total_cycles_window           <= 32'd0;
            last_retired_window                <= 32'd0;
            last_load_use_stalls_window        <= 32'd0;
            last_control_flushes_window        <= 32'd0;
            last_fetch_waits_window            <= 32'd0;
            last_memory_waits_window           <= 32'd0;
            last_taken_branches_window         <= 32'd0;
            last_not_taken_branches_window     <= 32'd0;
            last_jumps_window                  <= 32'd0;
            last_wrong_path_flushed_window     <= 32'd0;
        end else if (cpu_enable) begin
            if (cycle_counter == CLOCK_HZ - 1) begin
                cycle_counter             <= 32'd0;
                last_retired_count        <= retired_counter_next;
                retired_counter           <= 32'd0;
                retired_million_remainder <= '0;
                mips_accumulator          <= 16'd0;
                mips_value                <= mips_accumulator_next;
                cpi_x100_value            <= (mips_accumulator_next == 16'd0)
                                           ? 16'd0
                                           : ((16'd10000 + (mips_accumulator_next >> 1)) / mips_accumulator_next);
                measurement_window_seen   <= 1'b1;

                last_total_cycles_window       <= total_cycles - total_cycles_prev;
                last_retired_window            <= retired_instructions - retired_instructions_prev;
                last_load_use_stalls_window    <= load_use_stall_cycles - load_use_stall_cycles_prev;
                last_control_flushes_window    <= control_hazard_flush_cycles - control_hazard_flush_cycles_prev;
                last_fetch_waits_window        <= instruction_fetch_wait_cycles - instruction_fetch_wait_cycles_prev;
                last_memory_waits_window       <= memory_wait_cycles - memory_wait_cycles_prev;
                last_taken_branches_window     <= taken_branches - taken_branches_prev;
                last_not_taken_branches_window <= not_taken_branches - not_taken_branches_prev;
                last_jumps_window              <= jumps - jumps_prev;
                last_wrong_path_flushed_window <= wrong_path_instructions_flushed - wrong_path_flushed_prev;

                total_cycles_prev                  <= total_cycles;
                retired_instructions_prev          <= retired_instructions;
                load_use_stall_cycles_prev         <= load_use_stall_cycles;
                control_hazard_flush_cycles_prev   <= control_hazard_flush_cycles;
                instruction_fetch_wait_cycles_prev <= instruction_fetch_wait_cycles;
                memory_wait_cycles_prev            <= memory_wait_cycles;
                taken_branches_prev                <= taken_branches;
                not_taken_branches_prev            <= not_taken_branches;
                jumps_prev                         <= jumps;
                wrong_path_flushed_prev            <= wrong_path_instructions_flushed;
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
            if (pc_redirect) begin
                redirect_seen <= 1'b1;
            end
            if (retire_valid) begin
                retire_seen <= 1'b1;
            end
            if (reg_write) begin
                reg_write_seen <= 1'b1;
            end
            if (mem_write) begin
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

    cpu_core_pipeline_forwardtiming #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_sync),
        .enable(cpu_enable),
        .fetch_pc(fetch_pc),
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

    assign display_value = sw_sync[1] ? cpi_x100_value : mips_value;
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

        // LED debug map:
        // led[3:0]   = fetch PC word index
        // led[7:4]   = decoded opcode
        // led[8]     = IF/ID valid
        // led[9]     = sticky retire observed
        // led[10]    = sticky register write observed
        // led[11]    = sticky memory write observed
        // led[12]    = sticky redirect observed
        // led[15:13] = pipeline stage valid bits {ID/EX, EX/MEM, MEM/WB}
        led[3:0]   = fetch_pc[5:2];
        led[7:4]   = decoded_opcode;
        led[8]     = if_id_valid;
        led[9]     = retire_seen;
        led[10]    = reg_write_seen;
        led[11]    = mem_write_seen;
        led[12]    = redirect_seen;
        led[15:13] = {id_ex_valid, ex_mem_valid, mem_wb_valid};
    end

endmodule
