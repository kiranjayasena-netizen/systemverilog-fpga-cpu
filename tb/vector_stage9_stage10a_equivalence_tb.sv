`timescale 1ns/1ps
module vector_stage9_stage10a_equivalence_tb;
  logic clk=0,rst=0,start=0; always #5 clk=~clk;
  logic [4:0] len; logic r9,d9,r10,d10; logic [3:0] pc9,pc10; logic [15:0] ins9,ins10; logic v9,v10;
  logic pe=0; logic [3:0] pa; logic [15:0] pd;
  logic de=0; logic [4:0] da; logic [127:0] dd;
  logic dre=0; logic [4:0] dra; logic [127:0] drd9,drd10;
  logic ve=0; logic [2:0] va; logic [127:0] vd;
  logic re=0; logic [2:0] ra; logic [127:0] rd9,rd10; logic [2:0] st9,st10;
  logic [31:0] q9[0:4]; logic [31:0] q10[0:15];
  logic [31:0] req9,hit9,miss9,oa9,os9,req10,hit10,miss10,oa10,os10,e0f,e1f,e0h,e1h,db,dep;
  vector_prefetch_program_core c9(.clk(clk),.rst(rst),.start(start),.program_length(len),.running(r9),.done(d9),.current_pc(pc9),.current_instruction(ins9),.current_instruction_valid(v9),.prog_load_enable(pe),.prog_load_addr(pa),.prog_load_data(pd),.data_load_enable(de),.data_load_addr(da),.data_load_data(dd),.data_debug_read_enable(dre),.data_debug_read_addr(dra),.data_debug_read_data(drd9),.vector_load_enable(ve),.vector_load_addr(va),.vector_load_data(vd),.debug_read_enable(re),.debug_read_addr(ra),.debug_read_data(rd9),.state_debug(st9),.prefetch_request_count(req9),.prefetch_hit_count(hit9),.prefetch_miss_count(miss9),.overlap_alu_count(oa9),.overlap_store_count(os9));
  vector_dual_prefetch_program_core c10(.clk(clk),.rst(rst),.start(start),.program_length(len),.running(r10),.done(d10),.current_pc(pc10),.current_instruction(ins10),.current_instruction_valid(v10),.prog_load_enable(pe),.prog_load_addr(pa),.prog_load_data(pd),.data_load_enable(de),.data_load_addr(da),.data_load_data(dd),.data_debug_read_enable(dre),.data_debug_read_addr(dra),.data_debug_read_data(drd10),.vector_load_enable(ve),.vector_load_addr(va),.vector_load_data(vd),.debug_read_enable(re),.debug_read_addr(ra),.debug_read_data(rd10),.state_debug(st10),.prefetch_request_count(req10),.prefetch_hit_count(hit10),.prefetch_miss_count(miss10),.overlap_alu_count(oa10),.overlap_store_count(os10),.entry0_fill_count(e0f),.entry1_fill_count(e1f),.entry0_hit_count(e0h),.entry1_hit_count(e1h),.duplicate_suppression_count(db),.dependency_blocked_count(dep),.debug_entry0_valid(),.debug_entry1_valid(),.debug_entry0_addr(),.debug_entry1_addr(),.debug_entry0_data(),.debug_entry1_data(),.debug_pending_read_valid());
  function automatic logic [15:0] alu(input logic[3:0]o,input logic[2:0]d,a,b);alu={o,d,a,b,3'b0};endfunction
  function automatic logic [15:0] ld(input logic[2:0]d,input logic[4:0]a);ld={4'ha,d,a,4'b0};endfunction
  function automatic logic [15:0] st(input logic[2:0]s,input logic[4:0]a);st={4'hb,s,a,4'b0};endfunction
  function automatic logic [127:0] p4(input logic[31:0]a,b,c,d);p4={d,c,b,a};endfunction
  integer tests=0,fail=0;
  task automatic reset_all; begin rst=1;@(posedge clk);#1;rst=0;end endtask
  task automatic li(input int a,input logic[15:0]x);begin pa=a;pd=x;pe=1;@(posedge clk);#1;pe=0;end endtask
  task automatic lm(input logic[4:0]a,input logic[127:0]x);begin da=a;dd=x;de=1;@(posedge clk);#1;de=0;end endtask
  task automatic lv(input logic[2:0]a,input logic[127:0]x);begin va=a;vd=x;ve=1;@(posedge clk);#1;ve=0;end endtask
  task automatic run_both(input int n);integer k;begin len=n;start=1;@(posedge clk);#1;start=0;k=0;while((!d9||!d10)&&k<200)begin @(posedge clk);#1;k++;end if(!d9||!d10)begin fail++;$display("FAIL timeout");end end endtask
  task automatic check_reg(input logic[2:0]a,input logic[127:0]x,input string s);begin re=1;ra=a;#0;if(rd9!==rd10||rd9!==x)begin fail++;$display("FAIL %s r9=%h r10=%h exp=%h",s,rd9,rd10,x);end re=0;tests++;end endtask
  task automatic check_mem(input logic[4:0]a,input logic[127:0]x,input string s);begin dra=a;dre=1;@(posedge clk);#1;if(drd9!==drd10||drd9!==x)begin fail++;$display("FAIL %s m9=%h m10=%h exp=%h",s,drd9,drd10,x);end dre=0;tests++;end endtask
  task automatic begin_case;begin reset_all;len=0;start=0;pe=0;de=0;ve=0;re=0;dre=0;end endtask
  initial begin logic[127:0] a,b,c; a=p4(1,2,3,4);b=p4(5,6,7,8);c=p4(9,10,11,12);
    begin_case;lv(1,a);lv(2,b);li(0,alu(0,3,1,2));li(1,alu(1,4,3,1));li(2,alu(4,5,4,2));li(3,alu(6,6,5,1));run_both(4);check_reg(6,p4(1,1,1,1),"P1 register ALU");
    begin_case;lm(0,a);lm(1,b);li(0,ld(1,0));li(1,ld(2,1));li(2,alu(0,3,1,2));li(3,st(3,2));run_both(4);check_reg(3,p4(6,8,10,12),"P2 V3");check_mem(2,p4(6,8,10,12),"P2 store");
    begin_case;lm(0,a);lm(1,b);lm(2,c);li(0,ld(1,0));li(1,st(1,5));li(2,ld(2,1));li(3,alu(4,3,1,2));li(4,st(3,6));li(5,ld(4,2));run_both(6);check_mem(5,a,"P3 store1");check_mem(6,p4(4,4,4,12),"P3 store2");
    begin_case;lm(5,a);lv(4,b);li(0,st(4,5));li(1,ld(1,5));run_both(2);check_reg(1,b,"P4 store hazard");
    begin_case;lv(1,a);li(0,16'hc000);li(1,alu(0,2,1,1));run_both(2);check_reg(2,p4(2,4,6,8),"P5 invalid");
    begin_case;lm(0,a);li(0,ld(1,0));run_both(1);lm(0,b);start=1;@(posedge clk);#1;start=0;run_both(1);check_reg(1,b,"P6 restart");
    if(fail==0)$display("STAGE 9 / STAGE 10A ARCHITECTURAL EQUIVALENCE PASSED");else $display("EQUIVALENCE FAILED (%0d)",fail);$finish;
  end
endmodule
