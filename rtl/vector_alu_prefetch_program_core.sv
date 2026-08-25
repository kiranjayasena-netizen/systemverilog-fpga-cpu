// Stage 10B-A: Stage 10A dual-entry prefetch with safe ALU/read overlap.
// The Stage 10A source is intentionally left unchanged; this is an independent core.
module vector_alu_prefetch_program_core #(
 parameter int unsigned PROGRAM_DEPTH=16, DATA_DEPTH=32
) (
 input logic clk,rst,start,input logic [4:0] program_length, output logic running,done,
 output logic [((PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH))-1:0] current_pc,
 output logic [15:0] current_instruction, output logic current_instruction_valid,
 input logic prog_load_enable,input logic [((PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH))-1:0] prog_load_addr,input logic [15:0] prog_load_data,
 input logic data_load_enable,input logic [((DATA_DEPTH<=1)?1:$clog2(DATA_DEPTH))-1:0] data_load_addr,input logic [127:0] data_load_data,
 input logic data_debug_read_enable,input logic [((DATA_DEPTH<=1)?1:$clog2(DATA_DEPTH))-1:0] data_debug_read_addr,output logic [127:0] data_debug_read_data,
 input logic vector_load_enable,input logic [2:0] vector_load_addr,input logic [127:0] vector_load_data,
 input logic debug_read_enable,input logic [2:0] debug_read_addr,output logic [127:0] debug_read_data,output logic [2:0] state_debug,
 output logic [31:0] prefetch_request_count,prefetch_hit_count,prefetch_miss_count,entry0_hit_count,entry1_hit_count,
 output logic [31:0] overlap_alu_count,overlap_store_count,dependency_blocked_count,entry0_fill_count,entry1_fill_count,duplicate_suppression_count,
 output logic [31:0] alu_read_overlap_count,alu_prefetch_hit_count,
 output logic debug_entry0_valid,debug_entry1_valid,output logic [4:0] debug_entry0_addr,debug_entry1_addr,
 output logic [127:0] debug_entry0_data,debug_entry1_data,output logic debug_pending_read_valid
);
 localparam int PCW=(PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH);
 typedef enum logic [1:0] {S_EXEC,S_LOAD_WB} state_t; state_t state;
 logic [15:0] instruction,next_instruction,next2_instruction,next3_instruction,next4_instruction;
 logic [3:0] alu_op; logic [2:0] src_a,src_b,dst; logic [4:0] mem_addr,active_length,pending_read_addr;
 logic valid,is_alu,is_vload,is_vstore; logic [2:0] load_dst; logic [127:0] mem_read_data,alu_result;
 logic mem_read_enable,mem_write_enable,core_reg_write,core_load_write; logic [4:0] mem_read_addr,mem_write_addr; logic [127:0] mem_write_data;
 logic entry0_valid,entry1_valid,entry0_from_alu,entry1_from_alu; logic [4:0] entry0_addr,entry1_addr; logic [127:0] entry0_data,entry1_data;
 logic pending_read_valid,pending_read_slot,pending_discard,prefetch_issue,prefetch_hit0,prefetch_hit1,prefetch_hit;
 logic [4:0] candidate_addr; logic candidate_valid,candidate_slot; logic c1,c2,c3,c4; logic architectural_read_request;
 logic slot0_available,slot1_available,free_slot_valid;
 logic [3:0] next_pc; logic next_valid,next_is_vload,next_is_vstore,next2_valid,next2_is_vload,next2_is_vstore,next3_valid,next3_is_vload,next3_is_vstore,next4_valid,next4_is_vload,next4_is_vstore;
 logic [4:0] next_mem_addr,next2_mem_addr,next3_mem_addr,next4_mem_addr;
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) pim(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc),.read_data(instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+1'b1),.read_data(next_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look2(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+2'd2),.read_data(next2_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look3(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+2'd3),.read_data(next3_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look4(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+3'd4),.read_data(next4_instruction));
 vector_memory_instruction_decoder dec(.instruction(instruction),.alu_op(alu_op),.src_a(src_a),.src_b(src_b),.dst(dst),.mem_addr(mem_addr),.instruction_valid(valid),.is_alu(is_alu),.is_vload(is_vload),.is_vstore(is_vstore));
 vector_memory_instruction_decoder ndec(.instruction(next_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next_mem_addr),.instruction_valid(next_valid),.is_alu(),.is_vload(next_is_vload),.is_vstore(next_is_vstore));
 vector_memory_instruction_decoder ndec2(.instruction(next2_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next2_mem_addr),.instruction_valid(next2_valid),.is_alu(),.is_vload(next2_is_vload),.is_vstore(next2_is_vstore));
 vector_memory_instruction_decoder ndec3(.instruction(next3_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next3_mem_addr),.instruction_valid(next3_valid),.is_alu(),.is_vload(next3_is_vload),.is_vstore(next3_is_vstore));
 vector_memory_instruction_decoder ndec4(.instruction(next4_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next4_mem_addr),.instruction_valid(next4_valid),.is_alu(),.is_vload(next4_is_vload),.is_vstore(next4_is_vstore));
 assign current_instruction=instruction; assign current_instruction_valid=valid; assign state_debug={2'b00,state};
 assign prefetch_hit0=is_vload&&entry0_valid&&(entry0_addr==mem_addr); assign prefetch_hit1=is_vload&&entry1_valid&&(entry1_addr==mem_addr); assign prefetch_hit=prefetch_hit0||prefetch_hit1;
 // A current store cannot prefetch its own address; ALU instructions have no memory address dependency.
 assign c1=(current_pc+1'b1<active_length)&&next_valid&&next_is_vload&&(!is_vstore||(next_mem_addr!=mem_addr))&&!(entry0_valid&&entry0_addr==next_mem_addr)&&!(entry1_valid&&entry1_addr==next_mem_addr)&&!(pending_read_valid&&pending_read_addr==next_mem_addr);
 assign c2=(current_pc+2'd2<active_length)&&next2_valid&&next2_is_vload&&(!is_vstore||(next2_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next2_mem_addr)&&!(entry0_valid&&entry0_addr==next2_mem_addr)&&!(entry1_valid&&entry1_addr==next2_mem_addr)&&!(pending_read_valid&&pending_read_addr==next2_mem_addr);
 assign c3=(current_pc+2'd3<active_length)&&next3_valid&&next3_is_vload&&(!is_vstore||(next3_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next3_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next3_mem_addr)&&!(entry0_valid&&entry0_addr==next3_mem_addr)&&!(entry1_valid&&entry1_addr==next3_mem_addr)&&!(pending_read_valid&&pending_read_addr==next3_mem_addr);
 assign c4=(current_pc+3'd4<active_length)&&next4_valid&&next4_is_vload&&(!is_vstore||(next4_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next4_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next4_mem_addr)&&!(next3_valid&&next3_is_vstore&&next3_mem_addr==next4_mem_addr)&&!(entry0_valid&&entry0_addr==next4_mem_addr)&&!(entry1_valid&&entry1_addr==next4_mem_addr)&&!(pending_read_valid&&pending_read_addr==next4_mem_addr);
 assign candidate_valid=running&&state==S_EXEC&&valid&&(is_vstore||is_alu)&&!pending_read_valid&&(c1||c2||c3||c4);
 assign candidate_addr=c1?next_mem_addr:c2?next2_mem_addr:c3?next3_mem_addr:next4_mem_addr;
 assign candidate_slot=!entry0_valid?1'b0:1'b1;
 assign slot0_available=!entry0_valid&&!(pending_read_valid&&!pending_read_slot);
 assign slot1_available=!entry1_valid&&!(pending_read_valid&&pending_read_slot);
 assign free_slot_valid=slot0_available||slot1_available;
 assign prefetch_issue=candidate_valid&&free_slot_valid&&!(entry0_valid&&entry0_addr==candidate_addr)&&!(entry1_valid&&entry1_addr==candidate_addr);
 assign architectural_read_request=running&&state==S_EXEC&&is_vload&&!prefetch_hit;
 assign mem_read_enable=architectural_read_request||prefetch_issue||(!running&&data_debug_read_enable);
 assign mem_read_addr=(running&&state==S_EXEC&&is_vload&&!prefetch_hit)?mem_addr:(prefetch_issue?candidate_addr:data_debug_read_addr);
 assign mem_write_enable=(running&&state==S_EXEC&&is_vstore)||(!running&&data_load_enable); assign mem_write_addr=(running&&state==S_EXEC&&is_vstore)?mem_addr:data_load_addr; assign mem_write_data=(running&&state==S_EXEC&&is_vstore)?debug_read_data:data_load_data;
 vector_data_memory #(.DEPTH(DATA_DEPTH)) dm(.clk(clk),.read_enable(mem_read_enable),.read_addr(mem_read_addr),.read_data(mem_read_data),.write_enable(mem_write_enable),.write_addr(mem_write_addr),.write_data(mem_write_data)); assign data_debug_read_data=mem_read_data;
 assign core_reg_write=running&&state==S_EXEC&&is_alu; assign core_load_write=running&&state==S_EXEC&&prefetch_hit;
 vector_execution_unit eu(.clk(clk),.rst(rst),.src_a((debug_read_enable&&!running)?debug_read_addr:src_a),.src_b(src_b),.dst((state==S_LOAD_WB)?load_dst:dst),.alu_op(alu_op),.execute_enable(core_reg_write),.load_enable((!running&&vector_load_enable)||(running&&(state==S_LOAD_WB||core_load_write))),.load_addr((!running&&vector_load_enable)?vector_load_addr:((state==S_LOAD_WB)?load_dst:dst)),.load_data((!running&&vector_load_enable)?vector_load_data:(prefetch_hit0?entry0_data:prefetch_hit1?entry1_data:mem_read_data)),.debug_read_enable(debug_read_enable&&!running),.debug_read_addr(debug_read_addr),.debug_read_data(debug_read_data),.alu_result(alu_result));
 assign debug_entry0_valid=entry0_valid; assign debug_entry1_valid=entry1_valid; assign debug_entry0_addr=entry0_addr; assign debug_entry1_addr=entry1_addr; assign debug_entry0_data=entry0_data; assign debug_entry1_data=entry1_data; assign debug_pending_read_valid=pending_read_valid;
 always_ff @(posedge clk) begin
  if(rst) begin current_pc<='0;running<=0;done<=0;active_length<='0;load_dst<='0;state<=S_EXEC;entry0_valid<=0;entry1_valid<=0;entry0_from_alu<=0;entry1_from_alu<=0;pending_read_valid<=0;pending_discard<=0;prefetch_request_count<=0;prefetch_hit_count<=0;prefetch_miss_count<=0;entry0_hit_count<=0;entry1_hit_count<=0;overlap_alu_count<=0;overlap_store_count<=0;alu_read_overlap_count<=0;alu_prefetch_hit_count<=0;dependency_blocked_count<=0;entry0_fill_count<=0;entry1_fill_count<=0;duplicate_suppression_count<=0;end
  else begin
   if(!running&&(data_load_enable||data_debug_read_enable)) begin entry0_valid<=0;entry1_valid<=0;entry0_from_alu<=0;entry1_from_alu<=0;pending_read_valid<=0;end
   if(pending_read_valid) begin pending_read_valid<=0;if(!pending_discard)begin if(!pending_read_slot)begin entry0_data<=mem_read_data;entry0_addr<=pending_read_addr;entry0_valid<=1;entry0_fill_count<=entry0_fill_count+1'b1;end else begin entry1_data<=mem_read_data;entry1_addr<=pending_read_addr;entry1_valid<=1;entry1_fill_count<=entry1_fill_count+1'b1;end end pending_discard<=0;end
   if(prefetch_issue) begin pending_read_valid<=1;pending_read_addr<=candidate_addr;pending_read_slot<=candidate_slot;prefetch_request_count<=prefetch_request_count+1'b1;if(!candidate_slot)entry0_from_alu<=is_alu;else entry1_from_alu<=is_alu;if(is_alu)begin overlap_alu_count<=overlap_alu_count+1'b1;alu_read_overlap_count<=alu_read_overlap_count+1'b1;end else overlap_store_count<=overlap_store_count+1'b1;end
   if(running&&state==S_EXEC&&is_vstore&&!prefetch_issue&&candidate_valid) duplicate_suppression_count<=duplicate_suppression_count+1'b1;
   if(running&&state==S_EXEC&&is_vstore)begin if(entry0_valid&&entry0_addr==mem_addr)entry0_valid<=0;if(entry1_valid&&entry1_addr==mem_addr)entry1_valid<=0;if(pending_read_valid&&pending_read_addr==mem_addr)pending_discard<=1;end
   if(prefetch_hit&&is_alu) ;
   if(!running)begin if(start)begin current_pc<='0;entry0_valid<=0;entry1_valid<=0;entry0_from_alu<=0;entry1_from_alu<=0;pending_read_valid<=0;prefetch_request_count<=0;prefetch_hit_count<=0;prefetch_miss_count<=0;entry0_hit_count<=0;entry1_hit_count<=0;overlap_alu_count<=0;overlap_store_count<=0;alu_read_overlap_count<=0;alu_prefetch_hit_count<=0;dependency_blocked_count<=0;entry0_fill_count<=0;entry1_fill_count<=0;duplicate_suppression_count<=0;if(program_length==0||program_length>PROGRAM_DEPTH)begin running<=0;done<=1;end else begin active_length<=program_length;running<=1;done<=0;state<=S_EXEC;end end end
   else if(state==S_LOAD_WB)begin if(current_pc==active_length-1)begin running<=0;done<=1;entry0_valid<=0;entry1_valid<=0;end else begin current_pc<=current_pc+1'b1;state<=S_EXEC;end end
   else if(is_vload)begin if(prefetch_hit)begin prefetch_hit_count<=prefetch_hit_count+1'b1;if(prefetch_hit0)begin entry0_hit_count<=entry0_hit_count+1'b1;if(entry0_from_alu)alu_prefetch_hit_count<=alu_prefetch_hit_count+1'b1;entry0_valid<=0;end else begin entry1_hit_count<=entry1_hit_count+1'b1;if(entry1_from_alu)alu_prefetch_hit_count<=alu_prefetch_hit_count+1'b1;entry1_valid<=0;end if(current_pc==active_length-1)begin running<=0;done<=1;end else current_pc<=current_pc+1'b1;end else begin load_dst<=dst;state<=S_LOAD_WB;prefetch_miss_count<=prefetch_miss_count+1'b1;end end
   else if(current_pc==active_length-1)begin running<=0;done<=1;entry0_valid<=0;entry1_valid<=0;end else current_pc<=current_pc+1'b1;
  end
 end
endmodule
