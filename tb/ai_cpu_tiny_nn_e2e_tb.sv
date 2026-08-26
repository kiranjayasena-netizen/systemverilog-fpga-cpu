`timescale 1ns/1ps
module ai_cpu_tiny_nn_e2e_tb;
  logic clk=0; always #5 clk=~clk;
  logic rst=1;
  logic lm_b=1,lm_o=1,start_b=0,start_o=0,pw_b=0,pw_o=0,dw_b=0,dw_o=0,dr_b=0,dr_o=0;
  logic [7:0] pa_b=0,pa_o=0,da_b=0,da_o=0,ra_b=0,ra_o=0;
  logic [31:0] pd_b=0,pd_o=0,dd_b=0,dd_o=0,rd_b,rd_o;
  logic busy_b,done_b,busy_o,done_o; logic [31:0] cyc_b,cyc_o;
  ai_cpu_validation_wrapper #(.OPTIMIZED(0)) b(.clk,.rst,.load_mode(lm_b),.start(start_b),.prog_we(pw_b),.prog_addr(pa_b),.prog_data(pd_b),.data_we(dw_b),.data_addr_host(da_b),.data_wdata(dd_b),.data_re(dr_b),.data_raddr(ra_b),.data_rdata(rd_b),.busy(busy_b),.done(done_b),.cycle_count(cyc_b));
  ai_cpu_validation_wrapper #(.OPTIMIZED(1)) o(.clk,.rst,.load_mode(lm_o),.start(start_o),.prog_we(pw_o),.prog_addr(pa_o),.prog_data(pd_o),.data_we(dw_o),.data_addr_host(da_o),.data_wdata(dd_o),.data_re(dr_o),.data_raddr(ra_o),.data_rdata(rd_o),.busy(busy_o),.done(done_o),.cycle_count(cyc_o));
  logic [31:0] bp[0:255],op[0:255]; integer i,j,errors=0; integer signed x[0:3];
  logic [31:0] expect0[0:3],expect1[0:3],expectc[0:3];
  logic [31:0] b0,b1,bc,o0,o1,oc,cb,co;
  task automatic put_prog(input bit opt,input integer a,input [31:0] v); begin if(opt) begin pa_o<=a;pd_o<=v;pw_o<=1;@(posedge clk);pw_o<=0;end else begin pa_b<=a;pd_b<=v;pw_b<=1;@(posedge clk);pw_b<=0;end @(posedge clk); end endtask
  task automatic put_data(input bit opt,input integer a,input [31:0] v); begin if(opt) begin da_o<=a;dd_o<=v;dw_o<=1;@(posedge clk);dw_o<=0;end else begin da_b<=a;dd_b<=v;dw_b<=1;@(posedge clk);dw_b<=0;end @(posedge clk); end endtask
  task automatic get_data(input bit opt,input integer a,output [31:0] v); begin if(opt) begin ra_o<=a;dr_o<=1;@(posedge clk);dr_o<=0;@(posedge clk);v=rd_o;end else begin ra_b<=a;dr_b<=1;@(posedge clk);dr_b<=0;@(posedge clk);v=rd_b;end end endtask
  task automatic run_variant(input bit opt,input integer n,input integer t,output [31:0] y0,output [31:0] y1,output [31:0] cls,output [31:0] cycles);
    integer k, timeout; reg [31:0] inpack;
    begin
      inpack = {x[3][7:0],x[2][7:0],x[1][7:0],x[0][7:0]};
      if(opt) begin lm_o<=1; for(k=0;k<n;k=k+1) put_prog(1,k,op[k]); put_data(1,16,inpack); put_data(1,20,32'h01010101); put_data(1,21,32'h01ff01ff); put_data(1,22,32'hff01ff01); put_data(1,23,32'h0101ffff); put_data(1,30,32'h80000000); lm_o<=0;@(posedge clk);start_o<=1;@(posedge clk);start_o<=0; timeout=0; while(done_o!==1 && timeout<10000) begin @(posedge clk); timeout=timeout+1; end if(done_o!==1) $fatal(1,"optimized timeout"); cycles=cyc_o;repeat(3)@(posedge clk);lm_o<=1;get_data(1,40,y0);get_data(1,41,y1);get_data(1,42,cls);end
      else begin lm_b<=1; for(k=0;k<n;k=k+1) put_prog(0,k,bp[k]); for(k=0;k<4;k=k+1) put_data(0,16+k,x[k]); put_data(0,30,32'h80000000); lm_b<=0;@(posedge clk);start_b<=1;@(posedge clk);start_b<=0; timeout=0; while(done_b!==1 && timeout<10000) begin @(posedge clk); timeout=timeout+1; end if(done_b!==1) $fatal(1,"baseline timeout"); cycles=cyc_b; repeat(3)@(posedge clk);lm_b<=1;get_data(0,40,y0);get_data(0,41,y1);get_data(0,42,cls);end
    end
  endtask
  initial begin
    $readmemh("C:/FPGA/systemverilog-fpga-cpu/programs/ai_tiny_nn_baseline.mem",bp); $readmemh("C:/FPGA/systemverilog-fpga-cpu/programs/ai_tiny_nn_dot4acc.mem",op);
    expect0[0]=12;expect1[0]=15;expectc[0]=1; expect0[1]=8;expect1[1]=7;expectc[1]=0; expect0[2]=6;expect1[2]=32'hfffffffd;expectc[2]=0; expect0[3]=18;expect1[3]=32'hfffffff9;expectc[3]=0;
    repeat(3)@(posedge clk);rst<=0;
    for(j=0;j<4;j=j+1) begin
      x[0]=j==0?1:j==1?3:j==2?-1:4; x[1]=j==0?2:j==1?-2:j==2?-2:1; x[2]=j==0?3:j==1?1:j==2?-3:2; x[3]=j==0?4:j==1?4:j==2?-4:-3;
      run_variant(0,75,j,b0,b1,bc,cb); run_variant(1,52,j,o0,o1,oc,co);
      if(b0!==expect0[j]||b1!==expect1[j]||bc!==expectc[j]) begin $display("BASE FAIL %0d %h %h %h",j,b0,b1,bc);errors=errors+1;end
      if(o0!==expect0[j]||o1!==expect1[j]||oc!==expectc[j]) begin $display("OPT FAIL %0d %h %h %h",j,o0,o1,oc);errors=errors+1;end
      if(b0!==o0||b1!==o1||bc!==oc) begin $display("EQUIV FAIL %0d",j);errors=errors+1;end
      $display("TEST%0d PASS baseline=%h,%h class=%h cycles=%0d optimized=%h,%h class=%h cycles=%0d",j+1,b0,b1,bc,cb,o0,o1,oc,co);
    end
    if(errors!=0)$fatal(1,"AI tiny NN failures=%0d",errors);
    $display("AI_TINY_NN_BASELINE_PASS");$display("AI_TINY_NN_DOT4ACC_PASS");$display("AI_TINY_NN_EQUIVALENCE_PASS");$display("AI_TINY_NN_END_TO_END_PASS");$finish;
  end
endmodule



