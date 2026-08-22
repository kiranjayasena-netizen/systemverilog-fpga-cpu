module uart_rx #(parameter integer CLKS_PER_BIT=694) (
  input logic clk,input logic rst,input logic rx,
  output logic valid,output logic [7:0] data
);
  logic busy; integer count; logic [3:0] bit_idx; logic [7:0] shift;
  always_ff @(posedge clk) begin
    valid<=0;
    if(rst) begin busy<=0; count<=0; bit_idx<=0; shift<=0; data<=0; end
    else if(!busy) begin if(!rx) begin busy<=1; count<=CLKS_PER_BIT/2; bit_idx<=0; end end
    else if(count!=0) count<=count-1;
    else begin count<=CLKS_PER_BIT-1; if(bit_idx<8) begin shift[bit_idx]<=rx; bit_idx<=bit_idx+1'b1; end else begin busy<=0; data<=shift; valid<=1; end end
  end
endmodule
