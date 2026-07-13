module fpga_top_pipeline6 #(
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
    parameter int unsigned IMEM_DEPTH = 256
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic        enable_sw,
    output logic [15:0] led
);

    logic [31:0] fetch_pc;
    logic [31:0] instruction_addr;
    logic        fetch_request_valid;
    logic [31:0] fetch_request_pc;
    logic        if_id_valid;
    logic        id_op_valid;
    logic        op_ex_valid;
    logic        ex_mem_valid;
    logic        mem_wb_valid;
    logic [31:0] if_id_pc;
    logic [31:0] id_op_pc;
    logic [31:0] op_ex_pc;
    logic [31:0] ex_mem_pc;
    logic [31:0] mem_wb_pc;
    logic [31:0] if_id_instr;
    logic [31:0] id_op_instr;
    logic [31:0] op_ex_instr;
    logic [31:0] ex_mem_instr;
    logic [31:0] mem_wb_instr;
    logic [3:0]  if_id_opcode;
    logic [3:0]  id_op_opcode;
    logic [3:0]  op_ex_opcode;
    logic [3:0]  ex_mem_opcode;
    logic [3:0]  mem_wb_opcode;
    logic        if_id_decoded_valid;
    logic        id_op_decoded_valid;
    logic        op_ex_decoded_valid;
    logic        ex_mem_decoded_valid;
    logic        mem_wb_decoded_valid;
    logic [31:0] retired_count;
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [3:0]  retire_opcode;
    logic        reg_write;
    logic        mem_write;
    logic        mem_read;
    logic [31:0] mem_addr;
    logic [31:0] mem_write_data;
    logic [31:0] mem_read_data;
    logic        load_use_stall;
    logic        writeback_valid;
    logic [4:0]  writeback_rd;
    logic [31:0] writeback_data;
    logic        stall_active;
    logic [31:0] debug_x0;
    logic [31:0] debug_x1;
    logic [31:0] debug_x2;
    logic [31:0] debug_x3;
    logic [31:0] debug_x4;
    logic [31:0] debug_x5;
    logic [31:0] debug_x6;
    logic [31:0] debug_x7;
    logic [31:0] debug_x8;
    logic [31:0] debug_x9;
    logic [31:0] debug_x10;
    logic [31:0] debug_x11;
    logic [31:0] debug_x12;
    logic [31:0] debug_x13;

    cpu_core_pipeline6 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_btn),
        .enable(enable_sw),
        .debug_fetch_pc(fetch_pc),
        .debug_instruction_addr(instruction_addr),
        .debug_fetch_request_valid(fetch_request_valid),
        .debug_fetch_request_pc(fetch_request_pc),
        .debug_if_id_valid(if_id_valid),
        .debug_id_op_valid(id_op_valid),
        .debug_op_ex_valid(op_ex_valid),
        .debug_ex_mem_valid(ex_mem_valid),
        .debug_mem_wb_valid(mem_wb_valid),
        .debug_if_id_pc(if_id_pc),
        .debug_id_op_pc(id_op_pc),
        .debug_op_ex_pc(op_ex_pc),
        .debug_ex_mem_pc(ex_mem_pc),
        .debug_mem_wb_pc(mem_wb_pc),
        .debug_if_id_instr(if_id_instr),
        .debug_id_op_instr(id_op_instr),
        .debug_op_ex_instr(op_ex_instr),
        .debug_ex_mem_instr(ex_mem_instr),
        .debug_mem_wb_instr(mem_wb_instr),
        .debug_if_id_opcode(if_id_opcode),
        .debug_id_op_opcode(id_op_opcode),
        .debug_op_ex_opcode(op_ex_opcode),
        .debug_ex_mem_opcode(ex_mem_opcode),
        .debug_mem_wb_opcode(mem_wb_opcode),
        .debug_if_id_decoded_valid(if_id_decoded_valid),
        .debug_id_op_decoded_valid(id_op_decoded_valid),
        .debug_op_ex_decoded_valid(op_ex_decoded_valid),
        .debug_ex_mem_decoded_valid(ex_mem_decoded_valid),
        .debug_mem_wb_decoded_valid(mem_wb_decoded_valid),
        .debug_retired_count(retired_count),
        .debug_retire_valid(retire_valid),
        .debug_retire_pc(retire_pc),
        .debug_retire_opcode(retire_opcode),
        .debug_reg_write(reg_write),
        .debug_mem_write(mem_write),
        .debug_mem_read(mem_read),
        .debug_mem_addr(mem_addr),
        .debug_mem_write_data(mem_write_data),
        .debug_mem_read_data(mem_read_data),
        .debug_load_use_stall(load_use_stall),
        .debug_writeback_valid(writeback_valid),
        .debug_writeback_rd(writeback_rd),
        .debug_writeback_data(writeback_data),
        .debug_stall_active(stall_active),
        .debug_x0(debug_x0),
        .debug_x1(debug_x1),
        .debug_x2(debug_x2),
        .debug_x3(debug_x3),
        .debug_x4(debug_x4),
        .debug_x5(debug_x5),
        .debug_x6(debug_x6),
        .debug_x7(debug_x7),
        .debug_x8(debug_x8),
        .debug_x9(debug_x9),
        .debug_x10(debug_x10),
        .debug_x11(debug_x11),
        .debug_x12(debug_x12),
        .debug_x13(debug_x13)
    );

    always_comb begin
        // LED debug map:
        // led[3:0]   = fetch PC word index
        // led[7:4]   = IF/ID opcode
        // led[8]     = IF/ID valid
        // led[9]     = ID/OP valid
        // led[10]    = OP/EX valid
        // led[11]    = EX/MEM valid
        // led[12]    = MEM/WB valid
        // led[13]    = retirement pulse
        // led[14]    = register-write side-effect pulse
        // led[15]    = memory-write side-effect pulse
        led[3:0] = fetch_pc[5:2];
        led[7:4] = if_id_opcode;
        led[8]   = if_id_valid;
        led[9]   = id_op_valid;
        led[10]  = op_ex_valid;
        led[11]  = ex_mem_valid;
        led[12]  = mem_wb_valid;
        led[13]  = retire_valid;
        led[14]  = reg_write;
        led[15]  = mem_write;
    end

endmodule
