module fetch_unit (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    output logic [31:0] pc,
    output logic [31:0] instruction
);

    logic [31:0] next_pc;

    assign next_pc = pc + 32'd4;

    program_counter #(
        .RESET_ADDR(32'h0000_0000)
    ) pc_inst (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .next_pc(next_pc),
        .pc(pc)
    );

    instruction_memory imem (
        .addr(pc),
        .instruction(instruction)
    );

endmodule
