`timescale 1ns/1ps
module vector_memory_program_core_tb;
 logic clk=0,rst=0,start=0; logic[4:0] program_length=0; logic running,done; logic[3:0] current_pc; logic[15:0] current_instruction; logic current_instruction_valid;
 logic prog_load_enable=0; logic[3:0] prog_load_addr=0; logic[15:0] prog_load_data=0; logic data_load_enable=0; logic[4:0] data_load_addr=0; logic[127:0] data_load_data=0; logic data_debug_read_enable=0; logic[4:0] data_debug_read_addr=0; logic[127:0] data_debug_read_data; logic vector_load_enable=0; logic[2:0] vector_load_addr=0; logic[127:0] vector_load_data=0; logic debug_read_enable=0; logic[2:0] debug_read_addr=0; logic[127:0] debug_read_data; logic[2:0] state_debug; int unsigned tests_run=0,tests_failed=0;
 vector_memory_program_core dut(.*); always #5 clk=~clk;
 function automatic logic[127:0] p4(input logic[31:0]a,input logic[31:0]b,input logic[31:0]c,input logic[31:0]d); p4={d,c,b,a}; endfunction
 function automatic logic[15:0] alu(input logic[3:0]op,input logic[2:0]d,input logic[2:0]a,input logic[2:0]b); alu={op,d,a,b,3'b0}; endfunction
 function automatic logic[15:0] ld(input logic[2:0]d,input logic[4:0]a); ld={4'ha,d,a,4'b0}; endfunction
 function automatic logic[15:0] st(input logic[2:0]s,input logic[4:0]a); st={4'hb,s,a,4'b0}; endfunction
 task automatic check(input logic c,input string m); begin tests_run++; if(!c)begin tests_failed++;$error("FAIL: %s",m);end else $display("PASS: %s",m);end endtask
 task automatic reset_core; begin rst=1;@(posedge clk);#1;rst=0;end endtask
 task automatic load_vec(input logic[2:0]a,input logic[127:0]v);begin vector_load_addr=a;vector_load_data=v;vector_load_enable=1;@(posedge clk);#1;vector_load_enable=0;end endtask
 task automatic load_data(input logic[4:0]a,input logic[127:0]v);begin data_load_addr=a;data_load_data=v;data_load_enable=1;@(posedge clk);#1;data_load_enable=0;end endtask
 task automatic load_prog(input logic[3:0]a,input logic[15:0]v);begin prog_load_addr=a;prog_load_data=v;prog_load_enable=1;@(posedge clk);#1;prog_load_enable=0;end endtask
 task automatic read_vec(input logic[2:0]a,input logic[127:0]e,input string m);begin debug_read_addr=a;debug_read_enable=1;#1;check(debug_read_data===e,m);debug_read_enable=0;end endtask
 task automatic read_mem(input logic[4:0]a,input logic[127:0]e,input string m);begin data_debug_read_addr=a;data_debug_read_enable=1;@(posedge clk);#1;data_debug_read_enable=0;check(data_debug_read_data===e,m);end endtask
 task automatic run_wait(input int lim);int i;begin start=1;@(posedge clk);#1;start=0;i=0;while(!done&&i<lim)begin@(posedge clk);#1;i++;end check(done,"program completes");end endtask
 initial begin
  logic[127:0] a,b,sum; a=p4(1,2,3,4); b=p4(5,6,7,8); sum=p4(6,8,10,12);
  reset_core(); load_data(0,a); load_data(1,b); load_prog(0,ld(1,0)); program_length=1; run_wait(5); read_vec(1,a,"basic VLOAD"); read_mem(0,a,"VLOAD preserves memory");
  reset_core(); load_vec(2,p4(10,20,30,40)); load_prog(0,st(2,3)); program_length=1; run_wait(5); read_mem(3,p4(10,20,30,40),"basic VSTORE"); read_vec(2,p4(10,20,30,40),"VSTORE preserves register");
  reset_core(); load_vec(3,p4(10,10,10,10)); load_data(0,a); load_prog(0,ld(1,0)); load_prog(1,alu(0,2,1,3)); program_length=2; run_wait(8); read_vec(2,p4(11,12,13,14),"VLOAD to dependent VADD");
  reset_core(); load_vec(1,a);load_vec(2,b);load_prog(0,alu(0,3,1,2));load_prog(1,st(3,4));program_length=2;run_wait(8);read_mem(4,sum,"VADD to dependent VSTORE");
  reset_core();load_data(0,a);load_data(1,b);load_prog(0,ld(1,0));load_prog(1,ld(2,1));load_prog(2,alu(0,3,1,2));load_prog(3,st(3,2));program_length=4;run_wait(12);read_mem(2,sum,"full VLOAD/VSTORE pipeline");
  reset_core();load_data(0,a);load_prog(0,ld(1,0));load_prog(1,16'hc000);load_prog(2,st(1,31));program_length=3;run_wait(12);read_mem(31,a,"invalid slot advances and store executes");
  reset_core();load_vec(1,a);load_prog(0,st(1,31));program_length=1;run_wait(5);read_mem(31,a,"final VSTORE committed before done");
  reset_core();load_data(31,b);load_prog(0,ld(7,31));program_length=1;run_wait(6);read_vec(7,b,"final VLOAD committed before done");
  reset_core();load_vec(1,a);load_data(0,b);load_prog(0,st(1,0));program_length=1;run_wait(5);read_mem(0,a,"restart setup"); run_wait(5);read_mem(0,a,"restart after done");
  if(tests_failed==0)begin $display("Tests run: %0d",tests_run);$display("Tests failed: 0");$display("VECTOR MEMORY PROGRAM CORE TEST PASSED");end else begin $display("Tests run: %0d",tests_run);$display("Tests failed: %0d",tests_failed);$display("VECTOR MEMORY PROGRAM CORE TEST FAILED");$fatal(1);end $finish;
 end
endmodule
