`timescale 1ns/1ps
module vector_gpu_uart_readback_tb;
  localparam integer CPB=4;
  logic clk=0,rst=1,rx=1,tx,gpu_busy=0,gpu_done=0;
  logic gpu_start,gpu_reset,pwe,dwe,dre; logic [3:0] pa; logic [15:0] pd;
  logic [4:0] da,ra,plen; logic [127:0] dd,rd; logic [127:0] mem[0:31];
  vector_gpu_uart_controller #(.CLKS_PER_BIT(CPB)) dut(.clk(clk),.rst(rst),.uart_rx(rx),.gpu_busy(gpu_busy),.gpu_done(gpu_done),.uart_tx(tx),.gpu_start(gpu_start),.gpu_reset(gpu_reset),.prog_write_enable(pwe),.prog_write_addr(pa),.prog_write_data(pd),.data_write_enable(dwe),.data_write_addr(da),.data_write_data(dd),.program_length(plen),.data_read_enable(dre),.data_read_addr(ra),.data_read_data(rd));
  always #5 clk=~clk;
  always_ff @(posedge clk) if (dre) rd <= mem[ra];
  task automatic send_byte(input logic [7:0] b); integer i; begin rx<=0;repeat(CPB)@(posedge clk);for(i=0;i<8;i=i+1)begin rx<=b[i];repeat(CPB)@(posedge clk);end rx<=1;repeat(CPB)@(posedge clk);end endtask
  task automatic recv_byte(output logic [7:0] b); integer i; begin b=0; wait(tx===0);repeat(CPB+CPB/2)@(posedge clk);for(i=0;i<8;i=i+1)begin b[i]=tx;repeat(CPB)@(posedge clk);end repeat(CPB)@(posedge clk);end endtask
  task automatic check(input integer a); integer i; logic [7:0] b; logic [127:0] got; begin send_byte(8'h08);send_byte(a[7:0]);got=0;for(i=0;i<16;i=i+1)begin recv_byte(b);got[i*8 +: 8]=b;end if(got!==mem[a])$fatal(1,"readback addr %0d exp=%032h got=%032h",a,mem[a],got);$display("READBACK %0d PASS",a);end endtask
  initial begin integer i; for(i=0;i<32;i=i+1)mem[i]=i*128'h01010101010101010101010101010101; mem[0]=128'h0;mem[1]=128'hffffffffffffffffffffffffffffffff;mem[15]=128'h112233445566778899aabbccddeeff00;mem[31]=128'h0123456789abcdeffedcba9876543210; repeat(3)@(posedge clk);rst<=0;check(0);check(1);check(15);check(31);$display("UART_READBACK_TEST 4/4 PASS");$finish;end
endmodule
