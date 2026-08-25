// Small validation-only UART protocol.  Payload words are big-endian on the
// wire; memory addresses are one byte.  Writes are accepted only in load_mode.
module ai_cpu_uart_controller #(
    parameter integer CLKS_PER_BIT = 694
) (
    input logic clk, input logic rst, input logic uart_rx,
    output logic uart_tx,
    output logic load_mode, output logic start, output logic reset_req,
    output logic prog_we, output logic [7:0] prog_addr, output logic [31:0] prog_data,
    output logic data_we, output logic [7:0] data_addr, output logic [31:0] data_wdata,
    output logic data_re, output logic [7:0] data_raddr, input logic [31:0] data_rdata,
    input logic cpu_busy, input logic cpu_done, input logic [31:0] cycle_count
);
    logic rx_valid, tx_busy, tx_start;
    logic [7:0] rx_data, tx_data;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx_i(.clk(clk),.rst(rst),.rx(uart_rx),.valid(rx_valid),.data(rx_data));
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_i(.clk(clk),.rst(rst),.start(tx_start),.data(tx_data),.tx(uart_tx),.busy(tx_busy));

    typedef enum logic [4:0] {S_IDLE,S_IADDR,S_IDATA,S_DADDR,S_DDATA,S_RADDR,
                              S_RWAIT1,S_RWAIT,S_RESP} state_t;
    state_t state;
    logic [2:0] byte_idx;
    logic [7:0] addr_latch;
    logic [31:0] word_latch;
    logic [7:0] resp [0:15];
    logic [4:0] resp_len, resp_idx;
    logic tx_launch_wait;

    always_ff @(posedge clk) begin
        tx_start <= 1'b0; start <= 1'b0; reset_req <= 1'b0;
        prog_we <= 1'b0; data_we <= 1'b0; data_re <= 1'b0;
        if (rst) begin
            state <= S_IDLE; load_mode <= 1'b1; byte_idx <= 0;
            addr_latch <= 0; word_latch <= 0; resp_len <= 0; resp_idx <= 0;
            tx_launch_wait <= 1'b0;
            prog_addr <= 0; prog_data <= 0; data_addr <= 0; data_wdata <= 0;
            data_raddr <= 0; tx_data <= 0;
            for (integer ri = 0; ri < 16; ri = ri + 1) resp[ri] <= 8'h00;
        end else begin
            case (state)
                S_IDLE: if (rx_valid) begin
                    case (rx_data)
                        8'h01: begin resp[0]<=8'h81; resp_len<=1; resp_idx<=0; state<=S_RESP; end
                        8'h02: begin load_mode<=1'b1; reset_req<=1'b1; resp[0]<=0; resp_len<=1; resp_idx<=0; state<=S_RESP; end
                        8'h03: begin byte_idx<=0; state<=S_IADDR; end
                        8'h04: begin byte_idx<=0; state<=S_DADDR; end
                        8'h05: begin byte_idx<=0; state<=S_RADDR; end
                        8'h06: begin
                            if (cpu_busy) begin resp[0]<=8'hE1; end
                            else begin load_mode<=1'b0; start<=1'b1; resp[0]<=0; end
                            resp_len<=1; resp_idx<=0; state<=S_RESP;
                        end
                        8'h07: begin resp[0]<={6'b0,cpu_done,cpu_busy}; resp_len<=1; resp_idx<=0; state<=S_RESP; end
                        8'h08: begin
                            resp[0]<=cycle_count[31:24]; resp[1]<=cycle_count[23:16];
                            resp[2]<=cycle_count[15:8]; resp[3]<=cycle_count[7:0];
                            resp_len<=4; resp_idx<=0; state<=S_RESP;
                        end
                        default: begin resp[0]<=8'hEF; resp_len<=1; resp_idx<=0; state<=S_RESP; end
                    endcase
                end
                S_IADDR: if (rx_valid) begin addr_latch<=rx_data; byte_idx<=0; state<=S_IDATA; end
                S_IDATA: if (rx_valid) begin
                    word_latch <= {word_latch[23:0],rx_data};
                    if (byte_idx==3) begin
                        if (load_mode) begin prog_addr<=addr_latch; prog_data<={word_latch[23:0],rx_data}; prog_we<=1'b1; end
                        resp[0] <= load_mode ? 8'h00 : 8'hE1; resp_len<=1; resp_idx<=0; state<=S_RESP;
                    end else byte_idx<=byte_idx+1'b1;
                end
                S_DADDR: if (rx_valid) begin addr_latch<=rx_data; byte_idx<=0; state<=S_DDATA; end
                S_DDATA: if (rx_valid) begin
                    word_latch <= {word_latch[23:0],rx_data};
                    if (byte_idx==3) begin
                        if (load_mode) begin data_addr<=addr_latch; data_wdata<={word_latch[23:0],rx_data}; data_we<=1'b1; end
                        resp[0] <= load_mode ? 8'h00 : 8'hE1; resp_len<=1; resp_idx<=0; state<=S_RESP;
                    end else byte_idx<=byte_idx+1'b1;
                end
                S_RADDR: if (rx_valid) begin
                    addr_latch<=rx_data;
                    if (cpu_busy) begin resp[0]<=8'hE1; resp_len<=1; resp_idx<=0; state<=S_RESP; end
                    else begin
                        // Host reads are owned by the validation memory only
                        // while the CPU is stopped.  Re-enter load mode
                        // before requesting the synchronous read so result
                        // readback after DONE is deterministic and safe.
                        load_mode<=1'b1;
                        data_raddr<=rx_data; data_re<=1'b1; state<=S_RWAIT1;
                    end
                end
                S_RWAIT1: state<=S_RWAIT;
                S_RWAIT: begin
                    resp[0]<=data_rdata[31:24]; resp[1]<=data_rdata[23:16];
                    resp[2]<=data_rdata[15:8]; resp[3]<=data_rdata[7:0];
                    resp_len<=4; resp_idx<=0; state<=S_RESP;
                end
                S_RESP: begin
                    // uart_tx observes tx_start on the following clock.  Keep
                    // one launch guard cycle so two response bytes cannot be
                    // accepted before tx_busy reflects the first byte.
                    if (tx_launch_wait) begin
                        if (tx_busy) tx_launch_wait <= 1'b0;
                    end else if (!tx_busy && (resp_idx < resp_len)) begin
                        tx_data <= resp[resp_idx]; tx_start<=1'b1; resp_idx<=resp_idx+1'b1;
                        tx_launch_wait <= 1'b1;
                    end else if ((resp_idx >= resp_len) && !tx_busy) state<=S_IDLE;
                end
                default: state<=S_IDLE;
            endcase
        end
    end
endmodule
