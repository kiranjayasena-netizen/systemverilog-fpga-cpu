module bram_data_mem_validation #(
    parameter int unsigned DEPTH = 256,
    parameter int unsigned WIDTH = 32
) (
    input logic clk,
    input logic validation_load_mode,
    input logic validation_data_we,
    input logic [$clog2(DEPTH)-1:0] validation_data_addr,
    input logic [WIDTH-1:0] validation_data_wdata,
    input logic validation_data_re,
    input logic [$clog2(DEPTH)-1:0] validation_data_raddr,
    output logic [WIDTH-1:0] validation_data_rdata,
    input logic mem_read,
    input logic mem_write,
    input logic [31:0] addr,
    input logic [WIDTH-1:0] write_data,
    output logic [WIDTH-1:0] read_data
);
    localparam int unsigned ADDR_BITS = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_BITS-1:0] word_addr;
    assign word_addr = addr[ADDR_BITS+1:2];
    always_ff @(posedge clk) begin
        if (validation_load_mode) begin
            if (validation_data_we) mem[validation_data_addr] <= validation_data_wdata;
            if (validation_data_re) validation_data_rdata <= mem[validation_data_raddr];
        end else begin
            if (mem_write && addr[31:ADDR_BITS+2] == '0 && word_addr < DEPTH) mem[word_addr] <= write_data;
            if (mem_read && addr[31:ADDR_BITS+2] == '0 && word_addr < DEPTH) read_data <= mem[word_addr];
            else read_data <= '0;
        end
    end
endmodule
