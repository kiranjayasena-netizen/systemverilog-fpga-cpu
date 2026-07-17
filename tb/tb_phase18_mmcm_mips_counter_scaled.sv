`timescale 1ns/1ps

module phase18_mips_counter_scaled_model #(
    parameter int unsigned CPU_CLOCK_HZ = 1150,
    parameter int unsigned MIPS_DIVISOR = 10
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       run_enable,
    input  logic       retire_valid,
    input  logic [2:0] display_mode,
    output logic [15:0] display_value,
    output logic [15:0] mips_value,
    output logic [15:0] cpi_x100_value,
    output logic [15:0] clock_debug_value
);
    logic [31:0] cycle_counter;
    logic [31:0] retired_counter;
    logic [31:0] last_retired_count;

    assign clock_debug_value = 16'd115;

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_counter      <= 32'd0;
            retired_counter    <= 32'd0;
            last_retired_count <= 32'd0;
            mips_value         <= 16'd0;
            cpi_x100_value     <= 16'd0;
        end else if (run_enable) begin
            if (retire_valid) begin
                retired_counter <= retired_counter + 32'd1;
            end

            if (cycle_counter == CPU_CLOCK_HZ - 1) begin
                cycle_counter      <= 32'd0;
                last_retired_count <= retired_counter;
                mips_value         <= retired_counter[15:0] / MIPS_DIVISOR[15:0];
                cpi_x100_value     <= (retired_counter == 0) ? 16'd0 :
                                      ((CPU_CLOCK_HZ * 100) / retired_counter[15:0]);
                retired_counter    <= 32'd0;
            end else begin
                cycle_counter <= cycle_counter + 32'd1;
            end
        end
    end

    always_comb begin
        unique case (display_mode)
            3'b000: display_value = mips_value;
            3'b001: display_value = cpi_x100_value;
            3'b110: display_value = clock_debug_value;
            default: display_value = last_retired_count[15:0];
        endcase
    end
endmodule

module tb_phase18_mmcm_mips_counter_scaled;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic run_enable = 1'b0;
    logic retire_valid = 1'b0;
    logic [2:0] display_mode = 3'b000;
    logic [15:0] display_value;
    logic [15:0] mips_value;
    logic [15:0] cpi_x100_value;
    logic [15:0] clock_debug_value;

    always #5 clk = ~clk;

    phase18_mips_counter_scaled_model dut (
        .clk(clk),
        .rst(rst),
        .run_enable(run_enable),
        .retire_valid(retire_valid),
        .display_mode(display_mode),
        .display_value(display_value),
        .mips_value(mips_value),
        .cpi_x100_value(cpi_x100_value),
        .clock_debug_value(clock_debug_value)
    );

    task automatic run_window(input int unsigned retire_cycles);
        for (int unsigned i = 0; i < 1150; i++) begin
            retire_valid = (i < retire_cycles);
            @(posedge clk);
        end
        retire_valid = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        run_enable = 1'b1;

        run_window(0);
        if (mips_value !== 16'd0 || cpi_x100_value !== 16'd0) begin
            $fatal(1, "Zero-retire window did not remain safely at zero: mips=%0d cpi=%0d",
                   mips_value, cpi_x100_value);
        end

        run_window(1000);

        display_mode = 3'b000;
        #1;
        if (display_value !== 16'd100) begin
            $fatal(1, "MIPS display mode expected 100, got %0d", display_value);
        end

        display_mode = 3'b001;
        #1;
        if (display_value !== 16'd115) begin
            $fatal(1, "CPI x100 display mode expected 115, got %0d", display_value);
        end

        display_mode = 3'b110;
        #1;
        if (display_value !== 16'd115) begin
            $fatal(1, "Clock debug mode expected 115, got %0d", display_value);
        end

        $display("PHASE 18 SCALED MIPS COUNTER TEST PASSED");
        $finish;
    end
endmodule
