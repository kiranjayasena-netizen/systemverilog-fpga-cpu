`timescale 1ns/1ps
module uart_rx_tb;
  localparam integer CLKS_PER_BIT = 694;
  logic clk = 1'b0, rst = 1'b1, rx = 1'b1;
  logic valid; logic [7:0] data;
  integer valid_count;
  uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut(.*);
  always #5 clk = ~clk;

  task automatic send_byte(input logic [7:0] b);
    integer i;
    begin
      rx <= 1'b0; repeat (CLKS_PER_BIT) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin
        rx <= b[i]; repeat (CLKS_PER_BIT) @(posedge clk);
      end
      rx <= 1'b1; repeat (CLKS_PER_BIT) @(posedge clk);
    end
  endtask

  task automatic check_byte(input logic [7:0] b);
    begin
      valid_count = 0; send_byte(b); repeat (CLKS_PER_BIT/2) @(posedge clk);
      if (valid_count != 1 || data !== b) $fatal(1, "RX mismatch byte=%02h data=%02h valid_count=%0d", b, data, valid_count);
    end
  endtask

  always @(posedge clk) if (valid) valid_count = valid_count + 1;

  initial begin
    repeat (4) @(posedge clk); rst <= 1'b0;
    check_byte(8'h00); check_byte(8'h01); check_byte(8'h02);
    check_byte(8'h07); check_byte(8'h55); check_byte(8'hAA);
    check_byte(8'h81); check_byte(8'hE0); check_byte(8'hFF);
    // False start shorter than half a bit must not emit valid.
    rx <= 1'b0; repeat (CLKS_PER_BIT/4) @(posedge clk); rx <= 1'b1;
    repeat (CLKS_PER_BIT) @(posedge clk);
    if (valid) $fatal(1, "false start produced valid");
    // Bad stop bit must not emit valid.
    rx <= 1'b0; repeat (CLKS_PER_BIT) @(posedge clk);
    repeat (8) begin rx <= 1'b1; repeat (CLKS_PER_BIT) @(posedge clk); end
    rx <= 1'b0; repeat (CLKS_PER_BIT) @(posedge clk); rx <= 1'b1;
    repeat (CLKS_PER_BIT) @(posedge clk);
    if (valid) $fatal(1, "bad stop produced valid");
    $display("UART_RX_TEST 9/9 PASS");
    $finish;
  end
endmodule
