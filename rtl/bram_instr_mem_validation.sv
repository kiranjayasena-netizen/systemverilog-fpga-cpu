module bram_instr_mem_validation #(
    parameter int unsigned DEPTH = 256,
    parameter int unsigned WIDTH = 32,
    parameter string INIT_FILE = "",
    parameter logic [WIDTH-1:0] NOP_INSTRUCTION = '0
) (
    input logic clk,
    input logic validation_load_mode,
    input logic validation_prog_we,
    input logic [$clog2(DEPTH)-1:0] validation_prog_addr,
    input logic [WIDTH-1:0] validation_prog_data,
    input logic [31:0] addr,
    output logic [WIDTH-1:0] instruction
);
    localparam int unsigned ADDR_BITS = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_BITS-1:0] word_addr;
    initial begin
        for (int i=0; i<DEPTH; i++) mem[i] = NOP_INSTRUCTION;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    assign word_addr = addr[ADDR_BITS+1:2];
    always_ff @(posedge clk) begin
        if (validation_load_mode && validation_prog_we)
            mem[validation_prog_addr] <= validation_prog_data;
        if (!validation_load_mode) begin
            if (addr[31:ADDR_BITS+2] == '0 && word_addr < DEPTH) instruction <= mem[word_addr];
            else instruction <= NOP_INSTRUCTION;
        end
    end
endmodule
