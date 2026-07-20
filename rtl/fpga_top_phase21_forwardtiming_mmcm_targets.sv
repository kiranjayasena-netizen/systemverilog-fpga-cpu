module fpga_top_phase21_forwardtiming_mmcm_115 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase21_forwardtiming_mmcm_benchmark #(
        .CPU_CLOCK_HZ(115_000_000),
        .CLOCK_DEBUG_MHZ(115),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(28.750),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase21_forwardtiming_mmcm_117 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase21_forwardtiming_mmcm_benchmark #(
        .CPU_CLOCK_HZ(117_000_000),
        .CLOCK_DEBUG_MHZ(117),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.250),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase21_forwardtiming_mmcm_118 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase21_forwardtiming_mmcm_benchmark #(
        .CPU_CLOCK_HZ(118_000_000),
        .CLOCK_DEBUG_MHZ(118),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.500),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase21_forwardtiming_mmcm_119 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase21_forwardtiming_mmcm_benchmark #(
        .CPU_CLOCK_HZ(119_000_000),
        .CLOCK_DEBUG_MHZ(119),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.750),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase21_forwardtiming_mmcm_120 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase21_forwardtiming_mmcm_benchmark #(
        .CPU_CLOCK_HZ(120_000_000),
        .CLOCK_DEBUG_MHZ(120),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(30.000),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule
