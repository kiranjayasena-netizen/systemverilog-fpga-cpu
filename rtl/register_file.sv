module register_file (
    input  logic        clk,
    input  logic        rst,

    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,

    input  logic [4:0]  raddr_a,
    input  logic [4:0]  raddr_b,
    output logic [31:0] rdata_a,
    output logic [31:0] rdata_b
);

    logic [31:0] regs [0:31];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if (we && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

    always_comb begin
        rdata_a = (raddr_a == 5'd0) ? 32'h0000_0000 : regs[raddr_a];
        rdata_b = (raddr_b == 5'd0) ? 32'h0000_0000 : regs[raddr_b];
    end

endmodule
