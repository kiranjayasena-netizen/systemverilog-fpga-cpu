`timescale 1ns/1ps
module vector_data_memory_tb;
    logic clk=0, read_enable=0, write_enable=0;
    logic [4:0] read_addr=0, write_addr=0;
    logic [127:0] write_data=0, read_data;
    int unsigned tests_run=0, tests_failed=0;
    vector_data_memory dut(.*);
    always #5 clk=~clk;

    function automatic logic [127:0] p4(input logic [31:0] a,input logic [31:0] b,input logic [31:0] c,input logic [31:0] d);
        p4={d,c,b,a};
    endfunction
    task automatic check(input logic [127:0] expected,input string msg);
        begin tests_run++; if(read_data!==expected) begin tests_failed++; $error("FAIL: %s expected=%h got=%h",msg,expected,read_data); end else $display("PASS: %s",msg); end
    endtask
    task automatic write_mem(input logic [4:0] a,input logic [127:0] v);
        begin write_addr=a; write_data=v; write_enable=1; @(posedge clk); #1; write_enable=0; end
    endtask
    task automatic read_mem(input logic [4:0] a,input logic [127:0] expected,input string msg);
        begin read_addr=a; read_enable=1; @(posedge clk); #1; read_enable=0; check(expected,msg); end
    endtask
    initial begin
        logic [127:0] a,b;
        a=p4(32'h11111111,32'h22222222,32'h33333333,32'h44444444);
        b=p4(32'hdeadbeef,32'h12345678,32'h0badcafe,32'hcafebabe);
        write_mem(0,a); read_mem(0,a,"basic write/read and lane order");
        write_mem(1,p4(1,2,3,4)); write_mem(7,p4(5,6,7,8)); write_mem(15,p4(9,10,11,12)); write_mem(31,b);
        read_mem(1,p4(1,2,3,4),"address 1"); read_mem(7,p4(5,6,7,8),"address 7");
        read_mem(15,p4(9,10,11,12),"address 15"); read_mem(31,b,"boundary address 31");
        write_mem(7,a); read_mem(7,a,"overwrite A"); write_mem(7,b); read_mem(7,b,"overwrite B");
        write_addr=7; write_data=a; write_enable=0; @(posedge clk); #1; read_mem(7,b,"write disabled holds memory");
        read_mem(1,p4(1,2,3,4),"read timing setup");
        read_addr=7; read_enable=0; @(negedge clk); #1; check(p4(1,2,3,4),"read disabled holds previous output");
        read_addr=1; read_enable=0; #1; check(p4(1,2,3,4),"address change without edge does not update");
        read_enable=1; @(posedge clk); #1; read_enable=0; check(p4(1,2,3,4),"registered read updates on edge");
        write_addr=15; write_data=a; write_enable=1; read_addr=15; read_enable=1; @(posedge clk); #1; write_enable=0; read_enable=0;
        check(p4(9,10,11,12),"different-address simultaneous read/write read side");
        read_mem(15,a,"different-address simultaneous read/write write side");
        write_mem(0,b); write_addr=0; write_data=a; read_addr=0; write_enable=1; read_enable=1; @(posedge clk); #1; write_enable=0; read_enable=0;
        check(b,"same-address read/write is READ-FIRST"); read_mem(0,a,"same-address write is visible next read");
        for (int i=0;i<8;i++) write_mem(i,p4(32'h1000+i,32'h2000+i,32'h3000+i,32'h4000+i));
        for (int i=0;i<8;i++) read_mem(i,p4(32'h1000+i,32'h2000+i,32'h3000+i,32'h4000+i),"deterministic multi-entry sanity");
        if(tests_failed==0) begin $display("Tests run: %0d",tests_run); $display("Tests failed: 0"); $display("VECTOR DATA MEMORY TEST PASSED"); end
        else begin $display("Tests run: %0d",tests_run); $display("Tests failed: %0d",tests_failed); $display("VECTOR DATA MEMORY TEST FAILED"); $fatal(1); end
        $finish;
    end
endmodule
