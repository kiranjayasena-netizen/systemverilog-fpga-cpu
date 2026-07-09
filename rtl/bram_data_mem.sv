module bram_data_mem #(
    parameter int unsigned DEPTH = 256,
    parameter int unsigned WIDTH = 32
) (
    input  logic             clk,
    input  logic             mem_read,
    input  logic             mem_write,
    input  logic [31:0]      addr,
    input  logic [WIDTH-1:0] write_data,
    output logic [WIDTH-1:0] read_data
);

    localparam int unsigned ADDR_BITS = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_BITS-1:0] word_addr;
    logic                 addr_in_range;

    assign word_addr     = addr[ADDR_BITS+1:2];
    assign addr_in_range = (addr[31:ADDR_BITS+2] == '0) && (word_addr < DEPTH);

    always_ff @(posedge clk) begin
        if (mem_write && addr_in_range) begin
            mem[word_addr] <= write_data;
        end

        if (mem_read && addr_in_range) begin
            read_data <= mem[word_addr];
        end else begin
            read_data <= '0;
        end
    end

endmodule
