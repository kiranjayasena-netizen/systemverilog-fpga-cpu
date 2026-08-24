`timescale 1ns/1ps
module uart_tx_tb;
  localparam integer CLKS_PER_BIT = 8;
  logic clk = 1'b0, rst = 1'b1, start = 1'b0;
  logic [7:0] data = 0; logic tx, busy;
  uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut(.*);
  always #5 clk = ~clk;
  task automatic check_byte(input logic [7:0] b);
    integer i;
    begin
      @(posedge clk); data <= b; start <= 1'b1; @(posedge clk); start <= 1'b0;
      repeat (CLKS_PER_BIT/2) @(posedge clk);
      if (tx !== 1'b0) $fatal(1, "TX start error %02h", b);
      for (i=0;i<8;i=i+1) begin repeat (CLKS_PER_BIT) @(posedge clk); if (tx !== b[i]) $fatal(1,"TX bit error %02h bit %0d",b,i); end
      repeat (CLKS_PER_BIT) @(posedge clk); if (tx !== 1'b1) $fatal(1,"TX stop error %02h",b);
      repeat (CLKS_PER_BIT) @(posedge clk);
    end
  endtask
  initial begin
    repeat(3) @(posedge clk); rst<=0;
    check_byte(8'h00); check_byte(8'h01); check_byte(8'h55); check_byte(8'h81); check_byte(8'hFF);
    $display("UART_TX_TEST 5/5 PASS"); $finish;
  end
endmodule
