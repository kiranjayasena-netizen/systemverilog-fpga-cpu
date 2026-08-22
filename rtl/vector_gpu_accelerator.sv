// Stable host-facing accelerator wrapper around the selected Stage 14 core.
module vector_gpu_accelerator (
  input logic clk, input logic rst, input logic start,
  input logic [4:0] program_length,
  input logic prog_write_enable, input logic [3:0] prog_write_addr,
  input logic [15:0] prog_write_data,
  input logic data_write_enable, input logic [4:0] data_write_addr,
  input logic [127:0] data_write_data,
  input logic data_read_enable, input logic [4:0] data_read_addr,
  output logic [127:0] data_read_data,
  input logic reg_read_enable, input logic [2:0] reg_read_addr,
  output logic [127:0] reg_read_data,
  output logic busy, output logic done,
  output logic [31:0] cycle_count,
  output logic [31:0] prefetch_request_count,
  output logic [31:0] prefetch_hit_count,
  output logic [31:0] alu_read_overlap_count,
  output logic [31:0] alu_prefetch_hit_count
);
  logic running; logic [3:0] current_pc; logic [15:0] current_instruction; logic current_valid;
  logic [127:0] data_debug_data, debug_data; logic [2:0] state_debug;
  logic [31:0] miss,e0h,e1h,oa,os,dep,e0f,e1f,dup,aph;
  logic [31:0] orhw,c2,second,p0sd,p1sd,pair,dreq,dhit,maxdist;
  logic [31:0] lwo,lws,bdep,brf,succ,rf2; logic e0v,e1v,ep; logic [4:0] e0a,e1a; logic [127:0] e0d,e1d;
  vector_load_overlap_program_core #(.LOOKAHEAD_DEPTH(6)) core (
    .clk(clk),.rst(rst),.start(start),.program_length(program_length),.running(running),.done(done),
    .current_pc(current_pc),.current_instruction(current_instruction),.current_instruction_valid(current_valid),
    .prog_load_enable(prog_write_enable),.prog_load_addr(prog_write_addr),.prog_load_data(prog_write_data),
    .data_load_enable(data_write_enable),.data_load_addr(data_write_addr),.data_load_data(data_write_data),
    .data_debug_read_enable(data_read_enable),.data_debug_read_addr(data_read_addr),.data_debug_read_data(data_debug_data),
    .vector_load_enable(1'b0),.vector_load_addr(3'b0),.vector_load_data(128'b0),
    .debug_read_enable(reg_read_enable),.debug_read_addr(reg_read_addr),.debug_read_data(debug_data),.state_debug(state_debug),
    .prefetch_request_count(prefetch_request_count),.prefetch_hit_count(prefetch_hit_count),.prefetch_miss_count(miss),
    .entry0_hit_count(e0h),.entry1_hit_count(e1h),.overlap_alu_count(oa),.overlap_store_count(os),.dependency_blocked_count(dep),
    .entry0_fill_count(e0f),.entry1_fill_count(e1f),.duplicate_suppression_count(dup),.alu_read_overlap_count(alu_read_overlap_count),
    .alu_prefetch_hit_count(alu_prefetch_hit_count),.debug_entry0_valid(e0v),.debug_entry1_valid(e1v),.debug_entry0_addr(e0a),.debug_entry1_addr(e1a),
    .debug_entry0_data(e0d),.debug_entry1_data(e1d),.debug_pending_read_valid(ep),.outstanding_read_high_watermark(orhw),
    .cycles_with_two_outstanding(c2),.second_request_while_first_pending_count(second),.pending0_stale_discard_count(p0sd),
    .pending1_stale_discard_count(p1sd),.two_outstanding_useful_pair_count(pair),.deep_prefetch_request_count(dreq),
    .deep_prefetch_hit_count(dhit),.max_lookahead_distance(maxdist),.load_writeback_overlap_count(lwo),.load_writeback_cycles_saved(lws),
    .blocked_by_dependency_count(bdep),.blocked_by_rf_write_conflict_count(brf),.successful_overlap_count(succ),.rf_double_write_attempt_count(rf2));
  assign busy = running;
  assign data_read_data = data_debug_data;
  assign reg_read_data = debug_data;
  always_ff @(posedge clk) begin
    if (rst || !running) cycle_count <= 32'd0;
    else cycle_count <= cycle_count + 1'b1;
  end
endmodule
