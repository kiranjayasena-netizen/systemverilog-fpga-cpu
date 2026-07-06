module fpga_top #(
    parameter string IMEM_INIT_FILE = "programs/fpga_led_demo.mem"
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic        enable_sw,
    output logic [15:0] led
);

    logic [31:0] pc;
    logic [31:0] instruction;
    logic [3:0]  opcode;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] imm_ext;
    logic        reg_write;
    logic        use_imm;
    logic [2:0]  alu_op;
    logic        valid_instr;
    logic [31:0] alu_result;

    cpu_core #(
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_btn),
        .enable(enable_sw),
        .pc(pc),
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm_ext(imm_ext),
        .reg_write(reg_write),
        .use_imm(use_imm),
        .alu_op(alu_op),
        .valid_instr(valid_instr),
        .alu_result(alu_result)
    );

    always_comb begin
        led[3:0]   = pc[5:2];
        led[7:4]   = opcode;
        led[8]     = valid_instr;
        led[9]     = reg_write;
        led[10]    = use_imm;
        led[13:11] = alu_op;
        led[15:14] = alu_result[1:0];
    end

endmodule
