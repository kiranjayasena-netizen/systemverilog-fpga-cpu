module fpga_top_pipeline6_bringup #(
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned SLOW_DIVIDE_CYCLES = 25_000_000
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic [1:0]  sw,
    output logic [15:0] led
);

    localparam int unsigned SLOW_COUNTER_WIDTH = $clog2(SLOW_DIVIDE_CYCLES);

    logic rst_meta;
    logic rst_sync;
    logic [1:0] sw_meta;
    logic [1:0] sw_sync;

    logic [SLOW_COUNTER_WIDTH-1:0] slow_counter;
    logic slow_pulse;
    logic cpu_enable;

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
    logic        redirect_valid;
    logic [31:0] redirect_pc;
    logic        flush_valid;
    logic        branch_taken;
    logic        jump_taken;
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
    logic        stall_seen;
    logic        redirect_seen;
    logic        retire_seen;
    logic        reg_write_seen;
    logic        mem_write_seen;

    always_ff @(posedge clk) begin
        rst_meta <= rst_btn;
        rst_sync <= rst_meta;
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
    end

    always_ff @(posedge clk) begin
        if (rst_sync || !sw_sync[0] || !sw_sync[1]) begin
            slow_counter <= '0;
            slow_pulse   <= 1'b0;
        end else if (slow_counter == SLOW_DIVIDE_CYCLES - 1) begin
            slow_counter <= '0;
            slow_pulse   <= 1'b1;
        end else begin
            slow_counter <= slow_counter + {{(SLOW_COUNTER_WIDTH-1){1'b0}}, 1'b1};
            slow_pulse   <= 1'b0;
        end
    end

    assign cpu_enable = sw_sync[0] && (!sw_sync[1] || slow_pulse);

    cpu_core_pipeline6 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_sync),
        .enable(cpu_enable),
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
        .debug_redirect_valid(redirect_valid),
        .debug_redirect_pc(redirect_pc),
        .debug_flush_valid(flush_valid),
        .debug_branch_taken(branch_taken),
        .debug_jump_taken(jump_taken),
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

    always_ff @(posedge clk) begin
        if (rst_sync) begin
            stall_seen     <= 1'b0;
            redirect_seen  <= 1'b0;
            retire_seen    <= 1'b0;
            reg_write_seen <= 1'b0;
            mem_write_seen <= 1'b0;
        end else begin
            if (stall_active || load_use_stall) begin
                stall_seen <= 1'b1;
            end
            if (redirect_valid) begin
                redirect_seen <= 1'b1;
            end
            if (retire_valid) begin
                retire_seen <= 1'b1;
            end
            if (reg_write) begin
                reg_write_seen <= 1'b1;
            end
            if (mem_write) begin
                mem_write_seen <= 1'b1;
            end
        end
    end

    always_comb begin
        // LED debug map for Basys 3 bring-up:
        // led[3:0]   = fetch PC word index, fetch_pc[5:2]
        // led[8:4]   = IF/ID, ID/OP, OP/EX, EX/MEM, MEM/WB valid bits
        // led[9]     = sticky stall/load-use-stall observed
        // led[10]    = sticky redirect observed
        // led[11]    = sticky retirement observed
        // led[12]    = sticky register write observed
        // led[13]    = sticky memory write observed
        // led[14]    = slow mode active, synchronized SW1
        // led[15]    = run enabled, synchronized SW0
        led[3:0] = fetch_pc[5:2];
        led[4]   = if_id_valid;
        led[5]   = id_op_valid;
        led[6]   = op_ex_valid;
        led[7]   = ex_mem_valid;
        led[8]   = mem_wb_valid;
        led[9]   = stall_seen;
        led[10]  = redirect_seen;
        led[11]  = retire_seen;
        led[12]  = reg_write_seen;
        led[13]  = mem_write_seen;
        led[14]  = sw_sync[1];
        led[15]  = sw_sync[0];
    end

endmodule
