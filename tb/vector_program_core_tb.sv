`timescale 1ns/1ps
module vector_program_core_tb;
    localparam logic [3:0] VADD=4'h0, VSUB=4'h1, VXOR=4'h4, VCMPLT=4'h6, VSRA=4'h9;
    logic clk=0, rst=0, start=0;
    logic [4:0] program_length=0;
    logic running, done;
    logic [3:0] current_pc;
    logic [15:0] current_instruction;
    logic current_instruction_valid;
    logic prog_load_enable=0; logic [3:0] prog_load_addr=0; logic [15:0] prog_load_data=0;
    logic load_enable=0; logic [2:0] load_addr=0; logic [127:0] load_data=0;
    logic debug_read_enable=0; logic [2:0] debug_read_addr=0; logic [127:0] debug_read_data;
    int unsigned tests_run=0, tests_failed=0;
    vector_program_core dut (.*);
    always #5 clk=~clk;

    function automatic logic [127:0] p4(input logic [31:0] a,input logic [31:0] b,input logic [31:0] c,input logic [31:0] d);
        p4={d,c,b,a};
    endfunction
    function automatic logic [15:0] enc(input logic [3:0] op,input logic [2:0] d,input logic [2:0] a,input logic [2:0] b);
        enc={op,d,a,b,3'b000};
    endfunction
    task automatic check(input logic cond,input string msg);
        begin tests_run++; if(!cond) begin tests_failed++; $error("FAIL: %s",msg); end else $display("PASS: %s",msg); end
    endtask
    task automatic load_vec(input logic [2:0] a,input logic [127:0] v);
        begin load_addr=a; load_data=v; load_enable=1; @(posedge clk); #1; load_enable=0; end
    endtask
    task automatic read_vec(input logic [2:0] a,input logic [127:0] expected,input string msg);
        begin debug_read_enable=1; debug_read_addr=a; #1; tests_run++; if(debug_read_data!==expected) begin tests_failed++; $error("FAIL: %s expected=%h got=%h",msg,expected,debug_read_data); end else $display("PASS: %s value=%h",msg,debug_read_data); debug_read_enable=0; end
    endtask
    task automatic load_prog(input logic [3:0] a,input logic [15:0] ins);
        begin prog_load_addr=a; prog_load_data=ins; prog_load_enable=1; @(posedge clk); #1; prog_load_enable=0; end
    endtask
    task automatic pulse_start;
        begin start=1; @(posedge clk); #1; start=0; end
    endtask
    task automatic wait_done(input int limit);
        int i;
        begin i=0; while(!done && i<limit) begin @(posedge clk); #1; i++; end check(done,"program reaches done"); end
    endtask
    task automatic reset_core;
        begin rst=1; @(posedge clk); #1; rst=0; end
    endtask

    initial begin
        reset_core();
        check(current_pc===0 && !running && !done,"reset clears control state");
        load_vec(3,p4(1,2,3,4)); load_vec(1,p4(1,2,3,4)); load_vec(2,p4(5,6,7,8));
        load_prog(0,enc(VADD,3,1,2));
        load_prog(1,enc(VSUB,4,3,1));
        load_prog(2,enc(VXOR,5,3,4));
        load_prog(3,enc(VCMPLT,6,1,2));
        check(current_instruction===enc(VADD,3,1,2),"program memory readback at PC zero");
        program_length=0; pulse_start(); check(done && !running && current_pc===0,"zero-length program completes immediately");

        program_length=4; pulse_start(); check(running && !done && current_pc===0,"start enters running at PC zero");
        @(posedge clk); #1; check(current_pc===1,"PC advances to one");
        start=1; @(posedge clk); #1; start=0; check(current_pc===2,"start while running is ignored");
        @(posedge clk); #1; check(current_pc===3,"PC advances to three");
        @(posedge clk); #1; check(done && !running && current_pc===3,"final instruction completes at PC three");
        read_vec(3,p4(6,8,10,12),"V3 dependent-program result");
        read_vec(4,p4(5,6,7,8),"V4 dependent-program result");
        read_vec(5,p4(3,14,13,4),"V5 dependent-program result");
        read_vec(6,p4(1,1,1,1),"V6 signed compare result");
        repeat(3) @(posedge clk); #1; check(current_pc===3,"no sequencing after done");

        // Invalid instruction is a no-write slot and PC still advances.
        reset_core(); load_vec(1,p4(1,2,3,4)); load_vec(2,p4(5,6,7,8));
        load_prog(0,enc(VADD,3,1,2)); load_prog(1,16'hA000); load_prog(2,enc(VSUB,4,3,1));
        program_length=3; pulse_start(); wait_done(8);
        read_vec(3,p4(6,8,10,12),"invalid slot preserves prior result");
        read_vec(4,p4(5,6,7,8),"instruction after invalid slot executes");

        // Restart after completion.
        pulse_start(); wait_done(8); read_vec(4,p4(5,6,7,8),"restart after done");

        // A register load wins on the same edge an instruction would execute.
        reset_core(); load_vec(1,p4(1,2,3,4)); load_vec(2,p4(5,6,7,8));
        load_prog(0,enc(VADD,3,1,2)); program_length=1; pulse_start();
        load_addr=3; load_data=p4(9,9,9,9); load_enable=1; @(posedge clk); #1; load_enable=0;
        check(done && !running,"load-priority program completes");
        read_vec(3,p4(9,9,9,9),"vector load priority over execution");

        // Program writes while running are ignored by policy.
        reset_core(); load_vec(1,p4(1,2,3,4)); load_vec(2,p4(5,6,7,8));
        load_prog(0,enc(VADD,3,1,2)); load_prog(1,enc(VSUB,4,3,1)); program_length=2; pulse_start();
        prog_load_addr=1; prog_load_data=enc(VXOR,4,1,2); prog_load_enable=1; @(posedge clk); #1; prog_load_enable=0;
        wait_done(8); read_vec(4,p4(5,6,7,8),"program load while running is ignored");

        // Signed compare and arithmetic shift in stored instructions.
        reset_core(); load_vec(1,p4(32'h80000000,32'h00000001,32'hffffffff,32'h7fffffff));
        load_vec(2,p4(32'h00000001,32'h00000000,32'h00000000,32'hffffffff));
        load_prog(0,enc(VCMPLT,3,1,2)); load_prog(1,enc(VSRA,4,1,2)); program_length=2; pulse_start(); wait_done(8);
        read_vec(3,p4(1,0,1,0),"stored signed compare");
        read_vec(4,p4(32'hc0000000,1,32'hffffffff,32'h00000000),"stored arithmetic shift");

        if(tests_failed==0) begin $display("Tests run: %0d",tests_run); $display("Tests failed: 0"); $display("VECTOR PROGRAM CORE TEST PASSED"); end
        else begin $display("Tests run: %0d",tests_run); $display("Tests failed: %0d",tests_failed); $display("VECTOR PROGRAM CORE TEST FAILED"); $fatal(1); end
        $finish;
    end
endmodule
