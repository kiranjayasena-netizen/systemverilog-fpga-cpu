// Validation-only shell for the frozen CPU implementations.  The selected
// core remains cycle-for-cycle responsible for execution; this module only
// owns the safe load/run/read control contract used by the board harness.
module ai_cpu_validation_wrapper #(
    parameter bit OPTIMIZED = 1'b0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        load_mode,
    input  logic        start,
    input  logic        prog_we,
    input  logic [7:0]  prog_addr,
    input  logic [31:0] prog_data,
    input  logic        data_we,
    input  logic [7:0]  data_addr_host,
    input  logic [31:0] data_wdata,
    input  logic        data_re,
    input  logic [7:0]  data_raddr,
    output logic [31:0] data_rdata,
    output logic        busy,
    output logic        done,
    output logic [31:0] cycle_count
);
    logic run_active;
    logic core_done;
    logic [31:0] core_cycles;

    // Common named nets allow the two generate branches to instantiate the
    // derivatives with identical wiring.  Unused architectural observations
    // are intentionally left unconnected at this boundary.
    logic [31:0] fetch_pc, instruction_addr, fetch_request_pc;
    logic fetch_request_valid, if_id_valid, id_ex_valid, ex_mem_valid;
    logic mem_wb_valid, decoded_valid, retire_valid, retire_reg_write;
    logic [31:0] if_id_pc, if_id_instruction, alu_result, data_addr;
    logic [31:0] memory_read_data, retire_pc, retire_write_data;
    logic [31:0] retire_mem_addr, retire_mem_data;
    logic [3:0] decoded_opcode, retire_opcode;
    logic [4:0] retire_rd;
    logic reg_write, mem_write, pc_redirect, retire_mem_write;
    logic [31:0] retired_instructions, pipeline_fill_cycles;
    logic [31:0] data_hazard_stall_cycles, load_use_stall_cycles;
    logic [31:0] control_hazard_flush_cycles, instruction_fetch_wait_cycles;
    logic [31:0] memory_wait_cycles, taken_branches, not_taken_branches;
    logic [31:0] jumps, wrong_path_instructions_flushed;
    logic [31:0] validation_data_rdata;

    logic dot_issue_valid, dot_issue_accept, dot_issue_chain;
    logic [4:0] dot_issue_rd, dot_complete_rd;
    logic [31:0] dot_issue_packed_a, dot_issue_packed_b;
    logic [31:0] dot_issue_accumulator, dot_issue_pc;
    logic [3:0] dot_issue_opcode, dot_inflight_valid, dot_complete_opcode;
    logic dot_complete_valid, dot_complete_eligible, normal_wb_valid;
    logic dot_wb_valid, rf_write_enable, dot_retire_valid, dot_active;
    logic [19:0] dot_inflight_rd;
    logic [31:0] dot_complete_result, dot_complete_pc, rf_write_data;
    logic [4:0] rf_write_addr;
    logic dot_frontend_hold, dot_dependency_stall;
    logic dot_source_dependency_stall, dot_accumulator_dependency_stall;
    logic dot_cancel_event;

    assign busy = run_active;
    assign done = core_done;
    assign cycle_count = core_cycles;
    assign data_rdata = validation_data_rdata;

    // load_mode is deliberately part of core reset.  This guarantees that a
    // newly loaded image starts from a clean architectural state and prevents
    // host writes from racing an executing pipeline.
    wire core_rst = rst | load_mode;
    wire core_enable = run_active;

    always_ff @(posedge clk) begin
        if (rst) begin
            run_active <= 1'b0;
        end else begin
            if (start && !load_mode && !run_active)
                run_active <= 1'b1;
            if (core_done)
                run_active <= 1'b0;
        end
    end

    generate
        if (!OPTIMIZED) begin : g_baseline
            cpu_core_pipeline_timingopt_validation core (.*,
                .clk(clk), .rst(core_rst), .enable(core_enable),
                .total_cycles(core_cycles),
                .validation_load_mode(load_mode),
                .validation_prog_we(prog_we),
                .validation_prog_addr(prog_addr),
                .validation_prog_data(prog_data),
                .validation_data_we(data_we),
                .validation_data_addr(data_addr_host),
                .validation_data_wdata(data_wdata),
                .validation_data_re(data_re),
                .validation_data_raddr(data_raddr),
                .validation_data_rdata(validation_data_rdata),
                .validation_done(core_done));
        end else begin : g_optimized
            cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation core (.*,
                .clk(clk), .rst(core_rst), .enable(core_enable),
                .total_cycles(core_cycles),
                .validation_load_mode(load_mode),
                .validation_prog_we(prog_we),
                .validation_prog_addr(prog_addr),
                .validation_prog_data(prog_data),
                .validation_data_we(data_we),
                .validation_data_addr(data_addr_host),
                .validation_data_wdata(data_wdata),
                .validation_data_re(data_re),
                .validation_data_raddr(data_raddr),
                .validation_data_rdata(validation_data_rdata),
                .validation_done(core_done));
        end
    endgenerate
endmodule
