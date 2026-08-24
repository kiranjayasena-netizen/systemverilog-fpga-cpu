module uart_rx #(parameter integer CLKS_PER_BIT=694) (
  input  logic clk,
  input  logic rst,
  input  logic rx,
  output logic valid,
  output logic [7:0] data
);
  typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
  rx_state_t state;
  integer count;
  logic [2:0] bit_idx;
  logic [7:0] shift;

  always_ff @(posedge clk) begin
    valid <= 1'b0;
    if (rst) begin
      state   <= RX_IDLE;
      count   <= 0;
      bit_idx <= 3'd0;
      shift   <= 8'd0;
      data    <= 8'd0;
    end else begin
      case (state)
        RX_IDLE: begin
          if (!rx) begin
            // The first sample is the centre of the start bit, not data bit 0.
            count <= (CLKS_PER_BIT / 2) - 1;
            state <= RX_START;
          end
        end
        RX_START: begin
          if (count != 0) begin
            count <= count - 1;
          end else if (!rx) begin
            count   <= CLKS_PER_BIT - 1;
            bit_idx <= 3'd0;
            state   <= RX_DATA;
          end else begin
            // False start: return to idle without emitting a byte.
            state <= RX_IDLE;
          end
        end
        RX_DATA: begin
          if (count != 0) begin
            count <= count - 1;
          end else begin
            shift[bit_idx] <= rx;
            count <= CLKS_PER_BIT - 1;
            if (bit_idx == 3'd7)
              state <= RX_STOP;
            else
              bit_idx <= bit_idx + 1'b1;
          end
        end
        RX_STOP: begin
          if (count != 0) begin
            count <= count - 1;
          end else begin
            if (rx) begin
              data  <= shift;
              valid <= 1'b1;
            end
            state <= RX_IDLE;
          end
        end
        default: state <= RX_IDLE;
      endcase
    end
  end
endmodule
