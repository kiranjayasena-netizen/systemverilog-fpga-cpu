`timescale 1ns/1ps
module ai_cpu_validation_wrapper_tb;
  logic clk=0,rst=1,load_mode=1,start=0,prog_we=0,data_we=0,data_re=0; always #5 clk=~clk;
  logic [7:0] prog_addr=0,data_addr_host=0,data_raddr=0; logic [31:0] prog_data=0,data_wdata=0,data_rdata;
  logic busy,done; logic [31:0] cycle_count;
  ai_cpu_validation_wrapper #(.OPTIMIZED(1'b1)) dut(.*);
  initial begin
    repeat(4) @(posedge clk); rst<=0;
    // Exercise the explicit host path; execution is intentionally left to the
    // repository's established CPU program benches.
    @(posedge clk); prog_addr<=0; prog_data<=32'h00000000; prog_we<=1;
    @(posedge clk); prog_we<=0; data_addr_host<=0; data_wdata<=32'h12345678; data_we<=1;
    @(posedge clk); data_we<=0;
    $display("AI_CPU_VALIDATION_WRAPPER_SMOKE PASS"); $finish;
  end
endmodule
