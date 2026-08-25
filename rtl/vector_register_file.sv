// Standalone Phase 1 vector register file.
//
// Four 32-bit lanes form one 128-bit vector.  This module is deliberately
// independent of the frozen CPU so its storage and lane-ordering semantics can
// be verified before any CPU/accelerator interface is designed.
module vector_register_file #(
    parameter int unsigned LANES         = 4,
    parameter int unsigned ELEMENT_WIDTH = 32,
    parameter int unsigned REG_COUNT     = 8
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         we,
    input  logic [(REG_COUNT <= 1 ? 1 : $clog2(REG_COUNT))-1:0] waddr,
    input  logic [LANES*ELEMENT_WIDTH-1:0] wdata,
    input  logic [(REG_COUNT <= 1 ? 1 : $clog2(REG_COUNT))-1:0] raddr_a,
    input  logic [(REG_COUNT <= 1 ? 1 : $clog2(REG_COUNT))-1:0] raddr_b,
    output logic [LANES*ELEMENT_WIDTH-1:0] rdata_a,
    output logic [LANES*ELEMENT_WIDTH-1:0] rdata_b
);

    localparam int unsigned VECTOR_WIDTH = LANES * ELEMENT_WIDTH;
    localparam int unsigned ADDR_WIDTH = (REG_COUNT <= 1) ? 1 : $clog2(REG_COUNT);

    logic [VECTOR_WIDTH-1:0] regs [0:REG_COUNT-1];

    initial begin
        if (LANES == 0 || ELEMENT_WIDTH == 0 || REG_COUNT == 0) begin
            $fatal(1, "vector_register_file parameters must be non-zero");
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < REG_COUNT; i++) begin
                regs[i] <= '0;
            end
        end else if (we && (waddr < REG_COUNT)) begin
            regs[waddr] <= wdata;
        end
    end

    always_comb begin
        rdata_a = (raddr_a < REG_COUNT) ? regs[raddr_a] : '0;
        rdata_b = (raddr_b < REG_COUNT) ? regs[raddr_b] : '0;
    end

endmodule
