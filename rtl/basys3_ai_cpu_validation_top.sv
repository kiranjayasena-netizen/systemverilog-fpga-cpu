module basys3_ai_cpu_validation_top #(
    parameter bit OPTIMIZED = 1'b0
) (
    input logic clk100, input logic rst_btn, input logic uart_rx,
    output logic uart_tx, output logic [15:0] led
);
    logic gpu_clk, locked;
    logic load_mode, start, reset_req;
    logic prog_we, data_we, data_re;
    logic [7:0] prog_addr, data_addr, data_raddr;
    logic [31:0] prog_data, data_wdata, data_rdata, cycles;
    logic busy, done;

    // The validation mux boundary is constrained at a common 80 MHz rate;
    // canonical CPU timing and architecture are unchanged.
    logic gpu_clk_fb, gpu_clk_mmcm;
    MMCME2_BASE #(.CLKIN1_PERIOD(10.0), .CLKFBOUT_MULT_F(8.0),
                  .DIVCLK_DIVIDE(1), .CLKOUT0_DIVIDE_F(10.0)) mmcm_i (
        .CLKIN1(clk100), .RST(rst_btn), .PWRDWN(1'b0), .CLKFBIN(gpu_clk_fb),
        .CLKOUT0(gpu_clk_mmcm), .CLKFBOUT(gpu_clk_fb), .LOCKED(locked));
    BUFG bufg_i(.I(gpu_clk_mmcm),.O(gpu_clk));

    ai_cpu_validation_wrapper #(.OPTIMIZED(OPTIMIZED)) cpu_i (
        .clk(gpu_clk), .rst(rst_btn | ~locked | reset_req), .load_mode(load_mode),
        .start(start), .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data),
        .data_we(data_we), .data_addr_host(data_addr), .data_wdata(data_wdata),
        .data_re(data_re), .data_raddr(data_raddr), .data_rdata(data_rdata),
        .busy(busy), .done(done), .cycle_count(cycles));

    ai_cpu_uart_controller uart_i (
        .clk(gpu_clk), .rst(rst_btn | ~locked), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .load_mode(load_mode), .start(start), .reset_req(reset_req),
        .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data),
        .data_we(data_we), .data_addr(data_addr), .data_wdata(data_wdata),
        .data_re(data_re), .data_raddr(data_raddr), .data_rdata(data_rdata),
        .cpu_busy(busy), .cpu_done(done), .cycle_count(cycles));

    logic heartbeat;
    always_ff @(posedge gpu_clk) begin
        if (rst_btn | ~locked) heartbeat <= 1'b0;
        else heartbeat <= ~heartbeat;
    end
    assign led = {heartbeat,12'b0,locked,done,busy};
endmodule

module basys3_ai_cpu_baseline_top(
    input logic clk100,input logic rst_btn,input logic uart_rx,
    output logic uart_tx,output logic [15:0] led);
    basys3_ai_cpu_validation_top #(.OPTIMIZED(1'b0)) i(.*);
endmodule

module basys3_ai_cpu_optimized_top(
    input logic clk100,input logic rst_btn,input logic uart_rx,
    output logic uart_tx,output logic [15:0] led);
    basys3_ai_cpu_validation_top #(.OPTIMIZED(1'b1)) i(.*);
endmodule
