`timescale 1ns/1ps
module vector_dual_prefetch_program_core_benchmark_tb;
  logic clk=0,rst=0,start=0; always #5 clk=~clk;
  logic [4:0] program_length; logic running,done; logic [3:0] current_pc; logic [15:0] current_instruction; logic current_instruction_valid;
  logic prog_load_enable=0; logic [3:0] prog_load_addr; logic [15:0] prog_load_data;
  logic data_load_enable=0; logic [4:0] data_load_addr; logic [127:0] data_load_data; logic data_debug_read_enable=0; logic [4:0] data_debug_read_addr; logic [127:0] data_debug_read_data;
  logic vector_load_enable=0; logic [2:0] vector_load_addr; logic [127:0] vector_load_data; logic debug_read_enable=0; logic [2:0] debug_read_addr; logic [127:0] debug_read_data; logic [2:0] state_debug;
  logic [31:0] prefetch_request_count,prefetch_hit_count,prefetch_miss_count,entry0_hit_count,entry1_hit_count,overlap_alu_count,overlap_store_count,dependency_blocked_count,entry0_fill_count,entry1_fill_count,duplicate_suppression_count;
  logic debug_entry0_valid,debug_entry1_valid,debug_pending_read_valid; logic [4:0] debug_entry0_addr,debug_entry1_addr; logic [127:0] debug_entry0_data,debug_entry1_data;
  vector_dual_prefetch_program_core dut(.*); integer failures=0,max_entries_seen=0;
  always @(posedge clk) begin #1; if(debug_entry0_valid&&debug_entry1_valid) max_entries_seen=2; end
  function automatic logic[127:0] p4(input logic[31:0]a,b,c,d);p4={d,c,b,a};endfunction
  function automatic logic[15:0] alu(input logic[3:0]o,input logic[2:0]d,a,b);alu={o,d,a,b,3'b0};endfunction
  function automatic logic[15:0] ld(input logic[2:0]d,input logic[4:0]a);ld={4'ha,d,a,4'b0};endfunction
  function automatic logic[15:0] st(input logic[2:0]s,input logic[4:0]a);st={4'hb,s,a,4'b0};endfunction
  task automatic reset_core;begin rst=1;@(posedge clk);#1;rst=0;end endtask
  task automatic li(input int a,input logic[15:0]v);begin prog_load_addr=a;prog_load_data=v;prog_load_enable=1;@(posedge clk);#1;prog_load_enable=0;end endtask
  task automatic lm(input logic[4:0]a,input logic[127:0]v);begin data_load_addr=a;data_load_data=v;data_load_enable=1;@(posedge clk);#1;data_load_enable=0;end endtask
  task automatic lv(input logic[2:0]a,input logic[127:0]v);begin vector_load_addr=a;vector_load_data=v;vector_load_enable=1;@(posedge clk);#1;vector_load_enable=0;end endtask
  task automatic run(input int n,output int cyc);integer k;begin max_entries_seen=0;program_length=n;start=1;@(posedge clk);#1;start=0;cyc=0;while(!done&&cyc<200)begin @(posedge clk);#1;cyc++;end if(!done)begin failures++;$display("FAIL timeout");end end endtask
  task automatic check_mem(input logic[4:0]a,input logic[127:0]e);begin data_debug_read_addr=a;data_debug_read_enable=1;@(posedge clk);#1;if(data_debug_read_data!==e)begin failures++;$display("FAIL memory[%0d] expected=%h actual=%h",a,e,data_debug_read_data);end data_debug_read_enable=0;end endtask
  task automatic summary(input string n,input int cyc,input int scalars,input int alus,input int loads,input int stores);real x;begin x=real'(scalars)/cyc;$display("BENCHMARK: %s cycles=%0d cycles/vector=%0.3f scalar_ops/cycle=%0.6f ALU_fraction=%0.6f VLOAD=%0d VSTORE=%0d requests=%0d e0_hits=%0d e1_hits=%0d max_entries=%0d",n,cyc,real'(cyc)/4,x,real'(alus)/cyc,loads,stores,prefetch_request_count,entry0_hit_count,entry1_hit_count,max_entries_seen);end endtask
  initial begin logic[127:0]a,b,mask,e; integer cyc;
    a=p4(1,2,3,4);b=p4(5,6,7,8);mask=p4(32'hffff0000,32'h0000ffff,32'h00ff00ff,32'hff00ff00);
    reset_core();lv(1,a);lv(2,b);li(0,alu(0,3,1,2));li(1,alu(0,4,3,2));li(2,alu(0,5,4,2));li(3,alu(0,6,5,2));run(4,cyc);summary("REGISTER-ONLY VADD",cyc,16,4,0,0);
    reset_core();for(int i=0;i<4;i++)begin lm(i,p4(i+1,i+2,i+3,i+4));lm(8+i,p4(10+i,20+i,30+i,40+i));li(4*i,ld(1,i));li(4*i+1,ld(2,8+i));li(4*i+2,alu(0,3,1,2));li(4*i+3,st(3,16+i));end run(16,cyc);for(int i=0;i<4;i++)begin e=p4((i+1)+(10+i),(i+2)+(20+i),(i+3)+(30+i),(i+4)+(40+i));check_mem(16+i,e);end summary("VECTOR ARRAY ADD",cyc,16,4,8,4);
    reset_core();lv(2,mask);for(int i=0;i<4;i++)begin lm(i,p4(i,i+1,i+2,i+3));li(3*i,ld(1,i));li(3*i+1,alu(4,3,1,2));li(3*i+2,st(3,16+i));end run(12,cyc);for(int i=0;i<4;i++)begin e=p4(i^32'hffff0000,(i+1)^32'h0000ffff,(i+2)^32'h00ff00ff,(i+3)^32'hff00ff00);check_mem(16+i,e);end summary("XOR TRANSFORM",cyc,16,4,4,4);
    reset_core();lv(2,p4(1,1,1,1));for(int i=0;i<4;i++)begin lm(i,p4(32'h80000000+i,32'h00000001,32'hffffffff,32'h7fffffff));li(3*i,ld(1,i));li(3*i+1,alu(9,3,1,2));li(3*i+2,st(3,16+i));end run(12,cyc);for(int i=0;i<4;i++)begin e=p4(32'hc0000000+(i>>1),0,32'hffffffff,32'h3fffffff);check_mem(16+i,e);end summary("VSRA TRANSFORM",cyc,16,4,4,4);
    if(failures==0)$display("VECTOR DUAL PREFETCH BENCHMARK TEST PASSED");else $display("VECTOR DUAL PREFETCH BENCHMARK TEST FAILED failures=%0d",failures);$finish;
  end
endmodule
