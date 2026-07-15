module fpga_top_pipeline6_perf7seg #(
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
    parameter int unsigned IMEM_DEPTH = 256,
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
    logic        if_id_valid;
    logic        id_op_valid;
    logic        op_ex_valid;
    logic        ex_mem_valid;
    logic        mem_wb_valid;
    logic        retire_valid;
    logic        reg_write;
    logic        mem_write;
    logic        redirect_valid;

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
    logic [13:0] mips_display_clamped;
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
            measurement_window_seen    <= 1'b0;
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
            if (redirect_valid) begin
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

    cpu_core_pipeline6 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_sync),
        .enable(cpu_enable),
        .debug_fetch_pc(fetch_pc),
        .debug_instruction_addr(),
        .debug_fetch_request_valid(),
        .debug_fetch_request_pc(),
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

    assign mips_display_clamped = (mips_value > 16'd9999) ? 14'd9999 : mips_value[13:0];
    assign bcd_digits = bin14_to_bcd4(mips_display_clamped);
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
        // led[8:4]   = pipeline valid bits
        // led[9]     = sticky one-second measurement window completed
        // led[10]    = sticky redirect observed
        // led[11]    = sticky retire observed
        // led[12]    = sticky register write observed
        // led[13]    = sticky memory write observed
        // led[14]    = measurement active
        // led[15]    = run enable
        led[3:0] = fetch_pc[5:2];
        led[4]   = if_id_valid;
        led[5]   = id_op_valid;
        led[6]   = op_ex_valid;
        led[7]   = ex_mem_valid;
        led[8]   = mem_wb_valid;
        led[9]   = measurement_window_seen;
        led[10]  = redirect_seen;
        led[11]  = retire_seen;
        led[12]  = reg_write_seen;
        led[13]  = mem_write_seen;
        led[14]  = cpu_enable;
        led[15]  = sw_sync[0];
    end

endmodule
