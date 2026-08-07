module fpga_top_pipeline_dot4acc_wb #(
    parameter string       IMEM_INIT_FILE = "programs/dot4acc_stage_d.mem",
    parameter int unsigned IMEM_DEPTH = 256,
    parameter int unsigned DMEM_DEPTH = 256
) (
    input  logic        clk,
    input  logic        rst_btn,
    input  logic        enable_sw,
    output logic [15:0] led
);

    logic        cpu_enable;
    logic [31:0] fetch_pc;
    logic [31:0] instruction_addr;
    logic [31:0] fetch_request_pc;
    logic        fetch_request_valid;
    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic [3:0]  decoded_opcode;
    logic        decoded_valid;
    logic        id_ex_valid;
    logic        ex_mem_valid;
    logic        mem_wb_valid;
    logic [31:0] alu_result;
    logic [31:0] data_addr;
    logic [31:0] memory_read_data;
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [3:0]  retire_opcode;
    logic [4:0]  retire_rd;
    logic        retire_reg_write;
    logic [31:0] retire_write_data;
    logic        retire_mem_write;
    logic [31:0] retire_mem_addr;
    logic [31:0] retire_mem_data;
    logic        reg_write;
    logic        mem_write;
    logic        pc_redirect;
    logic [31:0] total_cycles;
    logic [31:0] retired_instructions;
    logic [31:0] pipeline_fill_cycles;
    logic [31:0] data_hazard_stall_cycles;
    logic [31:0] load_use_stall_cycles;
    logic [31:0] control_hazard_flush_cycles;
    logic [31:0] instruction_fetch_wait_cycles;
    logic [31:0] memory_wait_cycles;
    logic [31:0] taken_branches;
    logic [31:0] not_taken_branches;
    logic [31:0] jumps;
    logic [31:0] wrong_path_instructions_flushed;
    logic        dot_issue_valid;
    logic        dot_issue_accept;
    logic [4:0]  dot_issue_rd;
    logic [31:0] dot_issue_packed_a;
    logic [31:0] dot_issue_packed_b;
    logic [31:0] dot_issue_accumulator;
    logic        dot_issue_chain;
    logic [31:0] dot_issue_pc;
    logic [3:0]  dot_issue_opcode;
    logic [3:0]  dot_inflight_valid;
    logic [19:0] dot_inflight_rd;
    logic        dot_complete_valid;
    logic        dot_complete_eligible;
    logic [4:0]  dot_complete_rd;
    logic [31:0] dot_complete_result;
    logic [31:0] dot_complete_pc;
    logic [3:0]  dot_complete_opcode;
    logic        normal_wb_valid;
    logic        dot_wb_valid;
    logic        rf_write_enable;
    logic [4:0]  rf_write_addr;
    logic [31:0] rf_write_data;
    logic        dot_retire_valid;
    logic        dot_active;
    logic        dot_frontend_hold;
    logic        dot_dependency_stall;
    logic        dot_source_dependency_stall;
    logic        dot_accumulator_dependency_stall;
    logic        dot_cancel_event;

    // Match the established timing-optimised Basys 3 shell: the physical
    // board clock remains the only clock and SW0 gates architectural advance.
    assign cpu_enable = enable_sw;

    cpu_core_pipeline_dot4acc_wb #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE(IMEM_INIT_FILE)
    ) cpu_inst (
        .clk(clk),
        .rst(rst_btn),
        .enable(cpu_enable),
        .fetch_pc(fetch_pc),
        .instruction_addr(instruction_addr),
        .fetch_request_pc(fetch_request_pc),
        .fetch_request_valid(fetch_request_valid),
        .if_id_valid(if_id_valid),
        .if_id_pc(if_id_pc),
        .if_id_instruction(if_id_instruction),
        .decoded_opcode(decoded_opcode),
        .decoded_valid(decoded_valid),
        .id_ex_valid(id_ex_valid),
        .ex_mem_valid(ex_mem_valid),
        .mem_wb_valid(mem_wb_valid),
        .alu_result(alu_result),
        .data_addr(data_addr),
        .memory_read_data(memory_read_data),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_opcode(retire_opcode),
        .retire_rd(retire_rd),
        .retire_reg_write(retire_reg_write),
        .retire_write_data(retire_write_data),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_data(retire_mem_data),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .pc_redirect(pc_redirect),
        .total_cycles(total_cycles),
        .retired_instructions(retired_instructions),
        .pipeline_fill_cycles(pipeline_fill_cycles),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .taken_branches(taken_branches),
        .not_taken_branches(not_taken_branches),
        .jumps(jumps),
        .wrong_path_instructions_flushed(wrong_path_instructions_flushed),
        .dot_issue_valid(dot_issue_valid),
        .dot_issue_accept(dot_issue_accept),
        .dot_issue_rd(dot_issue_rd),
        .dot_issue_packed_a(dot_issue_packed_a),
        .dot_issue_packed_b(dot_issue_packed_b),
        .dot_issue_accumulator(dot_issue_accumulator),
        .dot_issue_chain(dot_issue_chain),
        .dot_issue_pc(dot_issue_pc),
        .dot_issue_opcode(dot_issue_opcode),
        .dot_inflight_valid(dot_inflight_valid),
        .dot_inflight_rd(dot_inflight_rd),
        .dot_complete_valid(dot_complete_valid),
        .dot_complete_eligible(dot_complete_eligible),
        .dot_complete_rd(dot_complete_rd),
        .dot_complete_result(dot_complete_result),
        .dot_complete_pc(dot_complete_pc),
        .dot_complete_opcode(dot_complete_opcode),
        .normal_wb_valid(normal_wb_valid),
        .dot_wb_valid(dot_wb_valid),
        .rf_write_enable(rf_write_enable),
        .rf_write_addr(rf_write_addr),
        .rf_write_data(rf_write_data),
        .dot_retire_valid(dot_retire_valid),
        .dot_active(dot_active),
        .dot_frontend_hold(dot_frontend_hold),
        .dot_dependency_stall(dot_dependency_stall),
        .dot_source_dependency_stall(dot_source_dependency_stall),
        .dot_accumulator_dependency_stall(dot_accumulator_dependency_stall),
        .dot_cancel_event(dot_cancel_event)
    );

    always_comb begin
        // Preserve the established timing-wrapper LED observation map.
        led[3:0]   = fetch_pc[5:2];
        led[7:4]   = decoded_opcode;
        led[8]     = if_id_valid;
        led[9]     = retire_valid;
        led[10]    = reg_write;
        led[11]    = mem_write;
        led[12]    = pc_redirect;
        led[15:13] = {id_ex_valid, ex_mem_valid, mem_wb_valid};
    end

endmodule
