module program_counter #(
    parameter logic [31:0] RESET_ADDR = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    input  logic [31:0] next_pc,
    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= RESET_ADDR;
        end else if (enable) begin
            pc <= next_pc;
        end
    end

endmodule
