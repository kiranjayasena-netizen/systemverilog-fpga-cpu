module fpga_top_phase20_phase19a_117p5 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(117_500_000),
        .CLOCK_DEBUG_MHZ(118),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.375),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase20_phase19a_118p0 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(118_000_000),
        .CLOCK_DEBUG_MHZ(118),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.500),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase20_phase19a_118p5 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(118_500_000),
        .CLOCK_DEBUG_MHZ(119),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.625),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase20_phase19a_119p0 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(119_000_000),
        .CLOCK_DEBUG_MHZ(119),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.750),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase20_phase19a_120p0 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(120_000_000),
        .CLOCK_DEBUG_MHZ(120),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(30.000),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule
