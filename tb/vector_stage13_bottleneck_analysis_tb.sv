`timescale 1ns/1ps
module vector_stage13_bottleneck_analysis_tb;
  logic clk=0,rst=0,start=0; always #5 clk=~clk;
  logic [4:0] program_length; logic running,done; logic [3:0] current_pc; logic [15:0] current_instruction; logic current_instruction_valid;
  logic pe=0; logic [3:0] pa; logic [15:0] pd; logic de=0; logic [4:0] da; logic [127:0] dd; logic dre=0; logic [4:0] dra; logic [127:0] drd;
  logic ve=0; logic [2:0] va; logic [127:0] vd; logic re=0; logic [2:0] ra; logic [127:0] rd; logic [2:0] state_dbg;
  logic [31:0] req,hit,miss,e0h,e1h,oa,os,dep,e0f,e1f,dup,ar,aph;
  logic [31:0] orhw,c2x,second,p0sd,p1sd,pair,dreq,dhit,maxdist;
  logic ev0,ev1,ep; logic [4:0] ea0,ea1; logic [127:0] ed0,ed1;
  vector_two_outstanding_prefetch_program_core #(.LOOKAHEAD_DEPTH(6)) dut(
    .clk(clk),.rst(rst),.start(start),.program_length(program_length),.running(running),.done(done),
    .current_pc(current_pc),.current_instruction(current_instruction),.current_instruction_valid(current_instruction_valid),
    .prog_load_enable(pe),.prog_load_addr(pa),.prog_load_data(pd),.data_load_enable(de),.data_load_addr(da),.data_load_data(dd),
    .data_debug_read_enable(dre),.data_debug_read_addr(dra),.data_debug_read_data(drd),.vector_load_enable(ve),.vector_load_addr(va),.vector_load_data(vd),
    .debug_read_enable(re),.debug_read_addr(ra),.debug_read_data(rd),.state_debug(state_dbg),.prefetch_request_count(req),.prefetch_hit_count(hit),.prefetch_miss_count(miss),
    .entry0_hit_count(e0h),.entry1_hit_count(e1h),.overlap_alu_count(oa),.overlap_store_count(os),.dependency_blocked_count(dep),.entry0_fill_count(e0f),.entry1_fill_count(e1f),
    .duplicate_suppression_count(dup),.alu_read_overlap_count(ar),.alu_prefetch_hit_count(aph),.debug_entry0_valid(ev0),.debug_entry1_valid(ev1),.debug_entry0_addr(ea0),.debug_entry1_addr(ea1),.debug_entry0_data(ed0),.debug_entry1_data(ed1),.debug_pending_read_valid(ep),
    .outstanding_read_high_watermark(orhw),.cycles_with_two_outstanding(c2x),.second_request_while_first_pending_count(second),.pending0_stale_discard_count(p0sd),.pending1_stale_discard_count(p1sd),.two_outstanding_useful_pair_count(pair),.deep_prefetch_request_count(dreq),.deep_prefetch_hit_count(dhit),.max_lookahead_distance(maxdist));

  integer total,alu_n,hit_n,miss_issue_n,wait_n,wb_n,store_n,control_n,idle_n,other_n,overlap_n,two_n,load_miss_n,load_hit_n,pc_adv_n,reg_w_n,mem_w_n;
  integer cycle_no, last_pc, last_pc_cycle; logic capture, array_trace; integer accounting_fail; integer issue_cycle[0:31]; logic prev_e0,prev_e1;
  function automatic [127:0] p4(input [31:0]a,b,c,d); p4={d,c,b,a}; endfunction
  function automatic [15:0] alu(input [3:0]o,input [2:0]d,a,b); alu={o,d,a,b,3'b0}; endfunction
  function automatic [15:0] ld(input [2:0]d,input [4:0]a); ld={4'ha,d,a,4'b0}; endfunction
  function automatic [15:0] st(input [2:0]s,input [4:0]a); st={4'hb,s,a,4'b0}; endfunction

  task automatic reset_core; begin rst=1; @(posedge clk); #1; rst=0; end endtask
  task automatic li(input integer a,input [15:0]v); begin pa=a;pd=v;pe=1;@(posedge clk);#1;pe=0;end endtask
  task automatic lm(input [4:0]a,input [127:0]v); begin da=a;dd=v;de=1;@(posedge clk);#1;de=0;end endtask
  task automatic lv(input [2:0]a,input [127:0]v); begin va=a;vd=v;ve=1;@(posedge clk);#1;ve=0;end endtask

  task automatic clear_counts; begin total=0;alu_n=0;hit_n=0;miss_issue_n=0;wait_n=0;wb_n=0;store_n=0;control_n=0;idle_n=0;other_n=0;overlap_n=0;two_n=0;load_miss_n=0;load_hit_n=0;pc_adv_n=0;reg_w_n=0;mem_w_n=0;cycle_no=0;last_pc=-1;last_pc_cycle=0;prev_e0=0;prev_e1=0;for(integer z=0;z<32;z=z+1)issue_cycle[z]=-1;end endtask
  task automatic run_bench(input integer n, input string name, output integer measured); integer c; begin
    clear_counts(); capture=1; program_length=n; start=1; @(posedge clk); #1; start=0; c=0;
    while(!done && c<300) begin @(posedge clk); #1; c=c+1; end
    capture=0; measured=c; if(!done) $display("TIMEOUT %s",name);
    $display("SUMMARY %s TOTAL=%0d ALU=%0d VLOAD_HIT=%0d VLOAD_MISS=%0d LOAD_WAIT=%0d LOAD_WB=%0d VSTORE=%0d CONTROL=%0d IDLE=%0d OTHER=%0d OVERLAP=%0d TWO_OUTSTANDING=%0d",name,total,alu_n,hit_n,miss_issue_n,wait_n,wb_n,store_n,control_n,idle_n,other_n,overlap_n,two_n);
    if(total!=measured) begin accounting_fail=accounting_fail+1; $display("ACCOUNTING FAIL %s primary=%0d measured=%0d",name,total,measured); end
  end endtask

  always @(posedge clk) begin #1;
    if(capture && (dut.running || dut.done)) begin
      cycle_no=cycle_no+1; total=total+1;
      if(dut.state==2'b01) begin wb_n=wb_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=LOAD_WB INSTR=%h CLASS=VLOAD_WRITEBACK",cycle_no,dut.current_pc,dut.current_instruction); end
      else if(dut.is_vload && dut.prefetch_hit) begin hit_n=hit_n+1;load_hit_n=load_hit_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=EXEC INSTR=%h CLASS=VLOAD_PREFETCH_HIT ADDR=%0d ISSUE_CYCLE=%0d LEAD_CYCLES=%0d",cycle_no,dut.current_pc,dut.current_instruction,dut.mem_addr,issue_cycle[dut.mem_addr],(issue_cycle[dut.mem_addr]>=0)?cycle_no-issue_cycle[dut.mem_addr]:-1); end
      else if(dut.is_vload && dut.architectural_read_request) begin miss_issue_n=miss_issue_n+1;load_miss_n=load_miss_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=EXEC INSTR=%h CLASS=VLOAD_MISS_ISSUE ADDR=%0d",cycle_no,dut.current_pc,dut.current_instruction,dut.mem_addr); end
      else if(dut.is_vstore) begin store_n=store_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=EXEC INSTR=%h CLASS=VSTORE_EXEC ADDR=%0d",cycle_no,dut.current_pc,dut.current_instruction,dut.mem_addr); end
      else if(dut.is_alu) begin alu_n=alu_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=EXEC INSTR=%h CLASS=ALU_EXEC OVERLAP=%b",cycle_no,dut.current_pc,dut.current_instruction,dut.prefetch_issue); end
      else if(!dut.current_instruction_valid) begin control_n=control_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=EXEC INSTR=%h CLASS=CONTROL_TRANSITION",cycle_no,dut.current_pc,dut.current_instruction); end
      else begin other_n=other_n+1; if(array_trace)$display("CYCLE %0d PC=%0d STATE=%0d INSTR=%h CLASS=OTHER",cycle_no,dut.current_pc,dut.state,dut.current_instruction); end
      if(dut.prefetch_issue) begin overlap_n=overlap_n+1; issue_cycle[dut.candidate_addr]=cycle_no; if(array_trace)$display("  SPEC_READ_ISSUE ADDR=%0d DIST=%0d ISSUE_CYCLE=%0d PENDING0=%b PENDING1=%b",dut.candidate_addr,dut.candidate_distance,cycle_no,dut.pending0_valid,dut.pending1_valid); end
      if(array_trace && dut.entry0_valid && !prev_e0)$display("  PREFETCH_RESPONSE ADDR=%0d SLOT=0 RESPONSE_CYCLE=%0d",dut.entry0_addr,cycle_no);
      if(array_trace && dut.entry1_valid && !prev_e1)$display("  PREFETCH_RESPONSE ADDR=%0d SLOT=1 RESPONSE_CYCLE=%0d",dut.entry1_addr,cycle_no);
      if(dut.pending0_valid&&dut.prefetch_issue) two_n=two_n+1;
      if(dut.core_reg_write) reg_w_n=reg_w_n+1;
      if(dut.mem_write_enable&&dut.running) mem_w_n=mem_w_n+1;
      if(last_pc>=0 && dut.current_pc!=last_pc) begin pc_adv_n=pc_adv_n+1; if(array_trace)$display("RETIRE PC=%0d COMPLETE_CYCLE=%0d CYCLES_CONSUMED=%0d",last_pc,cycle_no-1,cycle_no-last_pc_cycle); end
      last_pc=dut.current_pc; last_pc_cycle=cycle_no;
      prev_e0=dut.entry0_valid; prev_e1=dut.entry1_valid;
    end
  end

  initial begin integer cyc; logic [127:0]a,b,mask; accounting_fail=0; capture=0; array_trace=0; a=p4(1,2,3,4); b=p4(5,6,7,8); mask=p4(32'hffff0000,32'h0000ffff,32'h00ff00ff,32'hff00ff00);
    // Register-only VADD, exactly four ALU instructions.
    reset_core();lv(1,a);lv(2,b);li(0,alu(0,3,1,2));li(1,alu(0,4,3,2));li(2,alu(0,5,4,2));li(3,alu(0,6,5,2));run_bench(4,"REG_VADD",cyc);
    // Unchanged ARRAY_ADD workload with full cycle trace and retirement evidence.
    reset_core();array_trace=1;for(integer i=0;i<4;i=i+1)begin lm(i,p4(i+1,i+2,i+3,i+4));lm(8+i,p4(10+i,20+i,30+i,40+i));li(4*i,ld(1,i));li(4*i+1,ld(2,8+i));li(4*i+2,alu(0,3,1,2));li(4*i+3,st(3,16+i));end run_bench(16,"ARRAY_ADD",cyc);array_trace=0;
    reset_core();lv(2,mask);for(integer j=0;j<4;j=j+1)begin lm(j,p4(j,j+1,j+2,j+3));li(3*j,ld(1,j));li(3*j+1,alu(4,3,1,2));li(3*j+2,st(3,16+j));end run_bench(12,"XOR",cyc);
    reset_core();lv(2,p4(1,1,1,1));for(integer k=0;k<4;k=k+1)begin lm(k,p4(32'h80000000+k,32'h1,32'hffffffff,32'h7fffffff));li(3*k,ld(1,k));li(3*k+1,alu(9,3,1,2));li(3*k+2,st(3,16+k));end run_bench(12,"VSRA",cyc);
    $display("ACCOUNTING_FAILURES=%0d",accounting_fail); if(accounting_fail==0)$display("STAGE13_ANALYSIS_PASS"); else $fatal(1,"Stage 13 accounting failed"); $finish;
  end
endmodule
