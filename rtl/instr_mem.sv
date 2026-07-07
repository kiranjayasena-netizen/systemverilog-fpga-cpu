module instr_mem #(
    parameter int unsigned DEPTH = 256,
    parameter string       INIT_FILE = ""
) (
    input  logic [31:0] addr,
    output logic [31:0] instruction
);

    logic [31:0] mem [0:DEPTH-1];
    logic [7:0]  word_addr;
    logic        addr_in_range;

    assign word_addr     = addr[9:2];
    assign addr_in_range = (addr[31:10] == 22'b0) && (word_addr < DEPTH);

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = 32'h0000_0000;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always_comb begin
        if (addr_in_range) begin
            instruction = mem[word_addr];
        end else begin
            instruction = 32'h0000_0000;
        end
    end

endmodule

