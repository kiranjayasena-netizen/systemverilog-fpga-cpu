module fetch_unit #(
    parameter int unsigned IMEM_DEPTH = 256,
    parameter string       IMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    input  logic [31:0] next_pc,
    output logic [31:0] pc,
    output logic [31:0] instruction
);

    program_counter #(
        .RESET_ADDR(32'h0000_0000)
    ) pc_inst (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .next_pc(next_pc),
        .pc(pc)
    );

    instruction_memory #(
        .DEPTH(IMEM_DEPTH),
        .INIT_FILE(IMEM_INIT_FILE)
    ) imem (
        .addr(pc),
        .instruction(instruction)
    );

endmodule
