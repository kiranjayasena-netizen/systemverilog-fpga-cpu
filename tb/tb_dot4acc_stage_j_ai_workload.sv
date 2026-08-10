import cpu_defs_pkg::*;

// Stage J application-level evaluation.  This testbench intentionally uses
// the frozen H1.3b/T2 core without changing its RTL or timing structure.
module tb_dot4acc_stage_j_ai_workload;
    localparam int IMEM_DEPTH = 256;
    localparam int DMEM_DEPTH = 256;
    localparam logic [31:0] NOP = {OP_NOP, 28'h0};
    localparam int FREQ_MHZ = 93;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b1;

    logic [31:0] fetch_pc, instruction_addr, fetch_request_pc;
    logic fetch_request_valid, if_id_valid, id_ex_valid, ex_mem_valid, mem_wb_valid;
    logic [31:0] if_id_pc, if_id_instruction, alu_result, data_addr, memory_read_data;
    logic [3:0] decoded_opcode;
    logic decoded_valid, retire_valid, retire_reg_write, retire_mem_write;
    logic [31:0] retire_pc, retire_write_data, retire_mem_addr, retire_mem_data;
    logic [3:0] retire_opcode;
    logic [4:0] retire_rd;
    logic reg_write, mem_write, pc_redirect;
    logic [31:0] total_cycles, retired_instructions, pipeline_fill_cycles;
    logic [31:0] data_hazard_stall_cycles, load_use_stall_cycles;
    logic [31:0] control_hazard_flush_cycles, instruction_fetch_wait_cycles;
    logic [31:0] memory_wait_cycles, taken_branches, not_taken_branches, jumps;
    logic [31:0] wrong_path_instructions_flushed;
    logic dot_issue_valid, dot_issue_accept, dot_issue_chain, dot_complete_valid;
    logic dot_complete_eligible, normal_wb_valid, dot_wb_valid, rf_write_enable;
    logic dot_retire_valid, dot_active, dot_frontend_hold, dot_dependency_stall;
    logic dot_source_dependency_stall, dot_accumulator_dependency_stall, dot_cancel_event;
    logic [4:0] dot_issue_rd, dot_complete_rd, rf_write_addr;
    logic [31:0] dot_issue_packed_a, dot_issue_packed_b, dot_issue_accumulator;
    logic [31:0] dot_issue_pc, dot_complete_result, dot_complete_pc, rf_write_data;
    logic [3:0] dot_issue_opcode, dot_complete_opcode;
    logic [3:0] dot_inflight_valid;
    logic [19:0] dot_inflight_rd;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(IMEM_DEPTH), .DMEM_DEPTH(DMEM_DEPTH), .IMEM_INIT_FILE("")
    ) dut (.*);

    always #5 clk = ~clk;

    function automatic logic [31:0] enc(
        input logic [3:0] op, input logic [4:0] rd, input logic [4:0] rs1,
        input logic [4:0] rs2, input integer imm);
        enc = {op, rd, rs1, rs2, imm[12:0]};
    endfunction

    function automatic logic [31:0] dot_enc(input logic [4:0] rd,
                                             input logic [4:0] rs1,
                                             input logic [4:0] rs2);
        dot_enc = {OP_DOT4ACC, rd, rs1, rs2, 13'd0};
    endfunction

    function automatic integer signed sample_a(input integer i);
        integer v;
        begin
            v = ((i * 37 + 17) % 251) - 125;
            if (i == 0) v = 127;
            if (i == 1) v = -128;
            if (i == 2) v = -1;
            if (i == 3) v = 1;
            sample_a = v;
        end
    endfunction

    function automatic integer signed sample_b(input integer i);
        integer v;
        begin
            v = ((i * 53 + 91) % 251) - 125;
            if ((i % 11) == 0) v = 0;
            if (i == 4) v = -128;
            if (i == 5) v = 127;
            sample_b = v;
        end
    endfunction

    function automatic integer signed weight(input integer row, input integer i);
        integer v;
        begin
            v = (((row + 3) * (i + 7) * 19 + 23) % 251) - 125;
            if ((i % 13) == 0) v = 0;
            if ((row == 0) && (i == 1)) v = -128;
            if ((row == 1) && (i == 2)) v = 127;
            weight = v;
        end
    endfunction

    function automatic logic [31:0] pack4(input integer signed x0, input integer signed x1,
                                           input integer signed x2, input integer signed x3);
        pack4 = {x3[7:0], x2[7:0], x1[7:0], x0[7:0]};
    endfunction

    function automatic logic [31:0] ref_dot(input logic [31:0] acc,
                                            input logic [31:0] a, input logic [31:0] b);
        logic signed [31:0] sum;
        logic signed [7:0] av, bv;
        integer lane;
        begin
            sum = $signed(acc);
            for (lane = 0; lane < 4; lane = lane + 1) begin
                av = a[8*lane +: 8];
                bv = b[8*lane +: 8];
                sum = sum + av * bv;
            end
            ref_dot = sum;
        end
    endfunction

    task automatic clear_state;
        integer i;
        begin
            rst = 1'b1;
            for (i = 0; i < IMEM_DEPTH; i = i + 1) dut.instr_mem_inst.mem[i] = NOP;
            for (i = 0; i < DMEM_DEPTH; i = i + 1) dut.data_mem_inst.mem[i] = 32'd0;
            dut.regs[0] = 32'd0;
            dut.regs[9] = 32'd0;
            dut.regs[10] = 32'd0;
            dut.regs[11] = 32'd0;
            repeat (3) @(posedge clk);
            #1;
        end
    endtask

    task automatic run_program(input integer expected_stores, input integer max_cycles,
                               output integer cycles, output integer retired,
                               output integer loads, output integer stores,
                               output integer dots, output integer scalar,
                               output integer branches, output integer dot_issues,
                               output integer hold_cycles, output logic timed_out);
        integer c;
        begin
            rst = 1'b0;
            cycles = 0; retired = 0; loads = 0; stores = 0; dots = 0;
            scalar = 0; branches = 0; dot_issues = 0; hold_cycles = 0;
            timed_out = 1'b0;
            while ((stores < expected_stores) && (cycles < max_cycles)) begin
                @(posedge clk); #1;
                cycles = cycles + 1;
                if (dot_issue_accept) dot_issues = dot_issues + 1;
                if (dot_frontend_hold || dut.scalar_overlap_hold || dut.dot_issue_stall || dut.decode_stall)
                    hold_cycles = hold_cycles + 1;
                if (retire_valid) begin
                    retired = retired + 1;
                    case (retire_opcode)
                        OP_LOAD: loads = loads + 1;
                        OP_STORE: stores = stores + 1;
                        OP_DOT4ACC: dots = dots + 1;
                        OP_BEQ, OP_JUMP: branches = branches + 1;
                        OP_NOP: ;
                        default: scalar = scalar + 1;
                    endcase
                end
            end
            if (stores < expected_stores) timed_out = 1'b1;
            rst = 1'b1;
            repeat (2) @(posedge clk);
            #1;
        end
    endtask

    task automatic load_j1_data(input integer n);
        integer i, w, words;
        begin
            words = n / 4;
            for (w = 0; w < words; w = w + 1) begin
                dut.data_mem_inst.mem[w] = pack4(sample_a(4*w), sample_a(4*w+1),
                                                  sample_a(4*w+2), sample_a(4*w+3));
                dut.data_mem_inst.mem[32+w] = pack4(sample_b(4*w), sample_b(4*w+1),
                                                    sample_b(4*w+2), sample_b(4*w+3));
            end
        end
    endtask

    task automatic build_j1(input integer n, output logic [31:0] expected);
        integer pc, w, words;
        logic [31:0] acc, wa, wb;
        begin
            clear_state();
            load_j1_data(n);
            words = n / 4; acc = 32'd0;
            pc = 0;
            for (w = 0; w < words; w = w + 1) begin
                dut.instr_mem_inst.mem[pc] = enc(OP_LOAD, 5'd1, 5'd10, 5'd0, 0); pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = enc(OP_LOAD, 5'd2, 5'd11, 5'd0, 0); pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = dot_enc(5'd9, 5'd1, 5'd2); pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = enc(OP_ADDI, 5'd10, 5'd10, 5'd0, 4); pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = enc(OP_ADDI, 5'd11, 5'd11, 5'd0, 4); pc = pc + 1;
                wa = dut.data_mem_inst.mem[w]; wb = dut.data_mem_inst.mem[32+w];
                acc = ref_dot(acc, wa, wb);
            end
            dut.instr_mem_inst.mem[pc] = enc(OP_STORE, 5'd0, 5'd0, 5'd9, 252);
            dut.regs[10] = 0; dut.regs[11] = 128; dut.regs[9] = 0;
            expected = acc;
        end
    endtask

    task automatic build_j2(output logic [31:0] expected0, output logic [31:0] expected1);
        integer i, pc, row;
        logic [31:0] acc, iw, ww;
        begin
            clear_state();
            // Reuse the independently generated 128-element vectors: input
            // words are 0..31, weight row 0 is 32..47, row 1 is 48..63.
            load_j1_data(128);
            pc = 0;
            for (row = 0; row < 2; row = row + 1) begin
                acc = 0;
                for (i = 0; i < 16; i = i + 1) begin
                    dut.instr_mem_inst.mem[pc] = enc(OP_LOAD, 5'd1, 5'd10, 5'd0, i*4); pc = pc + 1;
                    dut.instr_mem_inst.mem[pc] = enc(OP_LOAD, 5'd2, 5'd11, 5'd0, row*64 + i*4); pc = pc + 1;
                    dut.instr_mem_inst.mem[pc] = dot_enc((row == 0) ? 5'd9 : 5'd8, 5'd1, 5'd2); pc = pc + 1;
                    dut.instr_mem_inst.mem[pc] = enc(OP_ADDI, 5'd12, 5'd12, 5'd0, 1); pc = pc + 1;
                    iw = dut.data_mem_inst.mem[i]; ww = dut.data_mem_inst.mem[32 + row*16 + i];
                    acc = ref_dot(acc, iw, ww);
                end
                dut.instr_mem_inst.mem[pc] = enc(OP_STORE, 5'd0, 5'd0, (row == 0) ? 5'd9 : 5'd8, 400 + row*4); pc = pc + 1;
                // Keep the next accumulator initialisation outside the fixed
                // DOT completion/writeback window.  These are architectural
                // NOPs, not a DUT change, and make the two-output kernel's
                // program boundary explicit.
                dut.instr_mem_inst.mem[pc] = NOP; pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = NOP; pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = NOP; pc = pc + 1;
                dut.instr_mem_inst.mem[pc] = NOP; pc = pc + 1;
                if (row == 0) expected0 = acc; else expected1 = acc;
            end
            dut.regs[10] = 0; dut.regs[11] = 128; dut.regs[12] = 0;
        end
    endtask

    integer c, r, l, s, d, sc, br, di, hc;
    logic timeout;
    logic [31:0] exp, exp0, exp1;
    integer csv;
    initial begin
        csv = $fopen("reports/dot4acc_stage_j/results.csv", "w");
        $fdisplay(csv, "benchmark,N,outputs,useful_macs,total_cycles,retired_instructions,load_count,store_count,dot4acc_count,scalar_count,branch_count,stall_cycles,mac_per_cycle,validated_mhz,mmac_per_s,result_check,expected_result,actual_result");
        build_j1(32, exp); run_program(1, 2000, c,r,l,s,d,sc,br,di,hc,timeout);
        $display("J1 N=32 cycles=%0d retired=%0d LOAD=%0d STORE=%0d DOT=%0d scalar=%0d branch=%0d hold=%0d MAC/cycle=%f result=%h expected=%h %s", c,r,l,s,d,sc,br,hc,32.0/c, dut.data_mem_inst.mem[63], exp, (timeout || dut.data_mem_inst.mem[63] != exp) ? "FAIL" : "PASS");
        $fdisplay(csv, "J1,32,1,32,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%f,%0d,%f,%s,%h,%h",c,r,l,s,d,sc,br,hc,32.0/c,FREQ_MHZ,(32.0/c)*FREQ_MHZ,(timeout || dut.data_mem_inst.mem[63] != exp)?"FAIL":"PASS",exp,dut.data_mem_inst.mem[63]);
        build_j1(64, exp); run_program(1, 3000, c,r,l,s,d,sc,br,di,hc,timeout);
        $display("J1 N=64 cycles=%0d retired=%0d LOAD=%0d STORE=%0d DOT=%0d scalar=%0d branch=%0d hold=%0d result=%h expected=%h %s", c,r,l,s,d,sc,br,hc,dut.data_mem_inst.mem[63],exp,(timeout || dut.data_mem_inst.mem[63] != exp)?"FAIL":"PASS");
        $fdisplay(csv, "J1,64,1,64,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%f,%0d,%f,%s,%h,%h",c,r,l,s,d,sc,br,hc,64.0/c,FREQ_MHZ,(64.0/c)*FREQ_MHZ,(timeout || dut.data_mem_inst.mem[63] != exp)?"FAIL":"PASS",exp,dut.data_mem_inst.mem[63]);
        build_j1(128, exp); run_program(1, 5000, c,r,l,s,d,sc,br,di,hc,timeout);
        $display("J1 N=128 cycles=%0d retired=%0d LOAD=%0d STORE=%0d DOT=%0d scalar=%0d branch=%0d hold=%0d result=%h expected=%h %s", c,r,l,s,d,sc,br,hc,dut.data_mem_inst.mem[63],exp,(timeout || dut.data_mem_inst.mem[63] != exp)?"FAIL":"PASS");
        $fdisplay(csv, "J1,128,1,128,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%f,%0d,%f,%s,%h,%h",c,r,l,s,d,sc,br,hc,128.0/c,FREQ_MHZ,(128.0/c)*FREQ_MHZ,(timeout || dut.data_mem_inst.mem[63] != exp)?"FAIL":"PASS",exp,dut.data_mem_inst.mem[63]);
        build_j2(exp0, exp1); run_program(2, 8000, c,r,l,s,d,sc,br,di,hc,timeout);
        $display("J2 2x64 cycles=%0d retired=%0d LOAD=%0d STORE=%0d DOT=%0d scalar=%0d branch=%0d hold=%0d out0=%h/%h out1=%h/%h %s", c,r,l,s,d,sc,br,hc,dut.data_mem_inst.mem[100],exp0,dut.data_mem_inst.mem[101],exp1,(timeout || dut.data_mem_inst.mem[100] != exp0 || dut.data_mem_inst.mem[101] != exp1)?"FAIL":"PASS");
        $fdisplay(csv, "J2,64,2,128,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%f,%0d,%f,%s,%h|%h,%h|%h",c,r,l,s,d,sc,br,hc,128.0/c,FREQ_MHZ,(128.0/c)*FREQ_MHZ,(timeout || dut.data_mem_inst.mem[100] != exp0 || dut.data_mem_inst.mem[101] != exp1)?"FAIL":"PASS",exp0,exp1,dut.data_mem_inst.mem[100],dut.data_mem_inst.mem[101]);
        $fclose(csv);
        if (timeout) $fatal(1, "Stage J timed out");
        $display("STAGE J PASS");
        $finish;
    end
endmodule
