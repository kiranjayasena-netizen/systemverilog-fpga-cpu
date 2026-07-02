module instruction_memory #(
    parameter int unsigned DEPTH = 256,
    parameter string INIT_FILE = ""
) (
    input  logic [31:0] addr,
    output logic [31:0] instruction
);

    logic [31:0] mem [0:DEPTH-1];
    logic [29:0] word_addr;

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = 32'h0000_0000;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    assign word_addr = addr[31:2];

    always_comb begin
        if (word_addr < DEPTH) begin
            instruction = mem[word_addr];
        end else begin
            instruction = 32'h0000_0000;
        end
    end

endmodule
