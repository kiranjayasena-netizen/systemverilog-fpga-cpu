// Stage 14: dependency-aware VLOAD miss writeback/read overlap derived from frozen Stage 12.
// The Stage 10A source is intentionally left unchanged; this is an independent core.
module vector_load_overlap_program_core #(
 parameter int unsigned PROGRAM_DEPTH=16, DATA_DEPTH=32, LOOKAHEAD_DEPTH=6
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
 output logic [31:0] outstanding_read_high_watermark,cycles_with_two_outstanding,second_request_while_first_pending_count,pending0_stale_discard_count,pending1_stale_discard_count,two_outstanding_useful_pair_count,deep_prefetch_request_count,deep_prefetch_hit_count,max_lookahead_distance,
 output logic [31:0] load_writeback_overlap_count,load_writeback_cycles_saved,blocked_by_dependency_count,blocked_by_rf_write_conflict_count,successful_overlap_count,rf_double_write_attempt_count,
 output logic debug_entry0_valid,debug_entry1_valid,output logic [4:0] debug_entry0_addr,debug_entry1_addr,
 output logic [127:0] debug_entry0_data,debug_entry1_data,output logic debug_pending_read_valid
);
 localparam int PCW=(PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH);
 typedef enum logic [1:0] {S_EXEC,S_LOAD_WB} state_t; state_t state;
 logic [15:0] instruction,next_instruction,next2_instruction,next3_instruction,next4_instruction,next5_instruction,next6_instruction,next7_instruction,next8_instruction;
 logic [3:0] alu_op; logic [2:0] src_a,src_b,dst; logic [4:0] mem_addr,active_length;
 logic valid,is_alu,is_vload,is_vstore; logic [2:0] load_dst; logic [127:0] mem_read_data,alu_result; logic [2:0] next_dst,next_src_a,next_src_b;
 logic mem_read_enable,mem_write_enable,core_reg_write,core_load_write; logic [4:0] mem_read_addr,mem_write_addr; logic [127:0] mem_write_data;
 logic entry0_valid,entry1_valid,entry0_from_alu,entry1_from_alu; logic [4:0] entry0_addr,entry1_addr; logic [127:0] entry0_data,entry1_data;
 logic pending0_valid,pending1_valid,pending0_slot,pending1_slot,pending0_discard,pending1_discard;
  logic [4:0] pending0_addr,pending1_addr; logic pending0_from_alu,pending1_from_alu; logic [3:0] pending0_distance,pending1_distance; logic pair_active,pair_hit_seen;
 logic prefetch_issue,prefetch_hit0,prefetch_hit1,prefetch_hit; logic [1:0] outstanding_count; logic response0_due;
  logic [4:0] candidate_addr; logic candidate_valid,candidate_slot; logic c1,c2,c3,c4,c5,c6,c7,c8; logic [3:0] candidate_distance; logic architectural_read_request;
 logic store_kill_pending0,store_kill_pending1,external_invalidation,load_wb_overlap_issue,load_wb_overlap_active;
 logic slot0_available,slot1_available,free_slot_valid;
 logic [3:0] next_pc; logic next_valid,next_is_alu,next_is_vload,next_is_vstore,next2_valid,next2_is_vload,next2_is_vstore,next3_valid,next3_is_vload,next3_is_vstore,next4_valid,next4_is_vload,next4_is_vstore,next5_valid,next5_is_vload,next5_is_vstore,next6_valid,next6_is_vload,next6_is_vstore,next7_valid,next7_is_vload,next7_is_vstore,next8_valid,next8_is_vload,next8_is_vstore;
 logic [4:0] next_mem_addr,next2_mem_addr,next3_mem_addr,next4_mem_addr,next5_mem_addr,next6_mem_addr,next7_mem_addr,next8_mem_addr;
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) pim(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc),.read_data(instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+1'b1),.read_data(next_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look2(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+2'd2),.read_data(next2_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look3(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+2'd3),.read_data(next3_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look4(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+3'd4),.read_data(next4_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look5(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+3'd5),.read_data(next5_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look6(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+3'd6),.read_data(next6_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look7(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+3'd7),.read_data(next7_instruction));
 vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) look8(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc+4'd8),.read_data(next8_instruction));
 vector_memory_instruction_decoder dec(.instruction(instruction),.alu_op(alu_op),.src_a(src_a),.src_b(src_b),.dst(dst),.mem_addr(mem_addr),.instruction_valid(valid),.is_alu(is_alu),.is_vload(is_vload),.is_vstore(is_vstore));
  vector_memory_instruction_decoder ndec(.instruction(next_instruction),.alu_op(),.src_a(next_src_a),.src_b(next_src_b),.dst(next_dst),.mem_addr(next_mem_addr),.instruction_valid(next_valid),.is_alu(next_is_alu),.is_vload(next_is_vload),.is_vstore(next_is_vstore));
 vector_memory_instruction_decoder ndec2(.instruction(next2_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next2_mem_addr),.instruction_valid(next2_valid),.is_alu(),.is_vload(next2_is_vload),.is_vstore(next2_is_vstore));
 vector_memory_instruction_decoder ndec3(.instruction(next3_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next3_mem_addr),.instruction_valid(next3_valid),.is_alu(),.is_vload(next3_is_vload),.is_vstore(next3_is_vstore));
 vector_memory_instruction_decoder ndec4(.instruction(next4_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next4_mem_addr),.instruction_valid(next4_valid),.is_alu(),.is_vload(next4_is_vload),.is_vstore(next4_is_vstore));
 vector_memory_instruction_decoder ndec5(.instruction(next5_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next5_mem_addr),.instruction_valid(next5_valid),.is_alu(),.is_vload(next5_is_vload),.is_vstore(next5_is_vstore));
 vector_memory_instruction_decoder ndec6(.instruction(next6_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next6_mem_addr),.instruction_valid(next6_valid),.is_alu(),.is_vload(next6_is_vload),.is_vstore(next6_is_vstore));
 vector_memory_instruction_decoder ndec7(.instruction(next7_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next7_mem_addr),.instruction_valid(next7_valid),.is_alu(),.is_vload(next7_is_vload),.is_vstore(next7_is_vstore));
 vector_memory_instruction_decoder ndec8(.instruction(next8_instruction),.alu_op(),.src_a(),.src_b(),.dst(),.mem_addr(next8_mem_addr),.instruction_valid(next8_valid),.is_alu(),.is_vload(next8_is_vload),.is_vstore(next8_is_vstore));
 assign current_instruction=instruction; assign current_instruction_valid=valid; assign state_debug={2'b00,state};
 assign prefetch_hit0=is_vload&&entry0_valid&&(entry0_addr==mem_addr); assign prefetch_hit1=is_vload&&entry1_valid&&(entry1_addr==mem_addr); assign prefetch_hit=prefetch_hit0||prefetch_hit1;
 // A current store cannot prefetch its own address; ALU instructions have no memory address dependency.
 assign c1=(current_pc+1'b1<active_length)&&next_valid&&next_is_vload&&(!is_vstore||(next_mem_addr!=mem_addr))&&!(entry0_valid&&entry0_addr==next_mem_addr)&&!(entry1_valid&&entry1_addr==next_mem_addr)&&!(pending0_valid&&pending0_addr==next_mem_addr)&&!(pending1_valid&&pending1_addr==next_mem_addr);
 assign c2=(current_pc+2'd2<active_length)&&next2_valid&&next2_is_vload&&(!is_vstore||(next2_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next2_mem_addr)&&!(entry0_valid&&entry0_addr==next2_mem_addr)&&!(entry1_valid&&entry1_addr==next2_mem_addr)&&!(pending0_valid&&pending0_addr==next2_mem_addr)&&!(pending1_valid&&pending1_addr==next2_mem_addr);
 assign c3=(current_pc+2'd3<active_length)&&next3_valid&&next3_is_vload&&(!is_vstore||(next3_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next3_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next3_mem_addr)&&!(entry0_valid&&entry0_addr==next3_mem_addr)&&!(entry1_valid&&entry1_addr==next3_mem_addr)&&!(pending0_valid&&pending0_addr==next3_mem_addr)&&!(pending1_valid&&pending1_addr==next3_mem_addr);
 assign c4=(current_pc+3'd4<active_length)&&next4_valid&&next4_is_vload&&(!is_vstore||(next4_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next4_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next4_mem_addr)&&!(next3_valid&&next3_is_vstore&&next3_mem_addr==next4_mem_addr)&&!(entry0_valid&&entry0_addr==next4_mem_addr)&&!(entry1_valid&&entry1_addr==next4_mem_addr)&&!(pending0_valid&&pending0_addr==next4_mem_addr)&&!(pending1_valid&&pending1_addr==next4_mem_addr);
assign c5=(LOOKAHEAD_DEPTH>=5)&&(current_pc+3'd5<active_length)&&next5_valid&&next5_is_vload&&(!is_vstore||(next5_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next5_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next5_mem_addr)&&!(next3_valid&&next3_is_vstore&&next3_mem_addr==next5_mem_addr)&&!(next4_valid&&next4_is_vstore&&next4_mem_addr==next5_mem_addr)&&!(entry0_valid&&entry0_addr==next5_mem_addr)&&!(entry1_valid&&entry1_addr==next5_mem_addr)&&!(pending0_valid&&pending0_addr==next5_mem_addr)&&!(pending1_valid&&pending1_addr==next5_mem_addr);
assign c6=(LOOKAHEAD_DEPTH>=6)&&(current_pc+3'd6<active_length)&&next6_valid&&next6_is_vload&&(!is_vstore||(next6_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next6_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next6_mem_addr)&&!(next3_valid&&next3_is_vstore&&next3_mem_addr==next6_mem_addr)&&!(next4_valid&&next4_is_vstore&&next4_mem_addr==next6_mem_addr)&&!(next5_valid&&next5_is_vstore&&next5_mem_addr==next6_mem_addr)&&!(entry0_valid&&entry0_addr==next6_mem_addr)&&!(entry1_valid&&entry1_addr==next6_mem_addr)&&!(pending0_valid&&pending0_addr==next6_mem_addr)&&!(pending1_valid&&pending1_addr==next6_mem_addr);
assign c7=(LOOKAHEAD_DEPTH>=7)&&(current_pc+3'd7<active_length)&&next7_valid&&next7_is_vload&&(!is_vstore||(next7_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next7_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next7_mem_addr)&&!(next3_valid&&next3_is_vstore&&next3_mem_addr==next7_mem_addr)&&!(next4_valid&&next4_is_vstore&&next4_mem_addr==next7_mem_addr)&&!(next5_valid&&next5_is_vstore&&next5_mem_addr==next7_mem_addr)&&!(next6_valid&&next6_is_vstore&&next6_mem_addr==next7_mem_addr)&&!(entry0_valid&&entry0_addr==next7_mem_addr)&&!(entry1_valid&&entry1_addr==next7_mem_addr)&&!(pending0_valid&&pending0_addr==next7_mem_addr)&&!(pending1_valid&&pending1_addr==next7_mem_addr);
assign c8=(LOOKAHEAD_DEPTH>=8)&&(current_pc+4'd8<active_length)&&next8_valid&&next8_is_vload&&(!is_vstore||(next8_mem_addr!=mem_addr))&&!(next_valid&&next_is_vstore&&next_mem_addr==next8_mem_addr)&&!(next2_valid&&next2_is_vstore&&next2_mem_addr==next8_mem_addr)&&!(next3_valid&&next3_is_vstore&&next3_mem_addr==next8_mem_addr)&&!(next4_valid&&next4_is_vstore&&next4_mem_addr==next8_mem_addr)&&!(next5_valid&&next5_is_vstore&&next5_mem_addr==next8_mem_addr)&&!(next6_valid&&next6_is_vstore&&next6_mem_addr==next8_mem_addr)&&!(next7_valid&&next7_is_vstore&&next7_mem_addr==next8_mem_addr)&&!(entry0_valid&&entry0_addr==next8_mem_addr)&&!(entry1_valid&&entry1_addr==next8_mem_addr)&&!(pending0_valid&&pending0_addr==next8_mem_addr)&&!(pending1_valid&&pending1_addr==next8_mem_addr);
 assign candidate_valid=running&&state==S_EXEC&&valid&&(is_vstore||is_alu)&&(c1||c2||c3||c4||c5||c6||c7||c8);
 assign candidate_addr=c1?next_mem_addr:c2?next2_mem_addr:c3?next3_mem_addr:c4?next4_mem_addr:c5?next5_mem_addr:c6?next6_mem_addr:c7?next7_mem_addr:next8_mem_addr;
 assign candidate_distance=c1?4'd1:c2?4'd2:c3?4'd3:c4?4'd4:c5?4'd5:c6?4'd6:c7?4'd7:c8?4'd8:4'd0;
 assign candidate_slot=slot0_available?1'b0:1'b1;
 assign slot0_available=!entry0_valid&&!(pending0_valid&&pending0_slot==1'b0)&&!(pending1_valid&&pending1_slot==1'b0);
 assign slot1_available=!entry1_valid&&!(pending0_valid&&pending0_slot==1'b1)&&!(pending1_valid&&pending1_slot==1'b1);
 assign outstanding_count={1'b0,pending0_valid}+{1'b0,pending1_valid};
 assign response0_due=pending0_valid;
 assign free_slot_valid=slot0_available||slot1_available;
 assign prefetch_issue=candidate_valid&&free_slot_valid&&(outstanding_count<2)&&!architectural_read_request;
  assign architectural_read_request=running&&state==S_EXEC&&is_vload&&!prefetch_hit;
  assign store_kill_pending0=running&&state==S_EXEC&&is_vstore&&pending0_valid&&(pending0_addr==mem_addr);
  assign store_kill_pending1=running&&state==S_EXEC&&is_vstore&&pending1_valid&&(pending1_addr==mem_addr);
  assign external_invalidation=!running&&(data_load_enable||data_debug_read_enable);
  assign load_wb_overlap_issue=running&&state==S_LOAD_WB&&!load_wb_overlap_active&&(current_pc+1'b1<active_length)&&next_valid&&next_is_vload&&!(entry0_valid&&entry0_addr==next_mem_addr)&&!(entry1_valid&&entry1_addr==next_mem_addr)&&!(pending0_valid&&pending0_addr==next_mem_addr)&&!(pending1_valid&&pending1_addr==next_mem_addr);
 assign mem_read_enable=architectural_read_request||prefetch_issue||load_wb_overlap_issue||(!running&&data_debug_read_enable);
 assign mem_read_addr=(running&&state==S_EXEC&&is_vload&&!prefetch_hit)?mem_addr:(load_wb_overlap_issue?next_mem_addr:(prefetch_issue?candidate_addr:data_debug_read_addr));
 assign mem_write_enable=(running&&state==S_EXEC&&is_vstore)||(!running&&data_load_enable); assign mem_write_addr=(running&&state==S_EXEC&&is_vstore)?mem_addr:data_load_addr; assign mem_write_data=(running&&state==S_EXEC&&is_vstore)?debug_read_data:data_load_data;
 vector_data_memory #(.DEPTH(DATA_DEPTH)) dm(.clk(clk),.read_enable(mem_read_enable),.read_addr(mem_read_addr),.read_data(mem_read_data),.write_enable(mem_write_enable),.write_addr(mem_write_addr),.write_data(mem_write_data)); assign data_debug_read_data=mem_read_data;
 assign core_reg_write=running&&state==S_EXEC&&is_alu; assign core_load_write=running&&state==S_EXEC&&prefetch_hit;
 vector_execution_unit eu(.clk(clk),.rst(rst),.src_a((debug_read_enable&&!running)?debug_read_addr:src_a),.src_b(src_b),.dst((state==S_LOAD_WB)?load_dst:dst),.alu_op(alu_op),.execute_enable(core_reg_write),.load_enable((!running&&vector_load_enable)||(running&&(state==S_LOAD_WB||core_load_write))),.load_addr((!running&&vector_load_enable)?vector_load_addr:((state==S_LOAD_WB)?load_dst:dst)),.load_data((!running&&vector_load_enable)?vector_load_data:(prefetch_hit0?entry0_data:prefetch_hit1?entry1_data:mem_read_data)),.debug_read_enable(debug_read_enable&&!running),.debug_read_addr(debug_read_addr),.debug_read_data(debug_read_data),.alu_result(alu_result));
 assign debug_entry0_valid=entry0_valid; assign debug_entry1_valid=entry1_valid; assign debug_entry0_addr=entry0_addr; assign debug_entry1_addr=entry1_addr; assign debug_entry0_data=entry0_data; assign debug_entry1_data=entry1_data; assign debug_pending_read_valid=pending0_valid||pending1_valid;
 always_ff @(posedge clk) begin
  if (rst) begin
   current_pc<='0; running<=0; done<=0; active_length<='0; load_dst<='0; state<=S_EXEC;
   entry0_valid<=0; entry1_valid<=0; entry0_from_alu<=0; entry1_from_alu<=0;
   pending0_valid<=0; pending1_valid<=0; pending0_discard<=0; pending1_discard<=0;
   pending0_addr<='0; pending1_addr<='0; pending0_slot<=0; pending1_slot<=0;
   pending0_from_alu<=0; pending1_from_alu<=0; pending0_distance<=0; pending1_distance<=0;
   prefetch_request_count<=0; prefetch_hit_count<=0; prefetch_miss_count<=0;
   entry0_hit_count<=0; entry1_hit_count<=0; overlap_alu_count<=0; overlap_store_count<=0;
   alu_read_overlap_count<=0; alu_prefetch_hit_count<=0; dependency_blocked_count<=0;
   entry0_fill_count<=0; entry1_fill_count<=0; duplicate_suppression_count<=0;
   outstanding_read_high_watermark<=0; cycles_with_two_outstanding<=0;
   second_request_while_first_pending_count<=0; pending0_stale_discard_count<=0;
   pending1_stale_discard_count<=0; two_outstanding_useful_pair_count<=0; pair_active<=0; pair_hit_seen<=0;
   deep_prefetch_request_count<=0; deep_prefetch_hit_count<=0; max_lookahead_distance<=0;
   load_wb_overlap_active<=0; load_writeback_overlap_count<=0; load_writeback_cycles_saved<=0; blocked_by_dependency_count<=0; blocked_by_rf_write_conflict_count<=0; successful_overlap_count<=0; rf_double_write_attempt_count<=0;
  end else begin
   if (!running && (data_load_enable || data_debug_read_enable)) begin
    entry0_valid<=0; entry1_valid<=0; entry0_from_alu<=0; entry1_from_alu<=0;
    pending0_valid<=0; pending1_valid<=0; pending0_discard<=0; pending1_discard<=0; load_wb_overlap_active<=0;
   end

   // Fixed one-cycle synchronous memory response: FIFO head returns now.
   if (pending0_valid) begin
     if (pending0_discard || store_kill_pending0 || external_invalidation) begin
     pending0_stale_discard_count<=pending0_stale_discard_count+1'b1;
    end else begin
     if (!pending0_slot) begin
      entry0_data<=mem_read_data; entry0_addr<=pending0_addr; entry0_valid<=1;
      entry0_from_alu<=pending0_from_alu; entry0_fill_count<=entry0_fill_count+1'b1;
     end else begin
      entry1_data<=mem_read_data; entry1_addr<=pending0_addr; entry1_valid<=1;
      entry1_from_alu<=pending0_from_alu; entry1_fill_count<=entry1_fill_count+1'b1;
     end
    end
    pending0_valid<=pending1_valid; pending0_addr<=pending1_addr; pending0_slot<=pending1_slot;
     pending0_discard<=pending1_discard || store_kill_pending1 || external_invalidation; pending0_from_alu<=pending1_from_alu; pending0_distance<=pending1_distance;
    pending1_valid<=0; pending1_discard<=0;
   end

   if (!pending0_valid && pending1_valid) begin
    pending0_valid<=1; pending0_addr<=pending1_addr; pending0_slot<=pending1_slot;
     pending0_discard<=pending1_discard || store_kill_pending1 || external_invalidation; pending0_from_alu<=pending1_from_alu; pending0_distance<=pending1_distance;
    pending1_valid<=0; pending1_discard<=0;
   end

   if (prefetch_issue) begin
    if (pending0_valid) begin
     pending1_valid<=1; pending1_addr<=candidate_addr; pending1_slot<=candidate_slot;
     pending1_discard<=0; pending1_from_alu<=is_alu; pending1_distance<=candidate_distance;
     second_request_while_first_pending_count<=second_request_while_first_pending_count+1'b1; pair_active<=1; pair_hit_seen<=0;
    end else begin
     pending0_valid<=1; pending0_addr<=candidate_addr; pending0_slot<=candidate_slot;
     pending0_discard<=0; pending0_from_alu<=is_alu; pending0_distance<=candidate_distance;
    end
    prefetch_request_count<=prefetch_request_count+1'b1;
    if (candidate_distance>4) begin
     deep_prefetch_request_count<=deep_prefetch_request_count+1'b1;
     if (candidate_distance>max_lookahead_distance) max_lookahead_distance<=candidate_distance;
    end
    if (is_alu) begin overlap_alu_count<=overlap_alu_count+1'b1; alu_read_overlap_count<=alu_read_overlap_count+1'b1; end
    else overlap_store_count<=overlap_store_count+1'b1;
   end

    if (prefetch_hit && pair_active) begin
     if (!pair_hit_seen) pair_hit_seen<=1;
     else begin two_outstanding_useful_pair_count<=two_outstanding_useful_pair_count+1'b1; pair_active<=0; pair_hit_seen<=0; end
    end

    if (pending0_valid && prefetch_issue) begin
    // The second request is accepted while request 0 is still in flight;
    // this is the two-outstanding state at the request boundary.
    if (outstanding_read_high_watermark<2) outstanding_read_high_watermark<=2;
    cycles_with_two_outstanding<=cycles_with_two_outstanding+1'b1;
   end else if (pending0_valid && pending1_valid) begin
    cycles_with_two_outstanding<=cycles_with_two_outstanding+1'b1;
    if (outstanding_read_high_watermark<2) outstanding_read_high_watermark<=2;
   end else if (pending0_valid || pending1_valid) begin
    if (outstanding_read_high_watermark<1) outstanding_read_high_watermark<=1;
   end

   if (running && state==S_EXEC && is_vstore && !prefetch_issue && candidate_valid)
    duplicate_suppression_count<=duplicate_suppression_count+1'b1;

   if (running && state==S_EXEC && is_vstore) begin
    if (entry0_valid && entry0_addr==mem_addr) entry0_valid<=0;
    if (entry1_valid && entry1_addr==mem_addr) entry1_valid<=0;
    if (pending0_valid && pending0_addr==mem_addr) pending0_discard<=1;
    if (pending1_valid && pending1_addr==mem_addr) pending1_discard<=1;
   end

   if (running && state==S_LOAD_WB && !load_wb_overlap_issue && next_valid && next_is_alu) begin
    if ((next_src_a==load_dst)||(next_src_b==load_dst)) blocked_by_dependency_count<=blocked_by_dependency_count+1'b1;
    else blocked_by_rf_write_conflict_count<=blocked_by_rf_write_conflict_count+1'b1;
   end

   if (!running) begin
    if (start) begin
     current_pc<='0; entry0_valid<=0; entry1_valid<=0; entry0_from_alu<=0; entry1_from_alu<=0;
     pending0_valid<=0; pending1_valid<=0; pending0_discard<=0; pending1_discard<=0;
     prefetch_request_count<=0; prefetch_hit_count<=0; prefetch_miss_count<=0; entry0_hit_count<=0; entry1_hit_count<=0;
     overlap_alu_count<=0; overlap_store_count<=0; alu_read_overlap_count<=0; alu_prefetch_hit_count<=0;
     dependency_blocked_count<=0; entry0_fill_count<=0; entry1_fill_count<=0; duplicate_suppression_count<=0;
     outstanding_read_high_watermark<=0; cycles_with_two_outstanding<=0; second_request_while_first_pending_count<=0;
     pending0_stale_discard_count<=0; pending1_stale_discard_count<=0; two_outstanding_useful_pair_count<=0; pair_active<=0; pair_hit_seen<=0;
      deep_prefetch_request_count<=0; deep_prefetch_hit_count<=0; max_lookahead_distance<=0;
      load_wb_overlap_active<=0; load_writeback_overlap_count<=0; load_writeback_cycles_saved<=0; blocked_by_dependency_count<=0; blocked_by_rf_write_conflict_count<=0; successful_overlap_count<=0; rf_double_write_attempt_count<=0;
     if (program_length==0 || program_length>PROGRAM_DEPTH) begin running<=0; done<=1; end
     else begin active_length<=program_length; running<=1; done<=0; state<=S_EXEC; end
    end
    end else if (state==S_LOAD_WB) begin
     if (load_wb_overlap_issue) begin
      // Current load writes the sole RF port; the otherwise idle memory port
      // issues the following independent VLOAD. No second RF write occurs.
      load_wb_overlap_active<=1; load_dst<=next_dst; current_pc<=current_pc+1'b1; state<=S_LOAD_WB;
      load_writeback_overlap_count<=load_writeback_overlap_count+1'b1; load_writeback_cycles_saved<=load_writeback_cycles_saved+1'b1; successful_overlap_count<=successful_overlap_count+1'b1; prefetch_miss_count<=prefetch_miss_count+1'b1;
     end else if (load_wb_overlap_active) begin
      load_wb_overlap_active<=0;
      if (current_pc==active_length-1) begin running<=0; done<=1; entry0_valid<=0; entry1_valid<=0; end
      else begin current_pc<=current_pc+1'b1; state<=S_EXEC; end
     end else if (current_pc==active_length-1) begin running<=0; done<=1; entry0_valid<=0; entry1_valid<=0; end
     else begin current_pc<=current_pc+1'b1; state<=S_EXEC; end
   end else if (is_vload) begin
    if (prefetch_hit) begin
     prefetch_hit_count<=prefetch_hit_count+1'b1;
     if (prefetch_hit0) begin
      entry0_hit_count<=entry0_hit_count+1'b1;
      if (entry0_from_alu) begin alu_prefetch_hit_count<=alu_prefetch_hit_count+1'b1; if (entry0_from_alu && entry0_addr==candidate_addr) deep_prefetch_hit_count<=deep_prefetch_hit_count+1'b1; end
      entry0_valid<=0;
     end else begin
      entry1_hit_count<=entry1_hit_count+1'b1;
      if (entry1_from_alu) alu_prefetch_hit_count<=alu_prefetch_hit_count+1'b1;
      entry1_valid<=0;
     end
     if (current_pc==active_length-1) begin running<=0; done<=1; end else current_pc<=current_pc+1'b1;
    end else begin load_dst<=dst; state<=S_LOAD_WB; prefetch_miss_count<=prefetch_miss_count+1'b1; end
   end else if (current_pc==active_length-1) begin running<=0; done<=1; entry0_valid<=0; entry1_valid<=0; end
   else current_pc<=current_pc+1'b1;
  end
 end
endmodule
