module fpga_top_pipeline_branchprefetch #(
    parameter string       IMEM_INIT_FILE = "programs/fpga_led_demo.mem",
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
    logic [31:0] beq_target_prefetch_requests;
    logic [31:0] beq_target_prefetch_hits;
    logic [31:0] beq_target_prefetch_discards;
    logic [31:0] beq_target_prefetch_invalidations;

    // Performance-oriented pipeline top: keep the 100 MHz board clock as the
    // only real clock and let the CPU advance every cycle while SW0 is high.
    assign cpu_enable = enable_sw;

    cpu_core_pipeline_branchprefetch #(
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
        .beq_target_prefetch_requests(beq_target_prefetch_requests),
        .beq_target_prefetch_hits(beq_target_prefetch_hits),
        .beq_target_prefetch_discards(beq_target_prefetch_discards),
        .beq_target_prefetch_invalidations(beq_target_prefetch_invalidations)
    );

    always_comb begin
        // LED debug map:
        // led[3:0]   = fetch PC word index from fetch_pc[5:2]
        // led[7:4]   = IF/ID decoded opcode
        // led[8]     = IF/ID valid
        // led[9]     = retirement valid
        // led[10]    = register writeback pulse
        // led[11]    = data-memory write pulse
        // led[12]    = PC redirect pulse
        // led[15:13] = pipeline stage valid bits {ID/EX, EX/MEM, MEM/WB}
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
