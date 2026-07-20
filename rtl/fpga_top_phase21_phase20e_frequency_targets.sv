module fpga_top_phase21_phase20e_119p5 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(119_500_000),
        .CLOCK_DEBUG_MHZ(120),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(29.875),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase21_phase20e_120p0 (
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

module fpga_top_phase21_phase20e_120p5 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(120_500_000),
        .CLOCK_DEBUG_MHZ(121),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(30.125),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule

module fpga_top_phase21_phase20e_121p0 (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [3:0]  sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_phase19a_forwardtiming_mmcm_mips #(
        .CPU_CLOCK_HZ(121_000_000),
        .CLOCK_DEBUG_MHZ(121),
        .MMCM_DIVCLK_DIVIDE(4),
        .MMCM_CLKFBOUT_MULT_F(30.250),
        .MMCM_CLKOUT0_DIVIDE_F(6.250)
    ) impl (.*);
endmodule
