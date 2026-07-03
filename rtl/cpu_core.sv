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
    logic        mem_read;
    logic        mem_write;
    logic        mem_to_reg;
    logic        data_mem_read_en;
    logic        data_mem_write_en;
    logic [31:0] data_mem_read_data;
    logic [31:0] writeback_data;

    assign alu_b             = use_imm ? imm_ext : rdata_b;
    assign reg_file_we       = reg_write && valid_instr;
    assign data_mem_read_en  = mem_read && valid_instr;
    assign data_mem_write_en = mem_write && valid_instr;
    assign writeback_data    = mem_to_reg ? data_mem_read_data : alu_result;

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
        .valid_instr(valid_instr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg)
    );

    register_file reg_file_inst (
        .clk(clk),
        .rst(rst),
        .we(reg_file_we),
        .waddr(rd),
        .wdata(writeback_data),
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

    data_memory data_mem_inst (
        .clk(clk),
        .rst(rst),
        .mem_read(data_mem_read_en),
        .mem_write(data_mem_write_en),
        .addr(alu_result),
        .write_data(rdata_b),
        .read_data(data_mem_read_data)
    );

endmodule
