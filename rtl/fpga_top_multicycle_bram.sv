module fpga_top_multicycle_bram #(
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256,
    parameter int unsigned SLOW_TICK_DIVISOR = 100_000_000
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic        enable_sw,
    output logic [15:0] led
);

    logic        slow_tick;
    logic        cpu_enable;
    logic [2:0]  state;
    logic [31:0] pc;
    logic [31:0] instruction_reg;
    logic [31:0] instruction_pc;
    logic [3:0]  opcode_reg;
    logic [4:0]  rd_reg;
    logic [4:0]  rs1_reg;
    logic [4:0]  rs2_reg;
    logic [12:0] imm13_reg;
    logic [31:0] imm_ext_reg;
    logic        valid_instr;
    logic        reg_write;
    logic        mem_write;
    logic [31:0] alu_result;
    logic [31:0] memory_read_data;
    logic [31:0] instruction_addr;
    logic [31:0] data_addr;

    slow_tick_generator #(
        .DIVISOR(SLOW_TICK_DIVISOR)
    ) slow_tick_inst (
        .clk  (clk),
        .rst  (rst_btn),
        .tick (slow_tick)
    );

    assign cpu_enable = enable_sw && slow_tick;

    cpu_core_multicycle_bram #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_btn),
        .enable(cpu_enable),
        .state(state),
        .pc(pc),
        .instruction_reg(instruction_reg),
        .instruction_pc(instruction_pc),
        .opcode_reg(opcode_reg),
        .rd_reg(rd_reg),
        .rs1_reg(rs1_reg),
        .rs2_reg(rs2_reg),
        .imm13_reg(imm13_reg),
        .imm_ext_reg(imm_ext_reg),
        .valid_instr(valid_instr),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_result(alu_result),
        .memory_read_data(memory_read_data),
        .instruction_addr(instruction_addr),
        .data_addr(data_addr)
    );

    always_comb begin
        led[3:0]   = pc[5:2];
        led[7:4]   = opcode_reg;
        led[8]     = valid_instr;
        led[9]     = reg_write;
        led[10]    = mem_write;
        led[13:11] = state;
        led[15:14] = alu_result[1:0];
    end

endmodule
