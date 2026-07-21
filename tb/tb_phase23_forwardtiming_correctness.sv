`timescale 1ns/1ps

import cpu_defs_pkg::*;

module tb_phase23_forwardtiming_correctness;
    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b0;

    logic [31:0] fetch_pc;
    logic [31:0] instruction_addr;
    logic [31:0] fetch_request_pc;
    logic        fetch_request_valid;
    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic [3:0]  decoded_opcode;
    logic        decoded_valid;
    logic        id_ex_valid;
    logic        ex_mem_valid;
    logic        mem_wb_valid;
    logic [31:0] alu_result;
    logic [31:0] data_addr;
    logic [31:0] memory_read_data;
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [3:0]  retire_opcode;
    logic [4:0]  retire_rd;
    logic        retire_reg_write;
    logic [31:0] retire_write_data;
    logic        retire_mem_write;
    logic [31:0] retire_mem_addr;
    logic [31:0] retire_mem_data;
    logic        reg_write;
    logic        mem_write;
    logic        pc_redirect;
    logic [31:0] total_cycles;
    logic [31:0] retired_instructions;
    logic [31:0] pipeline_fill_cycles;
    logic [31:0] data_hazard_stall_cycles;
    logic [31:0] load_use_stall_cycles;
    logic [31:0] control_hazard_flush_cycles;
    logic [31:0] instruction_fetch_wait_cycles;
    logic [31:0] memory_wait_cycles;
    logic [31:0] taken_branches;
    logic [31:0] not_taken_branches;
    logic [31:0] jumps;
    logic [31:0] wrong_path_instructions_flushed;

    int tests_run;
    int tests_failed;

    always #5 clk = ~clk;

    cpu_core_pipeline_forwardtiming_phase23 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .fetch_pc(fetch_pc),
        .instruction_addr(instruction_addr),
        .fetch_request_pc(fetch_request_pc),
        .fetch_request_valid(fetch_request_valid),
        .if_id_valid(if_id_valid),
        .if_id_pc(if_id_pc),
        .if_id_instruction(if_id_instruction),
        .decoded_opcode(decoded_opcode),
        .decoded_valid(decoded_valid),
        .id_ex_valid(id_ex_valid),
        .ex_mem_valid(ex_mem_valid),
        .mem_wb_valid(mem_wb_valid),
        .alu_result(alu_result),
        .data_addr(data_addr),
        .memory_read_data(memory_read_data),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_opcode(retire_opcode),
        .retire_rd(retire_rd),
        .retire_reg_write(retire_reg_write),
        .retire_write_data(retire_write_data),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_data(retire_mem_data),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .pc_redirect(pc_redirect),
        .total_cycles(total_cycles),
        .retired_instructions(retired_instructions),
        .pipeline_fill_cycles(pipeline_fill_cycles),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .taken_branches(taken_branches),
        .not_taken_branches(not_taken_branches),
        .jumps(jumps),
        .wrong_path_instructions_flushed(wrong_path_instructions_flushed)
    );

    function automatic logic [31:0] instr(
        input logic [3:0]  opcode,
        input logic [4:0]  rd,
        input logic [4:0]  rs1,
        input logic [4:0]  rs2,
        input logic [12:0] imm13
    );
        instr = {opcode, rd, rs1, rs2, imm13};
    endfunction

    function automatic logic [12:0] imm13_signed(input int value);
        imm13_signed = value[12:0];
    endfunction

    task automatic check_true(input string name, input bit condition);
        tests_run++;
        if (condition) begin
            $display("PASS: %s", name);
        end else begin
            tests_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic check_equal32(input string name, input logic [31:0] actual, input logic [31:0] expected);
        tests_run++;
        if (actual === expected) begin
            $display("PASS: %s | value=0x%08h", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s | actual=0x%08h expected=0x%08h", name, actual, expected);
        end
    endtask

    task automatic clear_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        end
        for (int i = 0; i < DMEM_DEPTH; i++) begin
            dut.data_mem_inst.mem[i] = 32'h0000_0000;
        end
    endtask

    task automatic put_instr(input int word_index, input logic [31:0] instruction);
        dut.instr_mem_inst.mem[word_index] = instruction;
    endtask

    task automatic step_clock();
        @(posedge clk);
        #1;
    endtask

    task automatic reset_core();
        enable = 1'b0;
        rst = 1'b1;
        repeat (5) step_clock();
        rst = 1'b0;
        repeat (2) step_clock();

        check_equal32("reset fetch PC", fetch_pc, 32'h0000_0000);
        check_true("reset IF/ID invalid", if_id_valid === 1'b0);
        check_true("reset retire invalid", retire_valid === 1'b0);
        check_equal32("reset cycle counter", total_cycles, 32'd0);
        check_equal32("reset x0", dut.regs[0], 32'd0);
    endtask

    task automatic run_cycles(input int unsigned cycles);
        for (int unsigned i = 0; i < cycles; i++) begin
            step_clock();
        end
    endtask

    initial begin
        tests_run = 0;
        tests_failed = 0;

        clear_memories();

        // Main program:
        // - arithmetic and memory loop using a backward BEQ as an unconditional
        //   loop branch, and a repeated JUMP pattern for the Phase 23
        //   frontend/JUMP target-cache path
        // - one backward BEQ mispredict-not-taken case
        // - forward BEQ and JUMP wrong-path side-effect protection
        put_instr(0,  instr(OP_ADDI,  5'd1,  5'd0, 5'd0, imm13_signed(64)));  // base
        put_instr(1,  instr(OP_ADDI,  5'd2,  5'd0, 5'd0, imm13_signed(1)));   // step
        put_instr(2,  instr(OP_ADDI,  5'd3,  5'd0, 5'd0, imm13_signed(3)));   // counter
        put_instr(3,  instr(OP_ADDI,  5'd4,  5'd0, 5'd0, imm13_signed(0)));   // accumulator
        put_instr(4,  instr(OP_ADD,   5'd4,  5'd4, 5'd2, 13'd0));
        put_instr(5,  instr(OP_STORE, 5'd0,  5'd1, 5'd4, imm13_signed(0)));
        put_instr(6,  instr(OP_LOAD,  5'd5,  5'd1, 5'd0, imm13_signed(0)));
        put_instr(7,  instr(OP_ADD,   5'd6,  5'd5, 5'd2, 13'd0));
        put_instr(8,  instr(OP_SUB,   5'd3,  5'd3, 5'd2, 13'd0));
        put_instr(9,  instr(OP_BEQ,   5'd0,  5'd3, 5'd0, imm13_signed(2)));
        put_instr(10, instr(OP_BEQ,   5'd0,  5'd0, 5'd0, imm13_signed(-6)));
        put_instr(11, instr(OP_ADDI,  5'd7,  5'd0, 5'd0, imm13_signed(77)));
        put_instr(12, instr(OP_BEQ,   5'd0,  5'd2, 5'd3, imm13_signed(-2)));
        put_instr(13, instr(OP_ADDI,  5'd8,  5'd0, 5'd0, imm13_signed(88)));
        put_instr(14, instr(OP_BEQ,   5'd0,  5'd8, 5'd8, imm13_signed(2)));
        put_instr(15, instr(OP_STORE, 5'd0,  5'd0, 5'd8, imm13_signed(0)));   // wrong path
        put_instr(16, instr(OP_ADDI,  5'd9,  5'd0, 5'd0, imm13_signed(99)));
        put_instr(17, instr(OP_JUMP,  5'd0,  5'd0, 5'd0, imm13_signed(2)));
        put_instr(18, instr(OP_ADDI,  5'd10, 5'd0, 5'd0, imm13_signed(123))); // wrong path
        put_instr(19, instr(OP_ADDI,  5'd11, 5'd0, 5'd0, imm13_signed(11)));
        put_instr(20, instr(OP_ADDI,  5'd0,  5'd0, 5'd0, imm13_signed(55)));
        put_instr(21, 32'hf000_0000);                                         // invalid bubble
        put_instr(22, instr(OP_NOP,   5'd0,  5'd0, 5'd0, 13'd0));
        put_instr(23, instr(OP_STORE, 5'd0,  5'd1, 5'd11, imm13_signed(4)));
        put_instr(24, instr(OP_ADDI,  5'd12, 5'd0, 5'd0, imm13_signed(0)));   // JUMP-loop accumulator
        put_instr(25, instr(OP_ADDI,  5'd13, 5'd0, 5'd0, imm13_signed(3)));   // JUMP-loop counter
        put_instr(26, instr(OP_ADDI,  5'd14, 5'd0, 5'd0, imm13_signed(1)));   // JUMP-loop step
        put_instr(27, instr(OP_ADD,   5'd12, 5'd12, 5'd14, 13'd0));
        put_instr(28, instr(OP_SUB,   5'd13, 5'd13, 5'd14, 13'd0));
        put_instr(29, instr(OP_BEQ,   5'd0,  5'd13, 5'd0, imm13_signed(2)));
        put_instr(30, instr(OP_JUMP,  5'd0,  5'd0,  5'd0, imm13_signed(-3)));  // repeated JUMP
        put_instr(31, instr(OP_ADDI,  5'd15, 5'd0, 5'd0, imm13_signed(15)));

        reset_core();
        enable = 1'b1;
        run_cycles(320);

        enable = 1'b0;
        step_clock();

        check_equal32("accumulator x4", dut.regs[4], 32'd3);
        check_equal32("load result x5", dut.regs[5], 32'd3);
        check_equal32("load-use add result x6", dut.regs[6], 32'd4);
        check_equal32("exit register x7", dut.regs[7], 32'd77);
        check_equal32("post-mispredict register x8", dut.regs[8], 32'd88);
        check_equal32("post-forward-branch register x9", dut.regs[9], 32'd99);
        check_equal32("wrong-path JUMP register x10 unchanged", dut.regs[10], 32'd0);
        check_equal32("final register x11", dut.regs[11], 32'd11);
        check_equal32("repeated JUMP loop accumulator x12", dut.regs[12], 32'd3);
        check_equal32("repeated JUMP loop counter x13", dut.regs[13], 32'd0);
        check_equal32("repeated JUMP loop exit x15", dut.regs[15], 32'd15);
        check_equal32("x0 remains zero", dut.regs[0], 32'd0);
        check_equal32("loop memory word 16", dut.data_mem_inst.mem[16], 32'd3);
        check_equal32("wrong-path store word 0 unchanged", dut.data_mem_inst.mem[0], 32'd0);
        check_equal32("final memory word 17", dut.data_mem_inst.mem[17], 32'd11);
        check_true("branches retired", (taken_branches + not_taken_branches) >= 32'd4);
        check_true("jump retired", jumps >= 32'd1);
        check_true("load-use stall observed", load_use_stall_cycles != 32'd0);
        check_true("control redirects observed", control_hazard_flush_cycles != 32'd0);
        check_true("wrong-path flushes observed", wrong_path_instructions_flushed != 32'd0);

        // Pause/resume should hold all architectural state and counters.
        begin
            logic [31:0] held_pc;
            logic [31:0] held_cycles;
            logic [31:0] held_retired;
            held_pc = fetch_pc;
            held_cycles = total_cycles;
            held_retired = retired_instructions;
            enable = 1'b0;
            run_cycles(8);
            check_equal32("pause holds fetch PC", fetch_pc, held_pc);
            check_equal32("pause holds cycle counter", total_cycles, held_cycles);
            check_equal32("pause holds retire counter", retired_instructions, held_retired);
            enable = 1'b1;
            run_cycles(8);
            check_true("resume advances cycle counter", total_cycles > held_cycles);
        end

        $display("PHASE 23 FORWARDTIMING CORRECTNESS SUMMARY: tests_run=%0d tests_failed=%0d",
                 tests_run, tests_failed);
        if (tests_failed != 0) begin
            $fatal(1, "PHASE 23 FORWARDTIMING CORRECTNESS TEST FAILED");
        end

        $display("PHASE 23 FORWARDTIMING CORRECTNESS TEST PASSED");
        $finish;
    end
endmodule
