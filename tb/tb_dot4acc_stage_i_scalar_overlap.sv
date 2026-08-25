import cpu_defs_pkg::*;

// Stage I measurement-only study.  This testbench deliberately instantiates
// the frozen H1.3b-T2 core and does not alter architectural RTL.
module tb_dot4acc_stage_i_scalar_overlap;
    localparam int IMEM_DEPTH = 256;
    localparam int DMEM_DEPTH = 256;
    localparam logic [31:0] NOP = {OP_NOP, 28'h0};

    logic clk = 1'b0, rst = 1'b1, enable = 1'b1;
    always #5 clk = ~clk;

    logic [31:0] total_cycles, retired_instructions;
    logic retire_valid, dot_issue_accept, dot_complete_valid;
    logic dot_frontend_hold, dot_active;
    logic [3:0] retire_opcode;
    logic [31:0] load_use_stall_cycles, data_hazard_stall_cycles;
    logic [31:0] control_hazard_flush_cycles, instruction_fetch_wait_cycles;
    logic [31:0] memory_wait_cycles;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(IMEM_DEPTH), .DMEM_DEPTH(DMEM_DEPTH), .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk), .rst(rst), .enable(enable),
        .retire_valid(retire_valid), .retire_opcode(retire_opcode),
        .total_cycles(total_cycles), .retired_instructions(retired_instructions),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .dot_issue_accept(dot_issue_accept), .dot_complete_valid(dot_complete_valid),
        .dot_frontend_hold(dot_frontend_hold), .dot_active(dot_active)
    );

    function automatic logic [31:0] ins(input logic [3:0] op, input int rd,
                                        input int rs1, input int rs2, input int imm);
        ins = {op, rd[4:0], rs1[4:0], rs2[4:0], imm[12:0]};
    endfunction
    function automatic logic [31:0] dot(input int rd, input int rs1, input int rs2);
        dot = ins(OP_DOT4ACC, rd, rs1, rs2, 0);
    endfunction
    function automatic logic [31:0] addi(input int rd, input int rs1, input int imm);
        addi = ins(OP_ADDI, rd, rs1, 0, imm);
    endfunction
    function automatic logic [31:0] store(input int rs2, input int rs1, input int imm);
        store = ins(OP_STORE, 0, rs1, rs2, imm);
    endfunction
    function automatic logic [31:0] beq(input int rs1, input int rs2, input int imm);
        beq = ins(OP_BEQ, 0, rs1, rs2, imm);
    endfunction

    int scalar_hold, overlap_hold, dot_stall, deferred_hold, decode_stall, dots, scalars;
    int cycle_start, retire_target;

    task automatic clear_program();
        for (int i = 0; i < IMEM_DEPTH; i++) dut.instr_mem_inst.mem[i] = NOP;
        for (int i = 0; i < DMEM_DEPTH; i++) dut.data_mem_inst.mem[i] = 32'h0;
        dut.regs[0] = 0; dut.regs[1] = 32'h0102_0304; dut.regs[2] = 32'h0506_0708;
        dut.regs[10] = 0; dut.regs[11] = 0; dut.regs[12] = 0;
    endtask

    task automatic reset_core();
        rst = 1'b1; repeat (3) @(posedge clk); #1; rst = 1'b0;
        cycle_start = total_cycles; scalar_hold = 0; overlap_hold = 0; dot_stall = 0;
        deferred_hold = 0; decode_stall = 0; dots = 0; scalars = 0;
    endtask

    task automatic run_case(input string name, input int count);
        int timeout;
        reset_core();
        timeout = 0;
        while ((retired_instructions < count) && (timeout < 300)) begin
            @(posedge clk); #1; timeout++;
            if (dut.dot_younger_non_dot_hold) scalar_hold++;
            if (dut.scalar_overlap_hold) overlap_hold++;
            if (dut.dot_issue_stall) dot_stall++;
            if (dut.scalar_overlap_hold) deferred_hold++;
            if (dut.decode_stall) decode_stall++;
            if (dot_issue_accept) dots++;
            if (retire_valid && retire_opcode != OP_DOT4ACC) scalars++;
        end
        if (timeout >= 300) $fatal(1, "%s timeout", name);
        $display("STAGE_I,%s,cycles=%0d,retired=%0d,dots=%0d,scalars=%0d,scalar_hold=%0d,overlap_hold=%0d,dot_stall=%0d,deferred_hold=%0d,decode_stall=%0d,redirects=%0d",
                 name, total_cycles-cycle_start, retired_instructions, dots, scalars,
                 scalar_hold, overlap_hold, dot_stall, deferred_hold, decode_stall,
                 control_hazard_flush_cycles);
    endtask

    initial begin
        clear_program();
        // I-A: independent scalar ALU between two DOTs.
        dut.instr_mem_inst.mem[0] = dot(9,1,2);
        dut.instr_mem_inst.mem[1] = addi(10,10,1);
        dut.instr_mem_inst.mem[2] = dot(9,1,2);
        dut.instr_mem_inst.mem[3] = addi(10,10,1);
        run_case("I-A-independent-addi", 4);

        // I-B: several independent pointer/counter updates.
        clear_program();
        dut.instr_mem_inst.mem[0] = dot(9,1,2);
        dut.instr_mem_inst.mem[1] = addi(10,10,1);
        dut.instr_mem_inst.mem[2] = addi(11,11,1);
        dut.instr_mem_inst.mem[3] = addi(12,12,-1);
        dut.instr_mem_inst.mem[4] = dot(9,1,2);
        run_case("I-B-three-independent-addi", 5);

        // I-C: negative control; scalar RAW depends on DOT destination.
        clear_program();
        dut.instr_mem_inst.mem[0] = dot(9,1,2);
        dut.instr_mem_inst.mem[1] = addi(10,9,1);
        dut.instr_mem_inst.mem[2] = dot(9,1,2);
        run_case("I-C-dot-raw", 3);

        // I-D: mixed memory-feed shape with independent pointer work.
        clear_program();
        dut.data_mem_inst.mem[0] = 32'h0102_0304;
        dut.data_mem_inst.mem[1] = 32'h0506_0708;
        dut.instr_mem_inst.mem[0] = ins(OP_LOAD,1,10,0,0);
        dut.instr_mem_inst.mem[1] = ins(OP_LOAD,2,10,0,4);
        dut.instr_mem_inst.mem[2] = dot(9,1,2);
        dut.instr_mem_inst.mem[3] = addi(10,10,8);
        dut.instr_mem_inst.mem[4] = ins(OP_LOAD,1,10,0,0);
        dut.instr_mem_inst.mem[5] = ins(OP_LOAD,2,10,0,4);
        dut.instr_mem_inst.mem[6] = dot(9,1,2);
        run_case("I-D-memory-mixed", 7);

        // I-D control: identical memory-fed shape without the independent
        // pointer ADDI, establishing the cycle cost attributable to that
        // scalar insertion rather than to LOAD/DOT dependencies.
        clear_program();
        dut.data_mem_inst.mem[0] = 32'h0102_0304;
        dut.data_mem_inst.mem[1] = 32'h0506_0708;
        dut.instr_mem_inst.mem[0] = ins(OP_LOAD,1,10,0,0);
        dut.instr_mem_inst.mem[1] = ins(OP_LOAD,2,10,0,4);
        dut.instr_mem_inst.mem[2] = dot(9,1,2);
        dut.instr_mem_inst.mem[3] = ins(OP_LOAD,1,10,0,0);
        dut.instr_mem_inst.mem[4] = ins(OP_LOAD,2,10,0,4);
        dut.instr_mem_inst.mem[5] = dot(9,1,2);
        run_case("I-D-memory-control", 6);

        // I-E: independent branch/control mix (negative control for redirect).
        clear_program();
        dut.instr_mem_inst.mem[0] = dot(9,1,2);
        dut.instr_mem_inst.mem[1] = addi(10,10,1);
        dut.instr_mem_inst.mem[2] = beq(0,0,2);
        dut.instr_mem_inst.mem[3] = addi(11,11,99);
        dut.instr_mem_inst.mem[4] = dot(9,1,2);
        run_case("I-E-branch-mix", 4);

        // I-F: independent store after scalar work.
        clear_program();
        dut.regs[10] = 8; dut.instr_mem_inst.mem[0] = dot(9,1,2);
        dut.instr_mem_inst.mem[1] = addi(11,11,1);
        dut.instr_mem_inst.mem[2] = store(11,10,0);
        run_case("I-F-independent-store", 3);
        $display("STAGE_I_MEASUREMENT_PASS");
        $finish;
    end
endmodule
