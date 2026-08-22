`timescale 1ns/1ps
module vector_gpu_accelerator_tb;
  logic clk=0,rst=0,start=0; always #5 clk=~clk; logic [4:0] plen; logic pwe=0; logic [3:0] paddr; logic [15:0] pdata; logic dwe=0; logic [4:0] daddr; logic [127:0] ddata; logic dre=0; logic [4:0] raddr; logic [127:0] rdata; logic rre=0; logic [2:0] vaddr; logic [127:0] vdata; logic busy,done; logic [31:0] cycles,req,hit,ar,aph; integer fail=0;
  vector_gpu_accelerator dut(.clk(clk),.rst(rst),.start(start),.program_length(plen),.prog_write_enable(pwe),.prog_write_addr(paddr),.prog_write_data(pdata),.data_write_enable(dwe),.data_write_addr(daddr),.data_write_data(ddata),.data_read_enable(dre),.data_read_addr(raddr),.data_read_data(rdata),.reg_read_enable(rre),.reg_read_addr(vaddr),.reg_read_data(vdata),.busy(busy),.done(done),.cycle_count(cycles),.prefetch_request_count(req),.prefetch_hit_count(hit),.alu_read_overlap_count(ar),.alu_prefetch_hit_count(aph));
  function automatic [15:0] alu(input [3:0]o,input [2:0]d,a,b);alu={o,d,a,b,3'b0};endfunction function automatic [15:0] st(input [2:0]s,input [4:0]a);st={4'hb,s,a,4'b0};endfunction function automatic [127:0] p4(input [31:0]a,b,c,d);p4={d,c,b,a};endfunction
  task automatic reset_core;begin rst=1;@(posedge clk);#1;rst=0;end endtask
  task automatic wp(input integer a,input [15:0]x);begin paddr=a;pdata=x;pwe=1;@(posedge clk);#1;pwe=0;end endtask
  task automatic wd(input integer a,input [127:0]x);begin daddr=a;ddata=x;dwe=1;@(posedge clk);#1;dwe=0;end endtask
  task automatic read_d(input integer a,input [127:0]x);begin raddr=a;@(posedge clk);#1;dre=1;@(posedge clk);#1;if(rdata!==x)begin fail++;$display("FAIL readback addr=%0d exp=%h got=%h",a,x,rdata);end dre=0;end endtask
  initial begin logic [127:0]a,b; a=p4(1,2,3,4);b=p4(5,6,7,8); reset_core;wd(0,a);wd(1,b);read_d(0,a);wp(0,16'ha210);wp(1,16'ha420);wp(2,alu(0,3,1,2));wp(3,st(3,2));plen=4;start=1;@(posedge clk);#1;start=0;while(!done)begin@(posedge clk);#1;end read_d(0,a); if(!done||busy)begin fail++;$display("FAIL status");end
    reset_core;wd(0,a);wd(1,b);wp(0,16'ha210);wp(1,16'ha420);wp(2,alu(0,3,1,2));wp(3,st(3,2));plen=4;start=1;@(posedge clk);#1;start=0;while(!done)begin@(posedge clk);#1;end
    if(fail==0)$display("VECTOR GPU ACCELERATOR TEST PASSED");else $display("VECTOR GPU ACCELERATOR TEST FAILED failures=%0d",fail);$finish; end
endmodule
