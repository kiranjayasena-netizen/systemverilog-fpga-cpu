`timescale 1ns/1ps
module vector_stage12_stage14_equivalence_tb;
  logic clk=0,rst=0,start=0; always #5 clk=~clk;
  logic [4:0] program_length; logic run12,done12,run14,done14; logic [3:0] pc12,pc14; logic [15:0] ins12,ins14; logic v12,v14;
  logic pe=0; logic [3:0] pa; logic [15:0] pd; logic de=0; logic [4:0] da; logic [127:0] dd;
  logic dre=0; logic [4:0] dra; logic [127:0] mem12,mem14; logic ve=0; logic [2:0] va; logic [127:0] vd;
  logic re=0; logic [2:0] ra; logic [127:0] reg12,reg14; logic [2:0] st12,st14;
  vector_two_outstanding_prefetch_program_core #(.LOOKAHEAD_DEPTH(6)) d12(
    .clk(clk),.rst(rst),.start(start),.program_length(program_length),.running(run12),.done(done12),.current_pc(pc12),.current_instruction(ins12),.current_instruction_valid(v12),
    .prog_load_enable(pe),.prog_load_addr(pa),.prog_load_data(pd),.data_load_enable(de),.data_load_addr(da),.data_load_data(dd),.data_debug_read_enable(dre),.data_debug_read_addr(dra),.data_debug_read_data(mem12),.vector_load_enable(ve),.vector_load_addr(va),.vector_load_data(vd),.debug_read_enable(re),.debug_read_addr(ra),.debug_read_data(reg12),.state_debug(st12));
  vector_load_overlap_program_core #(.LOOKAHEAD_DEPTH(6)) d14(
    .clk(clk),.rst(rst),.start(start),.program_length(program_length),.running(run14),.done(done14),.current_pc(pc14),.current_instruction(ins14),.current_instruction_valid(v14),
    .prog_load_enable(pe),.prog_load_addr(pa),.prog_load_data(pd),.data_load_enable(de),.data_load_addr(da),.data_load_data(dd),.data_debug_read_enable(dre),.data_debug_read_addr(dra),.data_debug_read_data(mem14),.vector_load_enable(ve),.vector_load_addr(va),.vector_load_data(vd),.debug_read_enable(re),.debug_read_addr(ra),.debug_read_data(reg14),.state_debug(st14));
  function automatic [15:0] alu(input [3:0]o,input [2:0]d,a,b); alu={o,d,a,b,3'b0}; endfunction
  function automatic [15:0] ld(input [2:0]d,input [4:0]a); ld={4'ha,d,a,4'b0}; endfunction
  function automatic [15:0] st(input [2:0]s,input [4:0]a); st={4'hb,s,a,4'b0}; endfunction
  function automatic [127:0] p4(input [31:0]a,b,c,d); p4={d,c,b,a}; endfunction
  task automatic rst_all; begin rst=1; @(posedge clk); #1; rst=0; end endtask
  task automatic li(input integer i,input [15:0] x); begin pa=i;pd=x;pe=1;@(posedge clk);#1;pe=0;end endtask
  task automatic lm(input [4:0] i,input [127:0] x); begin da=i;dd=x;de=1;@(posedge clk);#1;de=0;end endtask
  task automatic lv(input [2:0] i,input [127:0] x); begin va=i;vd=x;ve=1;@(posedge clk);#1;ve=0;end endtask
  integer tests=0,fail=0;
  task automatic run_case(input integer n,input string name,input integer plen,input [4:0] mem_addr,input [127:0] expected_mem); integer c,i; logic ok; begin
    program_length=plen; start=1; @(posedge clk); #1; start=0; c=0; while((!done12||!done14)&&c<300) begin @(posedge clk);#1;c++;end
    tests++; ok=done12&&done14&&(pc12==pc14); re=1;
    for(i=0;i<8;i++) begin ra=i; #0; if(reg12!==reg14) ok=0; end
    re=0; if(mem_addr<31) begin dra=mem_addr;dre=1;@(posedge clk);#1;if(mem12!==mem14||mem12!==expected_mem)ok=0;dre=0;end
    if(ok)$display("PASS EQUIV %0d %s",n,name); else begin fail++;$display("FAIL EQUIV %0d %s pc12=%0d pc14=%0d",n,name,pc12,pc14);end
  end endtask
  initial begin logic [127:0] a,b,c; a=p4(1,2,3,4); b=p4(5,6,7,8); c=p4(9,10,11,12);
    rst_all;lv(1,a);lv(2,b);li(0,alu(0,3,1,2));li(1,alu(1,4,3,1));run_case(1,"dependent ALU",2,31,0);
    rst_all;lm(0,a);lm(1,b);li(0,ld(1,0));li(1,ld(2,1));li(2,alu(0,3,1,2));li(3,st(3,2));run_case(2,"load load add store",4,2,p4(6,8,10,12));
    rst_all;lm(0,a);lm(1,b);lm(2,c);li(0,ld(1,0));li(1,st(1,5));li(2,ld(2,1));li(3,alu(4,3,1,2));li(4,st(3,6));li(5,ld(4,2));run_case(3,"multiple memory",6,6,p4(4,4,4,12));
    rst_all;lm(5,a);lv(4,b);li(0,st(4,5));li(1,ld(1,5));run_case(4,"store hazard",2,5,b);
    rst_all;lv(1,a);li(0,16'hc000);li(1,alu(0,2,1,1));run_case(5,"invalid instruction",2,31,0);
    rst_all;lm(0,a);li(0,ld(1,0));run_case(6,"restart",1,31,0);
    rst_all;lm(0,a);lv(2,p4(16'hff,16'h0f,16'hf0,16'hff00));li(0,ld(1,0));li(1,alu(4,3,1,2));li(2,st(3,2));run_case(7,"XOR",3,2,p4(1^16'hff,2^16'h0f,3^16'hf0,4^16'hff00));
    rst_all;lm(0,p4(32'h80000000,32'h10,32'hffffffff,32'h7fffffff));lv(2,p4(1,1,1,1));li(0,ld(1,0));li(1,alu(9,3,1,2));li(2,st(3,2));run_case(8,"VSRA",3,2,p4(32'hc0000000,32'h00000008,32'hffffffff,32'h3fffffff));
    rst_all;lm(4,a);lv(2,b);li(0,st(2,4));li(1,ld(1,4));run_case(9,"current store hazard",2,4,b);
    rst_all;lm(6,a);lv(3,b);li(0,alu(0,1,3,3));li(1,st(1,6));li(2,ld(2,6));run_case(10,"intervening store hazard",3,6,p4(10,12,14,16));
    $display("Equivalence tests run: %0d",tests);$display("Equivalence tests failed: %0d",fail);$finish;
  end
endmodule
