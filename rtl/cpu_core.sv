module cpu_core (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    output logic [31:0] pc,
    output logic [31:0] instruction,
    output logic [3:0]  opcode,
    output logic [4:0]  rd,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [31:0] imm_ext,
    output logic        reg_write,
    output logic        use_imm,
    output logic [2:0]  alu_op,
    output logic        valid_instr,
    output logic [31:0] alu_result
);

    logic [12:0] imm13;
    logic [31:0] rdata_a;
    logic [31:0] rdata_b;
    logic [31:0] alu_b;
    logic        reg_file_we;

    assign alu_b       = use_imm ? imm_ext : rdata_b;
    assign reg_file_we = reg_write && valid_instr;

    fetch_unit fetch_inst (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .pc(pc),
        .instruction(instruction)
    );

    instruction_decoder decoder_inst (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm13(imm13),
        .imm_ext(imm_ext)
    );

    control_unit control_inst (
        .opcode(opcode),
        .reg_write(reg_write),
        .use_imm(use_imm),
        .alu_op(alu_op),
        .valid_instr(valid_instr)
    );

    register_file reg_file_inst (
        .clk(clk),
        .rst(rst),
        .we(reg_file_we),
        .waddr(rd),
        .wdata(alu_result),
        .raddr_a(rs1),
        .raddr_b(rs2),
        .rdata_a(rdata_a),
        .rdata_b(rdata_b)
    );

    alu #(
        .WIDTH(32)
    ) alu_inst (
        .a(rdata_a),
        .b(alu_b),
        .op(alu_op),
        .y(alu_result)
    );

endmodule
