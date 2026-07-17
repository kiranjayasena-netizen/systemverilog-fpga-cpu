module fpga_top_phase19b_pipeline6_mmcm_mips #(
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256,
    parameter int unsigned CPU_CLOCK_HZ = 150_000_000,
    parameter int unsigned MIPS_DIVISOR = 1_000_000,
    parameter int unsigned CLOCK_DEBUG_MHZ = 150,
    parameter int unsigned MMCM_DIVCLK_DIVIDE = 2,
    parameter real         MMCM_CLKFBOUT_MULT_F = 15.000,
    parameter real         MMCM_CLKOUT0_DIVIDE_F = 5.000
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    localparam int unsigned MILLION_REMAINDER_WIDTH = $clog2(MIPS_DIVISOR);

    logic clkfb;
    logic clkfb_buf;
    logic cpu_clk_unbuf;
    logic cpu_clk;
    logic mmcm_locked;

    logic rst_meta;
    logic rst_sync;
    logic [3:0] sw_meta;
    logic [3:0] sw_sync;
    logic cpu_reset;
    logic cpu_enable;
    logic [2:0] display_mode;

    logic [31:0] fetch_pc;
    logic        if_id_valid;
    logic        id_op_valid;
    logic        op_ex_valid;
    logic        ex_mem_valid;
    logic        mem_wb_valid;
    logic        retire_valid;
    logic [3:0]  retire_opcode;
    logic        reg_write;
    logic        mem_write;
    logic        redirect_valid;
    logic        load_use_stall;
    logic        stall_active;

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

    logic retire_seen;
    logic reg_write_seen;
    logic mem_write_seen;
    logic redirect_seen;

    logic [16:0] refresh_counter;
    logic [1:0]  digit_select;
    logic [13:0] display_clamped;
    logic [15:0] bcd_digits;
    logic [3:0]  active_digit;
    logic [15:0] display_value;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(MMCM_CLKFBOUT_MULT_F),
        .CLKFBOUT_PHASE(0.000),
        .CLKIN1_PERIOD(10.000),
        .CLKOUT0_DIVIDE_F(MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .DIVCLK_DIVIDE(MMCM_DIVCLK_DIVIDE),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) cpu_clk_mmcm (
        .CLKIN1(clk),
        .CLKFBIN(clkfb_buf),
        .RST(rst_btn),
        .PWRDWN(1'b0),
        .CLKFBOUT(clkfb),
        .CLKFBOUTB(),
        .CLKOUT0(cpu_clk_unbuf),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(mmcm_locked)
    );

    BUFG clkfb_bufg (
        .I(clkfb),
        .O(clkfb_buf)
    );

    BUFG cpu_clk_bufg (
        .I(cpu_clk_unbuf),
        .O(cpu_clk)
    );

    always_ff @(posedge cpu_clk) begin
        rst_meta <= rst_btn || !mmcm_locked;
        rst_sync <= rst_meta;
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
    end

    assign cpu_reset = rst_sync;
    assign cpu_enable = sw_sync[0];
    assign display_mode = sw_sync[3:1];

    assign retire_million_wrap = retire_valid &&
                                 (retired_million_remainder == MIPS_DIVISOR - 1);
    assign retired_million_remainder_next = retire_valid
                                          ? (retire_million_wrap
                                             ? '0
                                             : retired_million_remainder + {{(MILLION_REMAINDER_WIDTH-1){1'b0}}, 1'b1})
                                          : retired_million_remainder;
    assign mips_accumulator_next = mips_accumulator + {15'd0, retire_million_wrap};
    assign retired_counter_next = retired_counter + {31'd0, retire_valid};

    function automatic logic [15:0] bin14_to_bcd4(input logic [13:0] bin_value);
        logic [29:0] shift_reg;
        int i;
        begin
            shift_reg = 30'd0;
            shift_reg[13:0] = bin_value;
            for (i = 0; i < 14; i++) begin
                if (shift_reg[17:14] >= 4'd5) shift_reg[17:14] = shift_reg[17:14] + 4'd3;
                if (shift_reg[21:18] >= 4'd5) shift_reg[21:18] = shift_reg[21:18] + 4'd3;
                if (shift_reg[25:22] >= 4'd5) shift_reg[25:22] = shift_reg[25:22] + 4'd3;
                if (shift_reg[29:26] >= 4'd5) shift_reg[29:26] = shift_reg[29:26] + 4'd3;
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

    always_ff @(posedge cpu_clk) begin
        if (cpu_reset) begin
            cycle_counter              <= 32'd0;
            retired_counter            <= 32'd0;
            last_retired_count         <= 32'd0;
            retired_million_remainder  <= '0;
            mips_accumulator           <= 16'd0;
            mips_value                 <= 16'd0;
            measurement_window_seen    <= 1'b0;
            retire_seen                <= 1'b0;
            reg_write_seen             <= 1'b0;
            mem_write_seen             <= 1'b0;
            redirect_seen              <= 1'b0;
        end else begin
            if (retire_valid)  retire_seen   <= 1'b1;
            if (reg_write)     reg_write_seen <= 1'b1;
            if (mem_write)     mem_write_seen <= 1'b1;
            if (redirect_valid) redirect_seen <= 1'b1;

            if (cpu_enable) begin
                retired_million_remainder <= retired_million_remainder_next;
                mips_accumulator <= mips_accumulator_next;
                retired_counter <= retired_counter_next;

                if (cycle_counter == CPU_CLOCK_HZ - 1) begin
                    cycle_counter <= 32'd0;
                    last_retired_count <= retired_counter_next;
                    mips_value <= mips_accumulator_next;
                    retired_counter <= 32'd0;
                    retired_million_remainder <= '0;
                    mips_accumulator <= 16'd0;
                    measurement_window_seen <= 1'b1;
                end else begin
                    cycle_counter <= cycle_counter + 32'd1;
                end
            end
        end
    end

    always_comb begin
        unique case (display_mode)
            3'b000: display_value = mips_value;
            3'b001: display_value = mips_value;
            3'b010: display_value = {15'd0, load_use_stall};
            3'b011: display_value = {15'd0, redirect_valid};
            3'b100: display_value = last_retired_count[15:0];
            3'b101: display_value = {15'd0, stall_active};
            3'b110: display_value = CLOCK_DEBUG_MHZ[15:0];
            default: display_value = mips_value;
        endcase
    end

    assign display_clamped = (display_value > 16'd9999) ? 14'd9999 : display_value[13:0];
    assign bcd_digits = bin14_to_bcd4(display_clamped);

    always_ff @(posedge cpu_clk) begin
        if (cpu_reset) begin
            refresh_counter <= 17'd0;
        end else begin
            refresh_counter <= refresh_counter + 17'd1;
        end
    end

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
    end

    assign seg = seven_segment_active_low(active_digit);
    assign dp = 1'b1;

    always_comb begin
        led = 16'h0000;
        led[0] = mmcm_locked;
        led[1] = cpu_enable;
        led[2] = measurement_window_seen;
        led[3] = cpu_reset;
        led[7:4] = fetch_pc[5:2];
        led[8] = if_id_valid;
        led[9] = retire_seen;
        led[10] = reg_write_seen;
        led[11] = mem_write_seen;
        led[12] = redirect_seen;
        led[15:13] = {op_ex_valid, ex_mem_valid, mem_wb_valid};
    end

    cpu_core_pipeline6 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(cpu_clk),
        .rst(cpu_reset),
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
        .debug_retire_opcode(retire_opcode),
        .debug_reg_write(reg_write),
        .debug_mem_write(mem_write),
        .debug_mem_read(),
        .debug_mem_addr(),
        .debug_mem_write_data(),
        .debug_mem_read_data(),
        .debug_load_use_stall(load_use_stall),
        .debug_redirect_valid(redirect_valid),
        .debug_redirect_pc(),
        .debug_flush_valid(),
        .debug_branch_taken(),
        .debug_jump_taken(),
        .debug_writeback_valid(),
        .debug_writeback_rd(),
        .debug_writeback_data(),
        .debug_stall_active(stall_active),
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
endmodule

module fpga_top_phase19b_pipeline6_mmcm_150 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19b_pipeline6_mmcm_mips #(
        .CPU_CLOCK_HZ(150_000_000),
        .CLOCK_DEBUG_MHZ(150),
        .MMCM_DIVCLK_DIVIDE(2),
        .MMCM_CLKFBOUT_MULT_F(15.000),
        .MMCM_CLKOUT0_DIVIDE_F(5.000)
    ) impl (.*);
endmodule

module fpga_top_phase19b_pipeline6_mmcm_155 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19b_pipeline6_mmcm_mips #(
        .CPU_CLOCK_HZ(155_000_000),
        .CLOCK_DEBUG_MHZ(155),
        .MMCM_DIVCLK_DIVIDE(2),
        .MMCM_CLKFBOUT_MULT_F(15.500),
        .MMCM_CLKOUT0_DIVIDE_F(5.000)
    ) impl (.*);
endmodule

module fpga_top_phase19b_pipeline6_mmcm_160 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19b_pipeline6_mmcm_mips #(
        .CPU_CLOCK_HZ(160_000_000),
        .CLOCK_DEBUG_MHZ(160),
        .MMCM_DIVCLK_DIVIDE(2),
        .MMCM_CLKFBOUT_MULT_F(16.000),
        .MMCM_CLKOUT0_DIVIDE_F(5.000)
    ) impl (.*);
endmodule

module fpga_top_phase19b_pipeline6_mmcm_166p667 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19b_pipeline6_mmcm_mips #(
        .CPU_CLOCK_HZ(166_666_667),
        .CLOCK_DEBUG_MHZ(167),
        .MMCM_DIVCLK_DIVIDE(1),
        .MMCM_CLKFBOUT_MULT_F(10.000),
        .MMCM_CLKOUT0_DIVIDE_F(6.000)
    ) impl (.*);
endmodule
