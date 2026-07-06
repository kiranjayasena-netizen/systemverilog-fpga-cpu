module slow_tick_generator #(
    // Basys 3 clock is 100 MHz. A divisor of 100,000,000 gives a 1 Hz tick.
    parameter int unsigned DIVISOR = 100_000_000
) (
    input  logic clk,
    input  logic rst,
    output logic tick
);

    localparam int unsigned COUNT_WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

    logic [COUNT_WIDTH-1:0] count;

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= '0;
            tick  <= 1'b0;
        end else if (DIVISOR <= 1) begin
            count <= '0;
            tick  <= 1'b1;
        end else if (count == DIVISOR - 1) begin
            count <= '0;
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end

endmodule
