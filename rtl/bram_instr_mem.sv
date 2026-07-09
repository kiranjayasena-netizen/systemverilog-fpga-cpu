module bram_instr_mem #(
    parameter int unsigned DEPTH = 256,
    parameter int unsigned WIDTH = 32,
    parameter string       INIT_FILE = "",
    parameter logic [WIDTH-1:0] NOP_INSTRUCTION = '0
) (
    input  logic             clk,
    input  logic [31:0]      addr,
    output logic [WIDTH-1:0] instruction
);

    localparam int unsigned ADDR_BITS = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_BITS-1:0] word_addr;
    logic                 addr_in_range;

    assign word_addr     = addr[ADDR_BITS+1:2];
    assign addr_in_range = (addr[31:ADDR_BITS+2] == '0) && (word_addr < DEPTH);

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = NOP_INSTRUCTION;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always_ff @(posedge clk) begin
        if (addr_in_range) begin
            instruction <= mem[word_addr];
        end else begin
            instruction <= NOP_INSTRUCTION;
        end
    end

endmodule
