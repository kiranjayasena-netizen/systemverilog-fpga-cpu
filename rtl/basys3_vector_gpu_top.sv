module basys3_vector_gpu_top (
  input logic clk,input logic rst_btn,input logic uart_rx,
  output logic uart_tx,output logic [15:0] led
);
  logic clkfb,clk80,locked; logic gpu_rst, gpu_start, gpu_busy, gpu_done, gpu_clk;
  logic pwe,dwe,dre; logic [3:0] pa; logic [15:0] pd; logic [4:0] da,ra,plen; logic [127:0] dd,rd;
  logic [31:0] cycles,req,hit,ar,aph; logic [24:0] heartbeat;
  MMCME2_BASE #(.CLKIN1_PERIOD(10.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(8.0),.CLKOUT0_DIVIDE_F(10.0)) mmcm(.CLKIN1(clk),.CLKFBIN(clkfb),.RST(rst_btn),.PWRDWN(1'b0),.CLKFBOUT(clkfb),.CLKOUT0(clk80),.LOCKED(locked));
  BUFG gpu_bufg(.I(clk80),.O(gpu_clk));
  vector_gpu_uart_controller #(.CLKS_PER_BIT(694)) ctl(.clk(gpu_clk),.rst(rst_btn||!locked),.uart_rx(uart_rx),.gpu_busy(gpu_busy),.gpu_done(gpu_done),.uart_tx(uart_tx),.gpu_start(gpu_start),.gpu_reset(gpu_rst),.prog_write_enable(pwe),.prog_write_addr(pa),.prog_write_data(pd),.data_write_enable(dwe),.data_write_addr(da),.data_write_data(dd),.program_length(plen),.data_read_enable(dre),.data_read_addr(ra),.data_read_data(rd));
  (* DONT_TOUCH = "yes" *) vector_gpu_accelerator gpu(.clk(gpu_clk),.rst(rst_btn|gpu_rst),.start(gpu_start),.program_length(plen),.prog_write_enable(pwe),.prog_write_addr(pa),.prog_write_data(pd),.data_write_enable(dwe),.data_write_addr(da),.data_write_data(dd),.data_read_enable(dre),.data_read_addr(ra),.data_read_data(rd),.reg_read_enable(1'b0),.reg_read_addr(3'b0),.reg_read_data(),.busy(gpu_busy),.done(gpu_done),.cycle_count(cycles),.prefetch_request_count(req),.prefetch_hit_count(hit),.alu_read_overlap_count(ar),.alu_prefetch_hit_count(aph));
  always_ff @(posedge gpu_clk) begin if(rst_btn) heartbeat<=0; else heartbeat<=heartbeat+1'b1; end
  always_comb begin led='0; led[0]=gpu_busy; led[1]=gpu_done; led[2]=locked; led[15]=heartbeat[24]; end
endmodule
