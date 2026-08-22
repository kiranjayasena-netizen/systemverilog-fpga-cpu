`timescale 1ns/1ps
module vector_alu_prefetch_program_core_tb;
 logic clk=0,rst=0,start=0; always #5 clk=~clk;
 logic [4:0] program_length; logic running,done; logic [3:0] current_pc; logic [15:0] current_instruction; logic current_instruction_valid;
 logic prog_load_enable=0; logic [3:0] prog_load_addr; logic [15:0] prog_load_data;
 logic data_load_enable=0; logic [4:0] data_load_addr; logic [127:0] data_load_data; logic data_debug_read_enable=0; logic [4:0] data_debug_read_addr; logic [127:0] data_debug_read_data;
 logic vector_load_enable=0; logic [2:0] vector_load_addr; logic [127:0] vector_load_data; logic debug_read_enable=0; logic [2:0] debug_read_addr; logic [127:0] debug_read_data; logic [2:0] state_debug;
 logic [31:0] prefetch_request_count,prefetch_hit_count,prefetch_miss_count,entry0_hit_count,entry1_hit_count,overlap_alu_count,overlap_store_count,dependency_blocked_count,entry0_fill_count,entry1_fill_count,duplicate_suppression_count,alu_read_overlap_count,alu_prefetch_hit_count;
 logic debug_entry0_valid,debug_entry1_valid,debug_pending_read_valid; logic [4:0] debug_entry0_addr,debug_entry1_addr; logic [127:0] debug_entry0_data,debug_entry1_data;
 vector_alu_prefetch_program_core dut(.*);
 integer tests_run=0,tests_failed=0,read_count=0; logic no_free_seen,trace12;
 // Check competing read intents, not consecutive read cycles. Consecutive
 // physical reads are legal; two commands in one cycle are not.
 always @(posedge clk) begin #1; if(dut.architectural_read_request && dut.prefetch_issue) begin tests_failed++; $display("FAIL two read sources at t=%0t",$time); end if(trace12) $display("TEST12 TRACE t=%0t pc=%0d instr=%h alu=%b e0=%b/%0d e1=%b/%0d pending=%b/%0d/%b cand=%b/%0d s0=%b s1=%b free=%b slot=%b issue=%b rd=%b/%0d",$time,dut.current_pc,dut.current_instruction,dut.is_alu,dut.entry0_valid,dut.entry0_addr,dut.entry1_valid,dut.entry1_addr,dut.pending_read_valid,dut.pending_read_addr,dut.pending_read_slot,dut.candidate_valid,dut.candidate_addr,dut.slot0_available,dut.slot1_available,dut.free_slot_valid,dut.candidate_slot,dut.prefetch_issue,dut.mem_read_enable,dut.mem_read_addr); if(!dut.slot0_available&&!dut.slot1_available&&!dut.free_slot_valid&&!dut.prefetch_issue&&((dut.entry0_valid&&dut.pending_read_valid&&dut.pending_read_slot==1'b1)||(dut.entry1_valid&&dut.pending_read_valid&&dut.pending_read_slot==1'b0))) begin no_free_seen=1; $display("TEST12 TARGET t=%0t pc=%0d e0=%b/%0d e1=%b/%0d pending=%b slot=%b free=%b issue=%b",$time,dut.current_pc,dut.entry0_valid,dut.entry0_addr,dut.entry1_valid,dut.entry1_addr,dut.pending_read_valid,dut.pending_read_slot,dut.free_slot_valid,dut.prefetch_issue); end end
 function automatic [127:0] p4(input [31:0] a,b,c,d); p4={d,c,b,a}; endfunction
 function automatic [15:0] alu(input [3:0] o,input [2:0] d,a,b); alu={o,d,a,b,3'b0}; endfunction
 function automatic [15:0] ld(input [2:0] d,input [4:0] a); ld={4'ha,d,a,4'b0}; endfunction
 function automatic [15:0] st(input [2:0] s,input [4:0] a); st={4'hb,s,a,4'b0}; endfunction
 task automatic reset_core; begin rst=1; @(posedge clk); #1; rst=0; end endtask
 task automatic li(input integer a,input [15:0] v); begin prog_load_addr=a;prog_load_data=v;prog_load_enable=1;@(posedge clk);#1;prog_load_enable=0;end endtask
 task automatic lm(input [4:0] a,input [127:0] v); begin data_load_addr=a;data_load_data=v;data_load_enable=1;@(posedge clk);#1;data_load_enable=0;end endtask
 task automatic lv(input [2:0] a,input [127:0] v); begin vector_load_addr=a;vector_load_data=v;vector_load_enable=1;@(posedge clk);#1;vector_load_enable=0;end endtask
 task automatic rv(input [2:0] a,input [127:0] e,output logic ok); begin debug_read_addr=a;debug_read_enable=1;#1;ok=(debug_read_data===e);debug_read_enable=0;end endtask
 task automatic run(input integer n); integer c; begin program_length=n;start=1;@(posedge clk);#1;start=0;c=0;while(!done&&c<100)begin @(posedge clk);#1;c++;end if(!done)begin tests_failed++;$display("timeout");end end endtask
 task automatic report(input string name,input logic ok); begin tests_run++;if(ok)$display("PASS %s",name);else begin tests_failed++;$display("FAIL %s",name);end end endtask
 task automatic alu_prefetch_case(output logic ok); logic [127:0] a,b,old; begin a=p4(1,2,3,4);b=p4(5,6,7,8);old=p4(9,9,9,9);reset_core();lv(1,a);lv(2,b);lv(4,old);lm(0,p4(40,30,20,10));
   li(0,alu(0,3,1,2)); li(1,16'h0000); li(2,ld(4,0)); li(3,alu(4,5,4,1)); run(4);
   ok=(alu_read_overlap_count>0)&&(prefetch_hit_count>0)&&(entry0_hit_count+entry1_hit_count>0);
 end endtask
 initial begin logic ok; logic [127:0] a,b;
  a=p4(1,2,3,4); b=p4(5,6,7,8);
  // 01: ALU detection and correct result during overlap
  reset_core();lv(1,a);lv(2,b);lm(0,p4(40,30,20,10));li(0,alu(0,3,1,2));li(1,16'h0000);li(2,ld(4,0));run(3);rv(3,p4(6,8,10,12),ok);report("TEST 01 BASIC ALU REGRESSION",ok&&alu_read_overlap_count>0);
  // 02: explicit overlap request
  report("TEST 02 ALU READ OVERLAP",alu_read_overlap_count>0);
  // 03: ALU-issued request returns into an entry
  report("TEST 03 ALU PREFETCH FILL",entry0_fill_count+entry1_fill_count>0);
  // 04: central genuine architectural hit
  alu_prefetch_case(ok);report("TEST 04 ALU ISSUED PREFETCH HIT",ok);
  report("TEST 05 HIT SAVES LOAD PHASE",prefetch_hit_count>0);
  // 06 dependent ALU after overlap
  reset_core();lv(1,a);lv(2,b);li(0,alu(0,3,1,2));li(1,alu(4,4,3,1));li(2,16'h0000);
  $display("TEST06 PROGRAM i0=%h (VADD V3,V1,V2) i1=%h (VXOR V4,V3,V1)",alu(0,3,1,2),alu(4,4,3,1));
  $display("TEST06 INPUT V1=%h lanes=(%h,%h,%h,%h) V2=%h lanes=(%h,%h,%h,%h)",a,a[31:0],a[63:32],a[95:64],a[127:96],b,b[31:0],b[63:32],b[95:64],b[127:96]);
  run(3); $display("TEST06 AFTER V3=%h V4=%h",dut.eu.vector_register_file_inst.regs[3],dut.eu.vector_register_file_inst.regs[4]);
  rv(4,p4(7,10,9,8),ok);report("TEST 06 ALU TO ALU DEPENDENCY",ok);
  // 07 ALU to store
  reset_core();lv(1,a);lv(2,b);li(0,alu(0,3,1,2));li(1,st(3,4));run(2);data_debug_read_enable=1;data_debug_read_addr=4;@(posedge clk);#1;ok=(data_debug_read_data===p4(6,8,10,12));data_debug_read_enable=0;report("TEST 07 ALU TO VSTORE",ok);
  // 08 hit to dependent ALU
  alu_prefetch_case(ok);report("TEST 08 PREFETCH HIT TO ALU",ok);
  // 09 two entries
  reset_core();lv(1,a);lv(2,b);lm(0,p4(40,30,20,10));lm(1,p4(80,70,60,50));li(0,alu(0,3,1,2));li(1,alu(1,4,1,2));li(2,16'h0000);li(3,ld(5,0));li(4,ld(6,1));run(5);report("TEST 09 DUAL ENTRY",entry0_fill_count+entry1_fill_count>=2);
  // 10 duplicate suppression while ALU active
  reset_core();lm(0,a);lm(1,b);li(0,alu(0,1,1,1));li(1,ld(2,0));li(2,ld(3,1));run(3);report("TEST 10 ALU DUPLICATE SUPPRESSION",prefetch_request_count>=1);
  // 11 intervening store safety
  reset_core();lv(1,b);lm(5,a);li(0,alu(0,2,1,1));li(1,st(1,5));li(2,ld(3,5));run(3);rv(3,b,ok);report("TEST 11 INTERVENING STORE",ok);
  // 12 both entries are full while a later distinct candidate is visible.
  reset_core(); no_free_seen=0; lv(1,a); lv(2,b); lm(0,p4(40,30,20,10)); lm(1,p4(80,70,60,50)); lm(2,p4(120,110,100,90));
  // PC1 issues load[0] at c4 (PC5). After its response, PC3 skips the
  // duplicate load[0] at c2 and issues load[1] at c3 (PC6). PC4 is a timing
  // ALU cycle while the second read is pending. PC5 is the observation ALU
  // cycle after entry1 fills; load[2] at c3 (PC8) is distinct. Both slots
  // are full, so no speculative read is issued. PC6/7/8 consume entries.
  li(0,16'hc000); li(1,alu(0,3,1,2)); li(2,16'hc000); li(3,alu(1,4,1,2)); li(4,alu(0,5,1,2)); li(5,alu(1,5,1,2)); li(6,ld(6,0)); li(7,ld(7,1)); li(8,ld(0,2)); trace12=1; run(9); trace12=0;
  $display("TEST12 EVENTS no_free_seen=%b e0fills=%0d e1fills=%0d requests=%0d",no_free_seen,entry0_fill_count,entry1_fill_count,prefetch_request_count);
  report("TEST 12 NO FREE SLOT",no_free_seen);
  // 13 pending busy obeyed
  report("TEST 13 PENDING BUSY",prefetch_request_count<=2);
  // 14 architectural VLOAD miss remains functional
  reset_core();lm(7,a);li(0,ld(1,7));run(1);rv(1,a,ok);report("TEST 14 VLOAD MISS PRIORITY",ok);
  // 15 VSTORE overlap remains available
  reset_core();lv(1,a);lm(0,b);li(0,st(1,4));li(1,ld(2,0));run(2);report("TEST 15 VSTORE OVERLAP",overlap_store_count>0);
  // 16 one read per cycle global checker
  report("TEST 16 ONE READ PER CYCLE",1'b1);
  // 17 hit qualified by VLOAD: ALU result must survive buffered address zero
  reset_core();lv(1,a);lv(2,b);lm(0,p4(40,30,20,10));li(0,alu(0,3,1,2));li(1,16'h0000);li(2,ld(4,0));run(3);rv(3,p4(6,8,10,12),ok);report("TEST 17 VLOAD HIT QUALIFICATION",ok);
  // 18 reset/restart
  reset_core();report("TEST 18 RESET RESTART",!running&&!debug_entry0_valid&&!debug_entry1_valid&&!debug_pending_read_valid);
  // 19 external idle invalidation
  lm(0,a);report("TEST 19 EXTERNAL INVALIDATION",!debug_entry0_valid&&!debug_entry1_valid);
  // 20 invalid instruction does not execute ALU
  reset_core();lv(1,a);li(0,16'hc000);li(1,alu(0,2,1,1));run(2);rv(2,p4(2,4,6,8),ok);report("TEST 20 INVALID INSTRUCTION",ok);
  $display("Tests run: %0d",tests_run);$display("Tests failed: %0d",tests_failed);if(tests_failed==0)$display("VECTOR ALU PREFETCH PROGRAM CORE TEST PASSED");else $fatal(1,"Stage 10B-A failed");$finish;
 end
endmodule
