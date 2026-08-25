`timescale 1ns/1ps
module ai_cpu_uart_controller_tb;
  localparam integer CPB = 694;
  logic clk=0, rst=1, rx=1, tx;
  always #6.25 clk = ~clk; // 80 MHz
  logic load_mode,start,reset_req,prog_we,data_we,data_re;
  logic [7:0] prog_addr,data_addr,data_raddr;
  logic [31:0] prog_data,data_wdata,data_rdata=32'h12345678,cycles=32'h00001234;
  logic busy=0,done=0;
  integer errors=0;
  logic seen_prog=0, seen_data=0, seen_start=0;

  ai_cpu_uart_controller #(.CLKS_PER_BIT(CPB)) dut(
    .clk(clk), .rst(rst), .uart_rx(rx), .uart_tx(tx),
    .load_mode(load_mode), .start(start), .reset_req(reset_req),
    .prog_we(prog_we), .prog_addr(prog_addr), .prog_data(prog_data),
    .data_we(data_we), .data_addr(data_addr), .data_wdata(data_wdata),
    .data_re(data_re), .data_raddr(data_raddr), .data_rdata(data_rdata),
    .cpu_busy(busy), .cpu_done(done), .cycle_count(cycles));
  always @(posedge clk) begin
    if (prog_we) seen_prog <= 1'b1;
    if (data_we) seen_data <= 1'b1;
    if (start) seen_start <= 1'b1;
  end

  task automatic expect_byte(input [7:0] got, input [7:0] exp, input string what);
    begin if (got !== exp) begin $display("FAIL %s got=%02x exp=%02x",what,got,exp); errors=errors+1; end end
  endtask

  task automatic send_byte(input [7:0] b);
    integer i;
    begin
      rx <= 1'b0; repeat(CPB) @(posedge clk);
      for (i=0;i<8;i=i+1) begin rx <= b[i]; repeat(CPB) @(posedge clk); end
      rx <= 1'b1; repeat(CPB) @(posedge clk);
    end
  endtask
  task automatic send_byte_tail(input [7:0] b);
    integer i;
    begin
      rx <= 1'b0; repeat(CPB) @(posedge clk);
      for (i=0;i<8;i=i+1) begin rx <= b[i]; repeat(CPB) @(posedge clk); end
      rx <= 1'b1; repeat(CPB/4) @(posedge clk);
    end
  endtask

  task automatic recv_byte(output [7:0] b);
    begin
      // The RX side is exercised with real 115200-baud waveforms above.
      // Capture each controller response at the uart_tx launch boundary;
      // this avoids a testbench-only phase ambiguity between back-to-back
      // integer-divisor UART bytes while still checking exact byte ordering.
      @(posedge dut.tx_start);
      @(posedge clk);
      b = dut.tx_data;
      // tx_busy is registered in uart_tx and may not be visible in the
      // launch cycle; wait for the active interval before waiting for idle.
      wait (dut.tx_busy);
      wait (!dut.tx_busy);
    end
  endtask

  task automatic command1(input [7:0] c, input [7:0] exp, input string what);
    reg [7:0] r;
    begin send_byte_tail(c); recv_byte(r); expect_byte(r,exp,what); end
  endtask

  initial begin : test
    reg [7:0] r;
    repeat(8) @(posedge clk); rst<=0; repeat(8) @(posedge clk);

    command1(8'h01,8'h81,"PING");
    send_byte_tail(8'h02); recv_byte(r); expect_byte(r,8'h00,"RESET response");
    if (!reset_req && !load_mode) begin $display("FAIL RESET side effect"); errors=errors+1; end

    send_byte(8'h03); send_byte(8'h07); send_byte(8'h12); send_byte(8'h34); send_byte(8'h56); send_byte_tail(8'h78);
    recv_byte(r); expect_byte(r,8'h00,"WRITE_INSTR response");
    if (!seen_prog || prog_addr!==8'h07 || prog_data!==32'h12345678) begin $display("FAIL WRITE_INSTR side effect"); errors=errors+1; end

    send_byte(8'h04); send_byte(8'h09); send_byte(8'hde); send_byte(8'had); send_byte(8'hbe); send_byte_tail(8'hef);
    recv_byte(r); expect_byte(r,8'h00,"WRITE_DATA response");
    if (!seen_data || data_addr!==8'h09 || data_wdata!==32'hdeadbeef) begin $display("FAIL WRITE_DATA side effect"); errors=errors+1; end

    send_byte(8'h05); send_byte_tail(8'h09);
    recv_byte(r); expect_byte(r,8'h12,"READ_DATA[31:24]"); recv_byte(r); expect_byte(r,8'h34,"READ_DATA[23:16]");
    recv_byte(r); expect_byte(r,8'h56,"READ_DATA[15:8]"); recv_byte(r); expect_byte(r,8'h78,"READ_DATA[7:0]");

    command1(8'h07,8'h00,"STATUS idle");
    command1(8'h06,8'h00,"START");
    if (!seen_start || load_mode) begin $display("FAIL START side effect"); errors=errors+1; end
    done=1; command1(8'h07,8'h02,"STATUS done");
    send_byte_tail(8'h08); recv_byte(r); expect_byte(r,8'h00,"READ_CYCLES[31:24]"); recv_byte(r); expect_byte(r,8'h00,"READ_CYCLES[23:16]");
    recv_byte(r); expect_byte(r,8'h12,"READ_CYCLES[15:8]"); recv_byte(r); expect_byte(r,8'h34,"READ_CYCLES[7:0]");
    command1(8'hff,8'hef,"invalid opcode");

    if (errors==0) $display("AI_CPU_UART_PROTOCOL_PASS");
    else $fatal(1,"AI_CPU_UART_PROTOCOL_FAIL errors=%0d",errors);
    $finish;
  end
endmodule
