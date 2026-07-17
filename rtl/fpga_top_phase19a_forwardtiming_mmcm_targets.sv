module fpga_top_phase19a_forwardtiming_mmcm_115p5 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(115_500_000),
        .CLOCK_DEBUG_MHZ(116),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(28.875),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase19a_forwardtiming_mmcm_116p0 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(116_000_000),
        .CLOCK_DEBUG_MHZ(116),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.000),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase19a_forwardtiming_mmcm_116p5 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(116_500_000),
        .CLOCK_DEBUG_MHZ(117),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.125),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase19a_forwardtiming_mmcm_117p0 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(117_000_000),
        .CLOCK_DEBUG_MHZ(117),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.250),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule
