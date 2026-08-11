// Stage 5 small standalone vector instruction memory.
// Reads are combinational; writes use the program-load clock edge.
module vector_instruction_memory #(
    parameter int unsigned DEPTH = 16
) (
    input  logic                         clk,
    input  logic                         prog_load_enable,
    input  logic [((DEPTH <= 1) ? 1 : $clog2(DEPTH))-1:0] prog_load_addr,
    input  logic [15:0]                  prog_load_data,
    input  logic [((DEPTH <= 1) ? 1 : $clog2(DEPTH))-1:0] read_addr,
    output logic [15:0]                  read_data
);
    localparam int unsigned ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    logic [15:0] memory [0:DEPTH-1];

    initial begin
        if (DEPTH == 0) $fatal(1, "instruction memory DEPTH must be non-zero");
    end

    always_ff @(posedge clk) begin
        if (prog_load_enable && (prog_load_addr < DEPTH))
            memory[prog_load_addr] <= prog_load_data;
    end

    always_comb begin
        if (read_addr < DEPTH)
            read_data = memory[read_addr];
        else
            read_data = 16'h0000;
    end
endmodule
