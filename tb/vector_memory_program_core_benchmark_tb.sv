`timescale 1ns/1ps
module vector_memory_program_core_benchmark_tb;
    localparam logic [3:0] VADD=4'h0, VXOR=4'h4, VCMPLT=4'h6, VSRA=4'h9;
    logic clk=0,rst=0,start=0; logic [4:0] program_length=0; logic running,done;
    logic [3:0] current_pc; logic [15:0] current_instruction; logic current_instruction_valid;
    logic prog_load_enable=0; logic [3:0] prog_load_addr=0; logic [15:0] prog_load_data=0;
    logic data_load_enable=0; logic [4:0] data_load_addr=0; logic [127:0] data_load_data=0;
    logic data_debug_read_enable=0; logic [4:0] data_debug_read_addr=0; logic [127:0] data_debug_read_data;
    logic vector_load_enable=0; logic [2:0] vector_load_addr=0; logic [127:0] vector_load_data=0;
    logic debug_read_enable=0; logic [2:0] debug_read_addr=0; logic [127:0] debug_read_data; logic [2:0] state_debug;
    int unsigned failures=0; int cycles;
    vector_memory_program_core dut(.*); always #5 clk=~clk;
    function automatic logic [127:0] p4(input logic [31:0]a,input logic [31:0]b,input logic [31:0]c,input logic [31:0]d); p4={d,c,b,a}; endfunction
    function automatic logic [15:0] alu(input logic[3:0]op,input logic[2:0]d,input logic[2:0]a,input logic[2:0]b); alu={op,d,a,b,3'b0}; endfunction
    function automatic logic [15:0] ld(input logic[2:0]d,input logic[4:0]a); ld={4'ha,d,a,4'b0}; endfunction
    function automatic logic [15:0] st(input logic[2:0]s,input logic[4:0]a); st={4'hb,s,a,4'b0}; endfunction
    task automatic reset_core; begin rst=1; @(posedge clk); #1; rst=0; end endtask
    task automatic load_data_word(input logic[4:0]a,input logic[127:0]v); begin data_load_addr=a;data_load_data=v;data_load_enable=1;@(posedge clk);#1;data_load_enable=0;end endtask
    task automatic load_vec(input logic[2:0]a,input logic[127:0]v); begin vector_load_addr=a;vector_load_data=v;vector_load_enable=1;@(posedge clk);#1;vector_load_enable=0;end endtask
    task automatic load_ins(input int a,input logic[15:0]v); begin prog_load_addr=a;prog_load_data=v;prog_load_enable=1;@(posedge clk);#1;prog_load_enable=0;end endtask
    task automatic read_mem(input logic[4:0]a,input logic[127:0]e,input string m); begin data_debug_read_addr=a;data_debug_read_enable=1;@(posedge clk);#1;data_debug_read_enable=0;if(data_debug_read_data!==e)begin failures++;$error("FAIL %s",m);end end endtask
    task automatic run_program(input int length,output int measured); int n; begin program_length=length; start=1; @(posedge clk); #1; start=0; measured=0; while(!done && measured<100) begin @(posedge clk); #1; measured++; end if(!done)begin failures++;$error("TIMEOUT");end end endtask
    task automatic print_result(input string name,input int vecs,input int scalars,input int loads,input int stores,input int alus,input int measured,input int bytes,input logic pass); real cpv,cpe,opc,frac; begin cpv=real'(measured)/vecs;cpe=real'(measured)/scalars;opc=real'(scalars)/measured;frac=real'(alus)/measured;$display("BENCHMARK: %s",name);$display("Vectors processed: %0d",vecs);$display("Scalar elements: %0d",scalars);$display("VLOAD count: %0d",loads);$display("VSTORE count: %0d",stores);$display("ALU count: %0d",alus);$display("Total cycles: %0d",measured);$display("Cycles/vector: %0.3f",cpv);$display("Cycles/scalar element: %0.3f",cpe);$display("Useful scalar ops/cycle: %0.6f",opc);$display("ALU execution fraction: %0.6f",frac);$display("Logical bytes: %0d",bytes);$display("Result: %s",pass?"PASS":"FAIL"); end endtask
    initial begin
      logic[127:0] va,vb,mask,exp; logic pass; int c;
      va=p4(1,2,3,4); vb=p4(5,6,7,8); mask=p4(32'hffff0000,32'h0000ffff,32'h00ff00ff,32'hff00ff00);
      reset_core(); load_vec(1,va);load_vec(2,vb);load_ins(0,alu(VADD,3,1,2));load_ins(1,alu(VADD,4,3,2));load_ins(2,alu(VADD,5,4,1));load_ins(3,alu(VADD,6,5,2)); run_program(4,c); exp=p4(17,22,27,32); debug_read_enable=1;debug_read_addr=6;#1;pass=(debug_read_data===exp);debug_read_enable=0; if(!pass)failures++; print_result("REGISTER-ONLY ALU",4,16,0,0,4,c,0,pass);
      reset_core(); for(int i=0;i<4;i++)begin load_data_word(i,p4(i+1,i+2,i+3,i+4));load_data_word(8+i,p4(10+i,20+i,30+i,40+i));end for(int i=0;i<4;i++)begin load_ins(4*i,ld(1,i));load_ins(4*i+1,ld(2,8+i));load_ins(4*i+2,alu(VADD,3,1,2));load_ins(4*i+3,st(3,16+i));end run_program(16,c);pass=1;for(int i=0;i<4;i++)begin exp=p4((i+1)+(10+i),(i+2)+(20+i),(i+3)+(30+i),(i+4)+(40+i));read_mem(16+i,exp,"array add result");end print_result("VECTOR ARRAY ADD",4,16,8,4,4,c,192,(failures==0));
      reset_core();load_vec(2,mask);for(int i=0;i<4;i++)begin load_data_word(i,p4(i,i+1,i+2,i+3));load_ins(3*i,ld(1,i));load_ins(3*i+1,alu(VXOR,3,1,2));load_ins(3*i+2,st(3,16+i));end run_program(12,c);pass=1;for(int i=0;i<4;i++)begin exp=p4(i^32'hffff0000,(i+1)^32'h0000ffff,(i+2)^32'h00ff00ff,(i+3)^32'hff00ff00);read_mem(16+i,exp,"unary transform result");end print_result("PIXEL-LIKE XOR",4,16,4,4,4,c,128,(failures==0));
      reset_core();load_vec(2,p4(1,1,1,1));for(int i=0;i<4;i++)begin load_data_word(i,p4(32'h80000000+i,32'h00000001,32'hffffffff,32'h7fffffff));load_ins(3*i,ld(1,i));load_ins(3*i+1,alu(VSRA,3,1,2));load_ins(3*i+2,st(3,16+i));end run_program(12,c);pass=1;for(int i=0;i<4;i++)begin exp=p4(32'hc0000000+(i>>1),0,32'hffffffff,32'h3fffffff);read_mem(16+i,exp,"shift result");end print_result("SHIFT TRANSFORM",4,16,4,4,4,c,128,(failures==0));
      if(failures==0)begin $display("VECTOR MEMORY BENCHMARK TEST PASSED");end else begin $display("VECTOR MEMORY BENCHMARK TEST FAILED failures=%0d",failures);$fatal(1);end $finish;
    end
endmodule
