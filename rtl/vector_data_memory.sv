// Stage 6 standalone synchronous whole-vector data memory.
// Contents are intentionally not reset; software/testbench must write before read.
module vector_data_memory #(
    parameter int unsigned DEPTH = 32
) (
    input  logic                         clk,
    input  logic                         read_enable,
    input  logic [$clog2(DEPTH)-1:0]     read_addr,
    output logic [127:0]                 read_data,
    input  logic                         write_enable,
    input  logic [$clog2(DEPTH)-1:0]     write_addr,
    input  logic [127:0]                 write_data
);
    logic [127:0] memory [0:DEPTH-1];

    initial begin
        if (DEPTH == 0) $fatal(1, "vector_data_memory DEPTH must be non-zero");
    end

    always_ff @(posedge clk) begin
        if (read_enable)
            read_data <= memory[read_addr];
        if (write_enable)
            memory[write_addr] <= write_data;
    end
endmodule
