module uart_tx #(parameter integer CLKS_PER_BIT=694) (
  input logic clk,input logic rst,input logic start,input logic [7:0] data,
  output logic tx,output logic busy
);
  logic [9:0] frame; integer count; logic [3:0] bit_idx;
  always_ff @(posedge clk) begin
    if(rst) begin tx<=1; busy<=0; frame<=0; count<=0; bit_idx<=0; end
    else if(!busy) begin tx<=1; if(start) begin frame<={1'b1,data,1'b0}; busy<=1; bit_idx<=0; count<=CLKS_PER_BIT-1; tx<=0; end end
    else if(count!=0) count<=count-1;
    else begin bit_idx<=bit_idx+1'b1; count<=CLKS_PER_BIT-1; if(bit_idx==9) begin busy<=0; tx<=1; end else tx<=frame[bit_idx+1]; end
  end
endmodule
