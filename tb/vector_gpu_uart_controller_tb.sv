`timescale 1ns/1ps
module vector_gpu_uart_controller_tb;
  localparam integer CPB=8;
  logic clk=0,rst=1,rx=1,gpu_busy=0,gpu_done=0,tx;
  logic gpu_start,gpu_reset,prog_we,data_we; logic [3:0] prog_addr; logic [15:0] prog_data;
  logic [4:0] data_addr,program_length; logic [127:0] data_data;
  logic data_read_enable; logic [4:0] data_read_addr; logic [127:0] data_read_data=0;
  vector_gpu_uart_controller #(.CLKS_PER_BIT(CPB)) dut(
    .clk(clk), .rst(rst), .uart_rx(rx), .gpu_busy(gpu_busy), .gpu_done(gpu_done),
    .uart_tx(tx), .gpu_start(gpu_start), .gpu_reset(gpu_reset),
    .prog_write_enable(prog_we), .prog_write_addr(prog_addr), .prog_write_data(prog_data),
    .data_write_enable(data_we), .data_write_addr(data_addr), .data_write_data(data_data),
    .program_length(program_length), .data_read_enable(data_read_enable),
    .data_read_addr(data_read_addr), .data_read_data(data_read_data));
  always #5 clk=~clk;
  task automatic send_byte(input logic [7:0] b); integer i; begin rx<=0; repeat(CPB)@(posedge clk); for(i=0;i<8;i=i+1) begin rx<=b[i]; repeat(CPB)@(posedge clk); end rx<=1; repeat(CPB)@(posedge clk); end endtask
  task automatic sample_tx(output logic [7:0] b); integer i; begin b=0; wait(tx===0); repeat(CPB+CPB/2)@(posedge clk); for(i=0;i<8;i=i+1) begin b[i]=tx; repeat(CPB)@(posedge clk); end repeat(CPB)@(posedge clk); end endtask
  initial begin logic [7:0] got; repeat(3)@(posedge clk); rst<=0; fork send_byte(8'h01); join; sample_tx(got); if(got!==8'h81) $fatal(1,"controller ping got %02h",got); $display("UART_PING_SIM PASS"); $finish; end
endmodule
