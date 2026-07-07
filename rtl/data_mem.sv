module data_mem #(
    parameter int unsigned DEPTH = 256
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);

    logic [31:0] mem [0:DEPTH-1];
    logic [7:0]  word_addr;
    logic        addr_in_range;

    assign word_addr     = addr[9:2];
    assign addr_in_range = (addr[31:10] == 22'b0) && (word_addr < DEPTH);

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= 32'h0000_0000;
            end
        end else if (mem_write && addr_in_range) begin
            mem[word_addr] <= write_data;
        end
    end

    always_comb begin
        if (mem_read && addr_in_range) begin
            read_data = mem[word_addr];
        end else begin
            read_data = 32'h0000_0000;
        end
    end

endmodule

