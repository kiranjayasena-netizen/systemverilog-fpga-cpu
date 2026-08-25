module vector_two_outstanding_prefetch_program_core_synth_top #(
  parameter integer LOOKAHEAD_DEPTH = 6
) (
 input logic clk,rst,start,input logic [4:0] program_length,
 input logic prog_load_enable,input logic [3:0] prog_load_addr,input logic [15:0] prog_load_data,
 input logic data_load_enable,input logic [4:0] data_load_addr,
 input logic data_debug_read_enable,input logic [4:0] data_debug_read_addr,
 input logic vector_load_enable,input logic [2:0] vector_load_addr,
 input logic debug_read_enable,input logic [2:0] debug_read_addr,
 output logic running,done,output logic [3:0] current_pc,output logic status_parity
);
 logic [127:0] data_load_data=128'h44444444_33333333_22222222_11111111;
 logic [127:0] vector_load_data=128'h44444444_33333333_22222222_11111111;
 logic [127:0] data_debug_read_data,debug_read_data; logic [15:0] current_instruction; logic current_instruction_valid; logic [2:0] state_debug;
 logic [31:0] c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13;
 logic debug_entry0_valid,debug_entry1_valid,debug_pending_read_valid; logic [31:0] orhw,c2x,second,p0sd,p1sd,pair,dreq,dhit,maxdist; logic [4:0] debug_entry0_addr,debug_entry1_addr; logic [127:0] debug_entry0_data,debug_entry1_data;
 vector_two_outstanding_prefetch_program_core #(.LOOKAHEAD_DEPTH(LOOKAHEAD_DEPTH)) core(
  .clk(clk),.rst(rst),.start(start),.program_length(program_length),.running(running),.done(done),.current_pc(current_pc),.current_instruction(current_instruction),.current_instruction_valid(current_instruction_valid),
  .prog_load_enable(prog_load_enable),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.data_load_enable(data_load_enable),.data_load_addr(data_load_addr),.data_load_data(data_load_data),
  .data_debug_read_enable(data_debug_read_enable),.data_debug_read_addr(data_debug_read_addr),.data_debug_read_data(data_debug_read_data),.vector_load_enable(vector_load_enable),.vector_load_addr(vector_load_addr),.vector_load_data(vector_load_data),
  .debug_read_enable(debug_read_enable),.debug_read_addr(debug_read_addr),.debug_read_data(debug_read_data),.state_debug(state_debug),.prefetch_request_count(c0),.prefetch_hit_count(c1),.prefetch_miss_count(c2),.entry0_hit_count(c3),.entry1_hit_count(c4),.overlap_alu_count(c5),.overlap_store_count(c6),.dependency_blocked_count(c7),.entry0_fill_count(c8),.entry1_fill_count(c9),.duplicate_suppression_count(c10),.alu_read_overlap_count(c11),.alu_prefetch_hit_count(c12),.debug_entry0_valid(debug_entry0_valid),.debug_entry1_valid(debug_entry1_valid),.debug_entry0_addr(debug_entry0_addr),.debug_entry1_addr(debug_entry1_addr),.debug_entry0_data(debug_entry0_data),.debug_entry1_data(debug_entry1_data),.debug_pending_read_valid(debug_pending_read_valid),.outstanding_read_high_watermark(orhw),.cycles_with_two_outstanding(c2x),.second_request_while_first_pending_count(second),.pending0_stale_discard_count(p0sd),.pending1_stale_discard_count(p1sd),.two_outstanding_useful_pair_count(pair),.deep_prefetch_request_count(dreq),.deep_prefetch_hit_count(dhit),.max_lookahead_distance(maxdist));
 assign status_parity=^current_instruction ^ current_instruction_valid ^ ^data_debug_read_data ^ ^debug_read_data ^ ^c0 ^ ^c1 ^ ^c11 ^ ^c12 ^ ^orhw ^ ^c2x ^ ^second ^ ^debug_entry0_data ^ ^debug_entry1_data;
endmodule

