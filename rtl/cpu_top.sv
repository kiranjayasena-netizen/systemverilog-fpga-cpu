module cpu_top #(
    parameter int unsigned IMEM_DEPTH = 256,
    parameter string       PROGRAM_FILE = "programs/add_test.mem"
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    output logic [31:0] pc,
    output logic [31:0] instruction,
    output logic [3:0]  opcode,
    output logic        valid_instr,
    output logic [31:0] alu_result
);

    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] imm_ext;
    logic        reg_write;
    logic        use_imm;
    logic [2:0]  alu_op;

    // The current cpu_core already integrates fetch, instruction memory and
    // data memory. cpu_top provides a single runnable processor-system wrapper.
    cpu_core #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .IMEM_INIT_FILE(PROGRAM_FILE)
    ) cpu_inst (
        .clk         (clk),
        .rst         (rst),
        .enable      (enable),
        .pc          (pc),
        .instruction (instruction),
        .opcode      (opcode),
        .rd          (rd),
        .rs1         (rs1),
        .rs2         (rs2),
        .imm_ext     (imm_ext),
        .reg_write   (reg_write),
        .use_imm     (use_imm),
        .alu_op      (alu_op),
        .valid_instr (valid_instr),
        .alu_result  (alu_result)
    );

endmodule

