module fpga_top_phase18_forwardtiming_mmcm_benchmark #(
    parameter int unsigned IMEM_DEPTH     = 256,
    parameter int unsigned DMEM_DEPTH     = 256,
    parameter int unsigned CPU_CLOCK_HZ   = 115_000_000,
    parameter int unsigned MIPS_DIVISOR   = 1_000_000,
    parameter string       IMEM_INIT_FILE = "programs/final_benchmark.mem"
) (
    input  logic       clk,
    input  logic       rst_btn,
    input  logic [3:0] sw,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        dp
);
    fpga_top_pipeline_forwardtiming_mmcm_mips #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .CPU_CLOCK_HZ(CPU_CLOCK_HZ),
        .MIPS_DIVISOR(MIPS_DIVISOR),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) phase17e_counter_wrapper (
        .clk(clk),
        .rst_btn(rst_btn),
        .sw(sw),
        .led(led),
        .seg(seg),
        .an(an),
        .dp(dp)
    );
endmodule
