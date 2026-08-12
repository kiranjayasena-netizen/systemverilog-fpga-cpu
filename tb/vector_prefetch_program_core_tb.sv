`timescale 1ns/1ps
module vector_prefetch_program_core_tb;
  localparam logic [3:0] VADD=4'h0,VXOR=4'h4,VSRA=4'h9;
  logic clk=0,rst=0,start=0; logic [4:0] program_length; logic running,done;
  logic [3:0] current_pc; logic [15:0] current_instruction; logic current_instruction_valid;
  logic prog_load_enable=0; logic [3:0] prog_load_addr; logic [15:0] prog_load_data;
  logic data_load_enable=0; logic [4:0] data_load_addr; logic [127:0] data_load_data;
  logic data_debug_read_enable=0; logic [4:0] data_debug_read_addr; logic [127:0] data_debug_read_data;
  logic vector_load_enable=0; logic [2:0] vector_load_addr; logic [127:0] vector_load_data;
  logic debug_read_enable=0; logic [2:0] debug_read_addr; logic [127:0] debug_read_data; logic [2:0] state_debug;
  logic [31:0] prefetch_request_count,prefetch_hit_count,prefetch_miss_count,overlap_alu_count,overlap_store_count;
  int failures=0;
  vector_prefetch_program_core dut(.*); always #5 clk=~clk;
  function automatic logic[127:0] p4(input logic[31:0]a,b,c,d); p4={d,c,b,a}; endfunction
  function automatic logic[15:0] alu(input logic[3:0]op,input logic[2:0]d,a,b); alu={op,d,a,b,3'b0}; endfunction
  function automatic logic[15:0] ld(input logic[2:0]d,input logic[4:0]a); ld={4'ha,d,a,4'b0}; endfunction
  function automatic logic[15:0] st(input logic[2:0]s,input logic[4:0]a); st={4'hb,s,a,4'b0}; endfunction
  task automatic reset_core; begin rst=1; @(posedge clk); #1; rst=0; end endtask
  task automatic lv(input logic[2:0]a,input logic[127:0]v); begin vector_load_addr=a;vector_load_data=v;vector_load_enable=1;@(posedge clk);#1;vector_load_enable=0;end endtask
  task automatic ldmem(input logic[4:0]a,input logic[127:0]v); begin data_load_addr=a;data_load_data=v;data_load_enable=1;@(posedge clk);#1;data_load_enable=0;end endtask
  task automatic li(input int a,input logic[15:0]v); begin prog_load_addr=a;prog_load_data=v;prog_load_enable=1;@(posedge clk);#1;prog_load_enable=0;end endtask
  task automatic readm(input logic[4:0]a,input logic[127:0]e); begin data_debug_read_addr=a;data_debug_read_enable=1;@(posedge clk);#1;data_debug_read_enable=0;if(data_debug_read_data!==e)begin failures++;$error("memory mismatch at %0d",a);end end endtask
  task automatic run(input int n,output int c); begin program_length=n;start=1;@(posedge clk);#1;start=0;c=0;while(!done&&c<100)begin @(posedge clk);#1;c++;end if(!done)begin failures++;$error("timeout");end end endtask
  task automatic checkv(input logic[2:0]a,input logic[127:0]e); begin debug_read_enable=1;debug_read_addr=a;#1;debug_read_enable=0;if(debug_read_data!==e)begin failures++;$error("register mismatch V%0d",a);end end endtask
  initial begin logic[127:0]va,vb,mask,e; int c;
    va=p4(1,2,3,4); vb=p4(5,6,7,8); mask=p4(32'hffff0000,32'h0000ffff,32'h00ff00ff,32'hff00ff00);
    reset_core(); lv(1,va);lv(2,vb);li(0,alu(VADD,3,1,2));li(1,alu(VADD,4,3,2));li(2,alu(VADD,5,4,1));li(3,alu(VADD,6,5,2));run(4,c);checkv(6,p4(17,22,27,32));if(c!=4)$error("ALU cycle mismatch %0d",c);
    reset_core();for(int i=0;i<4;i++)begin ldmem(i,p4(i+1,i+2,i+3,i+4));ldmem(8+i,p4(10+i,20+i,30+i,40+i));li(4*i,ld(1,i));li(4*i+1,ld(2,8+i));li(4*i+2,alu(VADD,3,1,2));li(4*i+3,st(3,16+i));end run(16,c);for(int i=0;i<4;i++)begin e=p4((i+1)+(10+i),(i+2)+(20+i),(i+3)+(30+i),(i+4)+(40+i));readm(16+i,e);end if(c!=21)begin failures++;$error("prefetch array cycle mismatch %0d",c);end
    reset_core();lv(2,mask);for(int i=0;i<4;i++)begin ldmem(i,p4(i,i+1,i+2,i+3));li(3*i,ld(1,i));li(3*i+1,alu(VXOR,3,1,2));li(3*i+2,st(3,16+i));end run(12,c);for(int i=0;i<4;i++)begin e=p4(i^32'hffff0000,(i+1)^32'h0000ffff,(i+2)^32'h00ff00ff,(i+3)^32'hff00ff00);readm(16+i,e);end if(c!=13)begin failures++;$error("prefetch XOR cycle mismatch %0d",c);end
    reset_core();lv(2,p4(1,1,1,1));for(int i=0;i<4;i++)begin ldmem(i,p4(32'h80000000+i,1,32'hffffffff,32'h7fffffff));li(3*i,ld(1,i));li(3*i+1,alu(VSRA,3,1,2));li(3*i+2,st(3,16+i));end run(12,c);for(int i=0;i<4;i++)begin e=p4(32'hc0000000+(i>>1),0,32'hffffffff,32'h3fffffff);readm(16+i,e);end if(c!=13)begin failures++;$error("prefetch VSRA cycle mismatch %0d",c);end
    if(prefetch_hit_count==0||prefetch_request_count==0)begin failures++;$error("no prefetch activity observed");end
    if(failures==0)begin $display("PREFETCH requests=%0d hits=%0d misses=%0d ALU-overlap=%0d STORE-overlap=%0d",prefetch_request_count,prefetch_hit_count,prefetch_miss_count,overlap_alu_count,overlap_store_count);$display("VECTOR PREFETCH PROGRAM CORE TEST PASSED");end else begin $display("VECTOR PREFETCH PROGRAM CORE TEST FAILED failures=%0d",failures);$fatal(1);end $finish;
  end
endmodule
