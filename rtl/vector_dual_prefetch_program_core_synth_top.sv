// Stage 10A physical-characterisation wrapper.  The complete dual-entry core
// remains instantiated; compact status outputs prevent synthetic IO from
// dominating the implementation while preserving datapath observability.
module vector_dual_prefetch_program_core_synth_top(
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
 logic [127:0] data_debug_read_data,debug_read_data;
 logic [15:0] current_instruction; logic current_instruction_valid; logic [2:0] state_debug;
 logic [31:0] prefetch_request_count,prefetch_hit_count,prefetch_miss_count,entry0_hit_count,entry1_hit_count,overlap_alu_count,overlap_store_count,dependency_blocked_count,entry0_fill_count,entry1_fill_count,duplicate_suppression_count;
 logic debug_entry0_valid,debug_entry1_valid,debug_pending_read_valid; logic [4:0] debug_entry0_addr,debug_entry1_addr; logic [127:0] debug_entry0_data,debug_entry1_data;
 vector_dual_prefetch_program_core core(
  .clk(clk),.rst(rst),.start(start),.program_length(program_length),.running(running),.done(done),.current_pc(current_pc),.current_instruction(current_instruction),.current_instruction_valid(current_instruction_valid),
  .prog_load_enable(prog_load_enable),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.data_load_enable(data_load_enable),.data_load_addr(data_load_addr),.data_load_data(data_load_data),
  .data_debug_read_enable(data_debug_read_enable),.data_debug_read_addr(data_debug_read_addr),.data_debug_read_data(data_debug_read_data),.vector_load_enable(vector_load_enable),.vector_load_addr(vector_load_addr),.vector_load_data(vector_load_data),
  .debug_read_enable(debug_read_enable),.debug_read_addr(debug_read_addr),.debug_read_data(debug_read_data),.state_debug(state_debug),.prefetch_request_count(prefetch_request_count),.prefetch_hit_count(prefetch_hit_count),.prefetch_miss_count(prefetch_miss_count),.entry0_hit_count(entry0_hit_count),.entry1_hit_count(entry1_hit_count),.overlap_alu_count(overlap_alu_count),.overlap_store_count(overlap_store_count),.dependency_blocked_count(dependency_blocked_count),.entry0_fill_count(entry0_fill_count),.entry1_fill_count(entry1_fill_count),.duplicate_suppression_count(duplicate_suppression_count),.debug_entry0_valid(debug_entry0_valid),.debug_entry1_valid(debug_entry1_valid),.debug_entry0_addr(debug_entry0_addr),.debug_entry1_addr(debug_entry1_addr),.debug_entry0_data(debug_entry0_data),.debug_entry1_data(debug_entry1_data),.debug_pending_read_valid(debug_pending_read_valid));
 assign status_parity=^current_instruction ^ current_instruction_valid ^ ^data_debug_read_data ^ ^debug_read_data ^ ^prefetch_request_count ^ ^prefetch_hit_count ^ ^prefetch_miss_count ^ ^debug_entry0_data ^ ^debug_entry1_data;
endmodule
