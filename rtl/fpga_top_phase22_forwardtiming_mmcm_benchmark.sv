module fpga_top_phase22_forwardtiming_mmcm_benchmark #(
    parameter string       IMEM_INIT_FILE = "programs/final_benchmark.mem",
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256,
    parameter int unsigned CPU_CLOCK_HZ = 115_000_000,
    parameter int unsigned MIPS_DIVISOR = 1_000_000,
    parameter int unsigned CLOCK_DEBUG_MHZ = 115,
    parameter int unsigned MMCM_DIVCLK_DIVIDE = 4,
    parameter real         MMCM_CLKFBOUT_MULT_F = 28.875,
    parameter real         MMCM_CLKOUT0_DIVIDE_F = 6.250
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
    localparam int unsigned CPI_DIV_WIDTH = 14;
    localparam int unsigned PERCENT_STEP_CYCLES = CPU_CLOCK_HZ / 10_000;

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
    logic        measurement_window_seen;
    logic        measurement_rollover;

    logic        cpi_div_active;
    logic [3:0]  cpi_div_bit;
    logic [13:0] cpi_div_numerator;
    logic [13:0] cpi_div_denominator;
    logic [13:0] cpi_div_remainder;
    logic [13:0] cpi_div_quotient;
    logic [13:0] cpi_x100_value;
    logic [14:0] cpi_div_remainder_candidate;
    logic [14:0] cpi_div_subtract_result;
    logic [13:0] cpi_div_remainder_next;
    logic [13:0] cpi_div_quotient_next;

    logic [31:0] sample_load_use_stall_cycles;
    logic [31:0] sample_control_hazard_flush_cycles;
    logic [31:0] sample_instruction_fetch_wait_cycles;
    logic [31:0] sample_memory_wait_cycles;
    logic [31:0] sample_taken_branches;
    logic [31:0] sample_not_taken_branches;
    logic [31:0] sample_jumps;

    logic load_use_event;
    logic control_flush_event;
    logic fetch_wait_event;
    logic memory_wait_event;
    logic branch_jump_event;

    logic [15:0] load_use_pct_accum;
    logic [15:0] control_flush_pct_accum;
    logic [15:0] fetch_wait_pct_accum;
    logic [15:0] memory_wait_pct_accum;
    logic [15:0] branch_jump_count_accum;

    logic [13:0] load_use_pct_remainder;
    logic [13:0] control_flush_pct_remainder;
    logic [13:0] fetch_wait_pct_remainder;
    logic [13:0] memory_wait_pct_remainder;

    logic [15:0] load_use_pct_x100_value;
    logic [15:0] control_flush_pct_x100_value;
    logic [15:0] fetch_wait_pct_x100_value;
    logic [15:0] memory_wait_pct_x100_value;
    logic [15:0] branch_jump_count_value;

    logic [29:0] load_use_pct_next;
    logic [29:0] control_flush_pct_next;
    logic [29:0] fetch_wait_pct_next;
    logic [29:0] memory_wait_pct_next;
    logic [15:0] branch_jump_count_next;

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

    function automatic logic [29:0] advance_percent_x100(
        input logic [15:0] accum,
        input logic [13:0] remainder,
        input logic        event_active
    );
        logic [15:0] accum_next;
        logic [13:0] remainder_next;
        begin
            accum_next = accum;
            remainder_next = remainder;

            if (event_active) begin
                if (remainder == PERCENT_STEP_CYCLES - 1) begin
                    remainder_next = 14'd0;
                    if (accum != 16'd9999) begin
                        accum_next = accum + 16'd1;
                    end
                end else begin
                    remainder_next = remainder + 14'd1;
                end
            end

            advance_percent_x100 = {accum_next, remainder_next};
        end
    endfunction

    always_ff @(posedge cpu_clk) begin
        rst_meta <= rst_btn || !mmcm_locked;
        rst_sync <= rst_meta;
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
    end

    assign cpu_reset = rst_sync;
    assign cpu_enable = sw_sync[0] && mmcm_locked;
    assign display_mode = sw_sync[3:1];

    assign load_use_event = load_use_stall_cycles != sample_load_use_stall_cycles;
    assign control_flush_event = control_hazard_flush_cycles != sample_control_hazard_flush_cycles;
    assign fetch_wait_event = instruction_fetch_wait_cycles != sample_instruction_fetch_wait_cycles;
    assign memory_wait_event = memory_wait_cycles != sample_memory_wait_cycles;
    assign branch_jump_event = (taken_branches != sample_taken_branches) ||
                               (not_taken_branches != sample_not_taken_branches) ||
                               (jumps != sample_jumps);

    assign retire_million_wrap = retire_valid &&
                                 (retired_million_remainder == MIPS_DIVISOR - 1);
    assign retired_million_remainder_next = retire_valid
                                          ? (retire_million_wrap
                                             ? '0
                                             : retired_million_remainder + {{(MILLION_REMAINDER_WIDTH-1){1'b0}}, 1'b1})
                                          : retired_million_remainder;
    assign mips_accumulator_next = mips_accumulator + {15'd0, retire_million_wrap};
    assign retired_counter_next = retired_counter + {31'd0, retire_valid};

    assign cpi_div_remainder_candidate = {cpi_div_remainder, cpi_div_numerator[cpi_div_bit]};
    assign cpi_div_subtract_result = cpi_div_remainder_candidate - {1'b0, cpi_div_denominator};
    assign load_use_pct_next = advance_percent_x100(load_use_pct_accum,
                                                     load_use_pct_remainder,
                                                     load_use_event);
    assign control_flush_pct_next = advance_percent_x100(control_flush_pct_accum,
                                                         control_flush_pct_remainder,
                                                         control_flush_event);
    assign fetch_wait_pct_next = advance_percent_x100(fetch_wait_pct_accum,
                                                      fetch_wait_pct_remainder,
                                                      fetch_wait_event);
    assign memory_wait_pct_next = advance_percent_x100(memory_wait_pct_accum,
                                                       memory_wait_pct_remainder,
                                                       memory_wait_event);
    assign branch_jump_count_next = branch_jump_event
                                  ? ((branch_jump_count_accum == 16'd9999)
                                     ? 16'd0
                                     : branch_jump_count_accum + 16'd1)
                                  : branch_jump_count_accum;

    always_comb begin
        cpi_div_remainder_next = cpi_div_remainder_candidate[13:0];
        cpi_div_quotient_next = cpi_div_quotient;

        if (cpi_div_remainder_candidate >= {1'b0, cpi_div_denominator}) begin
            cpi_div_remainder_next = cpi_div_subtract_result[13:0];
            cpi_div_quotient_next[cpi_div_bit] = 1'b1;
        end
    end

    always_ff @(posedge cpu_clk) begin
        if (cpu_reset) begin
            cycle_counter              <= 32'd0;
            retired_counter            <= 32'd0;
            last_retired_count         <= 32'd0;
            retired_million_remainder  <= '0;
            mips_accumulator           <= 16'd0;
            mips_value                 <= 16'd0;
            measurement_window_seen    <= 1'b0;
            measurement_rollover       <= 1'b0;
            cpi_div_active             <= 1'b0;
            cpi_div_bit                <= 4'd0;
            cpi_div_numerator          <= 14'd0;
            cpi_div_denominator        <= 14'd1;
            cpi_div_remainder          <= 14'd0;
            cpi_div_quotient           <= 14'd0;
            cpi_x100_value             <= 14'd0;
            sample_load_use_stall_cycles         <= 32'd0;
            sample_control_hazard_flush_cycles   <= 32'd0;
            sample_instruction_fetch_wait_cycles <= 32'd0;
            sample_memory_wait_cycles            <= 32'd0;
            sample_taken_branches                <= 32'd0;
            sample_not_taken_branches            <= 32'd0;
            sample_jumps                         <= 32'd0;
            load_use_pct_accum                   <= 16'd0;
            control_flush_pct_accum              <= 16'd0;
            fetch_wait_pct_accum                 <= 16'd0;
            memory_wait_pct_accum                <= 16'd0;
            branch_jump_count_accum              <= 16'd0;
            load_use_pct_remainder               <= 14'd0;
            control_flush_pct_remainder          <= 14'd0;
            fetch_wait_pct_remainder             <= 14'd0;
            memory_wait_pct_remainder            <= 14'd0;
            load_use_pct_x100_value              <= 16'd0;
            control_flush_pct_x100_value         <= 16'd0;
            fetch_wait_pct_x100_value            <= 16'd0;
            memory_wait_pct_x100_value           <= 16'd0;
            branch_jump_count_value              <= 16'd0;
        end else if (cpu_enable) begin
            measurement_rollover <= 1'b0;
            if (cycle_counter == CPU_CLOCK_HZ - 1) begin
                cycle_counter             <= 32'd0;
                last_retired_count        <= retired_counter_next;
                retired_counter           <= 32'd0;
                retired_million_remainder <= '0;
                mips_accumulator          <= 16'd0;
                mips_value                <= mips_accumulator_next;
                measurement_window_seen   <= 1'b1;
                measurement_rollover      <= 1'b1;

                if (mips_accumulator_next != 16'd0) begin
                    cpi_div_active      <= 1'b1;
                    cpi_div_bit         <= 4'd13;
                    cpi_div_numerator   <= (CPU_CLOCK_HZ / 10_000) + {1'b0, mips_accumulator_next[13:1]};
                    cpi_div_denominator <= mips_accumulator_next[13:0];
                    cpi_div_remainder   <= 14'd0;
                    cpi_div_quotient    <= 14'd0;
                end else begin
                    cpi_div_active <= 1'b0;
                    cpi_x100_value <= 14'd0;
                end

                load_use_pct_x100_value      <= load_use_pct_next[29:14];
                control_flush_pct_x100_value <= control_flush_pct_next[29:14];
                fetch_wait_pct_x100_value    <= fetch_wait_pct_next[29:14];
                memory_wait_pct_x100_value   <= memory_wait_pct_next[29:14];
                branch_jump_count_value      <= branch_jump_count_next;

                load_use_pct_accum          <= 16'd0;
                control_flush_pct_accum     <= 16'd0;
                fetch_wait_pct_accum        <= 16'd0;
                memory_wait_pct_accum       <= 16'd0;
                branch_jump_count_accum     <= 16'd0;
                load_use_pct_remainder      <= 14'd0;
                control_flush_pct_remainder <= 14'd0;
                fetch_wait_pct_remainder    <= 14'd0;
                memory_wait_pct_remainder   <= 14'd0;

                sample_load_use_stall_cycles         <= load_use_stall_cycles;
                sample_control_hazard_flush_cycles   <= control_hazard_flush_cycles;
                sample_instruction_fetch_wait_cycles <= instruction_fetch_wait_cycles;
                sample_memory_wait_cycles            <= memory_wait_cycles;
                sample_taken_branches                <= taken_branches;
                sample_not_taken_branches            <= not_taken_branches;
                sample_jumps                         <= jumps;
            end else begin
                cycle_counter             <= cycle_counter + 32'd1;
                retired_counter           <= retired_counter_next;
                retired_million_remainder <= retired_million_remainder_next;
                mips_accumulator          <= mips_accumulator_next;
                load_use_pct_accum        <= load_use_pct_next[29:14];
                load_use_pct_remainder    <= load_use_pct_next[13:0];
                control_flush_pct_accum   <= control_flush_pct_next[29:14];
                control_flush_pct_remainder <= control_flush_pct_next[13:0];
                fetch_wait_pct_accum      <= fetch_wait_pct_next[29:14];
                fetch_wait_pct_remainder  <= fetch_wait_pct_next[13:0];
                memory_wait_pct_accum     <= memory_wait_pct_next[29:14];
                memory_wait_pct_remainder <= memory_wait_pct_next[13:0];
                branch_jump_count_accum   <= branch_jump_count_next;

                sample_load_use_stall_cycles         <= load_use_stall_cycles;
                sample_control_hazard_flush_cycles   <= control_hazard_flush_cycles;
                sample_instruction_fetch_wait_cycles <= instruction_fetch_wait_cycles;
                sample_memory_wait_cycles            <= memory_wait_cycles;
                sample_taken_branches                <= taken_branches;
                sample_not_taken_branches            <= not_taken_branches;
                sample_jumps                         <= jumps;

                if (cpi_div_active) begin
                    cpi_div_remainder <= cpi_div_remainder_next;
                    cpi_div_quotient  <= cpi_div_quotient_next;

                    if (cpi_div_bit == 4'd0) begin
                        cpi_div_active <= 1'b0;
                        cpi_x100_value <= cpi_div_quotient_next;
                    end else begin
                        cpi_div_bit <= cpi_div_bit - 4'd1;
                    end
                end
            end
        end else begin
            measurement_rollover <= 1'b0;
        end
    end

    always_ff @(posedge cpu_clk) begin
        if (cpu_reset) begin
            redirect_seen  <= 1'b0;
            retire_seen    <= 1'b0;
            reg_write_seen <= 1'b0;
            mem_write_seen <= 1'b0;
        end else begin
            if (pc_redirect) redirect_seen <= 1'b1;
            if (retire_valid) retire_seen <= 1'b1;
            if (reg_write) reg_write_seen <= 1'b1;
            if (mem_write) mem_write_seen <= 1'b1;
        end
    end

    always_ff @(posedge cpu_clk) begin
        if (cpu_reset) begin
            refresh_counter <= 17'd0;
        end else begin
            refresh_counter <= refresh_counter + 17'd1;
        end
    end

    cpu_core_pipeline_forwardtiming_phase22 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(cpu_clk),
        .rst(cpu_reset),
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

    always_comb begin
        unique case (display_mode)
            3'b000: display_value = mips_value;
            3'b001: display_value = {2'd0, cpi_x100_value};
            3'b010: display_value = load_use_pct_x100_value;
            3'b011: display_value = control_flush_pct_x100_value;
            3'b100: display_value = fetch_wait_pct_x100_value;
            3'b101: display_value = memory_wait_pct_x100_value;
            3'b110: display_value = CLOCK_DEBUG_MHZ[15:0];
            default: display_value = mips_value;
        endcase
    end

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
        // led[0]     = MMCM locked
        // led[1]     = synchronized CPU run enable
        // led[2]     = sticky measurement window completed
        // led[3]     = CPU reset active
        // led[7:4]   = decoded opcode
        // led[8]     = IF/ID valid
        // led[9]     = sticky retire observed
        // led[10]    = sticky register write observed
        // led[11]    = sticky memory write observed
        // led[12]    = sticky redirect observed
        // led[15:13] = pipeline stage valid bits {ID/EX, EX/MEM, MEM/WB}
        led[0]     = mmcm_locked;
        led[1]     = cpu_enable;
        led[2]     = measurement_window_seen;
        led[3]     = cpu_reset;
        led[7:4]   = decoded_opcode;
        led[8]     = if_id_valid;
        led[9]     = retire_seen;
        led[10]    = reg_write_seen;
        led[11]    = mem_write_seen;
        led[12]    = redirect_seen;
        led[15:13] = {id_ex_valid, ex_mem_valid, mem_wb_valid};
    end

endmodule
