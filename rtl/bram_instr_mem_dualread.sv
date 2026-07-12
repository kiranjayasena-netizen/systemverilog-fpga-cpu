module bram_instr_mem_dualread #(
    parameter int unsigned DEPTH = 256,
    parameter int unsigned WIDTH = 32,
    parameter string       INIT_FILE = "",
    parameter logic [WIDTH-1:0] NOP_INSTRUCTION = '0
) (
    input  logic             clk,
    input  logic [31:0]      addr_a,
    input  logic [31:0]      addr_b,
    output logic [WIDTH-1:0] instruction_a,
    output logic [WIDTH-1:0] instruction_b
);

    localparam int unsigned ADDR_BITS = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_BITS-1:0] word_addr_a;
    logic [ADDR_BITS-1:0] word_addr_b;
    logic                 addr_a_in_range;
    logic                 addr_b_in_range;

    assign word_addr_a    = addr_a[ADDR_BITS+1:2];
    assign word_addr_b    = addr_b[ADDR_BITS+1:2];
    assign addr_a_in_range = (addr_a[31:ADDR_BITS+2] == '0) && (word_addr_a < DEPTH);
    assign addr_b_in_range = (addr_b[31:ADDR_BITS+2] == '0) && (word_addr_b < DEPTH);

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = NOP_INSTRUCTION;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always_ff @(posedge clk) begin
        if (addr_a_in_range) begin
            instruction_a <= mem[word_addr_a];
        end else begin
            instruction_a <= NOP_INSTRUCTION;
        end

        if (addr_b_in_range) begin
            instruction_b <= mem[word_addr_b];
        end else begin
            instruction_b <= NOP_INSTRUCTION;
        end
    end

endmodule
