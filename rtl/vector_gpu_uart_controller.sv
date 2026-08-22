module vector_gpu_uart_controller #(parameter integer CLKS_PER_BIT=694) (
  input logic clk,input logic rst,input logic uart_rx,input logic gpu_busy,input logic gpu_done,
  output logic uart_tx,output logic gpu_start,output logic gpu_reset,
  output logic prog_write_enable,output logic [3:0] prog_write_addr,output logic [15:0] prog_write_data,
  output logic data_write_enable,output logic [4:0] data_write_addr,output logic [127:0] data_write_data,
  output logic [4:0] program_length
);
  logic rx_valid; logic [7:0] rx_data; logic tx_start,tx_busy; logic [7:0] tx_data;
  uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx(.clk(clk),.rst(rst),.rx(uart_rx),.valid(rx_valid),.data(rx_data));
  uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx(.clk(clk),.rst(rst),.start(tx_start),.data(tx_data),.tx(uart_tx),.busy(tx_busy));
  typedef enum logic [3:0] {IDLE,PI_ADDR,PI_HI,PI_LO,PLEN,DM_ADDR,DM_BYTE,START_CMD} st_t; st_t state;
  logic [3:0] iaddr; logic [7:0] mem_byte; logic [4:0] byte_count; logic [127:0] mem_shift;
  always_ff @(posedge clk) begin
    prog_write_enable<=0; data_write_enable<=0; gpu_start<=0; gpu_reset<=0; tx_start<=0;
    if(rst) begin state<=IDLE; program_length<=0; iaddr<=0; prog_write_data<=0; data_write_addr<=0; data_write_data<=0; byte_count<=0; mem_shift<=0; end
    else if(rx_valid) begin
      case(state)
        IDLE: case(rx_data)
          8'h01: if(!tx_busy) begin tx_data<=8'h81;tx_start<=1;end // PING
          8'h02: gpu_reset<=1;
          8'h03: state<=PI_ADDR; // WRITE_INSTR: addr, hi, lo
          8'h04: state<=PLEN;
          8'h05: state<=DM_ADDR; // WRITE_MEMORY: addr + 16 LSB-first bytes
          8'h06: gpu_start<=!gpu_busy;
          8'h07: if(!tx_busy) begin tx_data<={6'b0,gpu_done,gpu_busy};tx_start<=1;end
          default: if(!tx_busy) begin tx_data<=8'he0;tx_start<=1;end
        endcase
        PI_ADDR: begin iaddr<=rx_data[3:0];state<=PI_HI;end
        PI_HI: begin prog_write_data[15:8]<=rx_data;state<=PI_LO;end
        PI_LO: begin prog_write_data[7:0]<=rx_data;prog_write_addr<=iaddr;prog_write_enable<=1;state<=IDLE;end
        PLEN: begin program_length<=rx_data[4:0];state<=IDLE;end
        DM_ADDR: begin data_write_addr<=rx_data[4:0];byte_count<=0;mem_shift<=0;state<=DM_BYTE;end
        DM_BYTE: begin mem_shift[byte_count*8 +: 8]<=rx_data; if(byte_count==15) begin data_write_data<={rx_data,mem_shift[127:8]};data_write_enable<=1;state<=IDLE;end else byte_count<=byte_count+1'b1;end
        default: state<=IDLE;
      endcase
    end
  end
endmodule
