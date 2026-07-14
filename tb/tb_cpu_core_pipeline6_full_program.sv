import cpu_defs_pkg::*;

module tb_cpu_core_pipeline6_full_program;

    localparam int unsigned IMEM_DEPTH = 128;
    localparam int unsigned DMEM_DEPTH = 64;
    localparam int unsigned DONE_INDEX = 47;
    localparam int unsigned EXPECTED_RETIRED = 58;
    localparam int unsigned EXPECTED_MEM_WRITES = 11;

    logic        clk;
    logic        rst;
    logic        enable;

    logic [31:0] debug_fetch_pc;
    logic [31:0] debug_instruction_addr;
    logic        debug_fetch_request_valid;
    logic [31:0] debug_fetch_request_pc;
    logic        debug_if_id_valid;
    logic        debug_id_op_valid;
    logic        debug_op_ex_valid;
    logic        debug_ex_mem_valid;
    logic        debug_mem_wb_valid;
    logic [31:0] debug_if_id_pc;
    logic [31:0] debug_id_op_pc;
    logic [31:0] debug_op_ex_pc;
    logic [31:0] debug_ex_mem_pc;
    logic [31:0] debug_mem_wb_pc;
    logic [31:0] debug_if_id_instr;
    logic [31:0] debug_id_op_instr;
    logic [31:0] debug_op_ex_instr;
    logic [31:0] debug_ex_mem_instr;
    logic [31:0] debug_mem_wb_instr;
    logic [3:0]  debug_if_id_opcode;
    logic [3:0]  debug_id_op_opcode;
    logic [3:0]  debug_op_ex_opcode;
    logic [3:0]  debug_ex_mem_opcode;
    logic [3:0]  debug_mem_wb_opcode;
    logic        debug_if_id_decoded_valid;
    logic        debug_id_op_decoded_valid;
    logic        debug_op_ex_decoded_valid;
    logic        debug_ex_mem_decoded_valid;
    logic        debug_mem_wb_decoded_valid;
    logic [31:0] debug_retired_count;
    logic        debug_retire_valid;
    logic [31:0] debug_retire_pc;
    logic [3:0]  debug_retire_opcode;
    logic        debug_reg_write;
    logic        debug_mem_write;
    logic        debug_mem_read;
    logic [31:0] debug_mem_addr;
    logic [31:0] debug_mem_write_data;
    logic [31:0] debug_mem_read_data;
    logic        debug_load_use_stall;
    logic        debug_redirect_valid;
    logic [31:0] debug_redirect_pc;
    logic        debug_flush_valid;
    logic        debug_branch_taken;
    logic        debug_jump_taken;
    logic        debug_writeback_valid;
    logic [4:0]  debug_writeback_rd;
    logic [31:0] debug_writeback_data;
    logic        debug_stall_active;
    logic [31:0] debug_x0;
    logic [31:0] debug_x1;
    logic [31:0] debug_x2;
    logic [31:0] debug_x3;
    logic [31:0] debug_x4;
    logic [31:0] debug_x5;
    logic [31:0] debug_x6;
    logic [31:0] debug_x7;
    logic [31:0] debug_x8;
    logic [31:0] debug_x9;
    logic [31:0] debug_x10;
    logic [31:0] debug_x11;
    logic [31:0] debug_x12;
    logic [31:0] debug_x13;

    int tests_run;
    int tests_failed;
    int bench_cycle_count;
    int bench_retired_count;
    int bench_mem_write_count;
    int branch_taken_count;
    int jump_taken_count;
    int redirect_count;
    int flush_count;
    int load_use_stall_count;
    int write_x0_failures;
    int retire_alignment_failures;
    int memory_alignment_failures;
    int pause_side_effect_failures;
    int mem_write_seen [0:DMEM_DEPTH-1];
    int retire_seen [0:IMEM_DEPTH-1];
    bit measurement_active;
    bit done_seen;
    bit pause_done;

    cpu_core_pipeline6 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .debug_fetch_pc(debug_fetch_pc),
        .debug_instruction_addr(debug_instruction_addr),
        .debug_fetch_request_valid(debug_fetch_request_valid),
        .debug_fetch_request_pc(debug_fetch_request_pc),
        .debug_if_id_valid(debug_if_id_valid),
        .debug_id_op_valid(debug_id_op_valid),
        .debug_op_ex_valid(debug_op_ex_valid),
        .debug_ex_mem_valid(debug_ex_mem_valid),
        .debug_mem_wb_valid(debug_mem_wb_valid),
        .debug_if_id_pc(debug_if_id_pc),
        .debug_id_op_pc(debug_id_op_pc),
        .debug_op_ex_pc(debug_op_ex_pc),
        .debug_ex_mem_pc(debug_ex_mem_pc),
        .debug_mem_wb_pc(debug_mem_wb_pc),
        .debug_if_id_instr(debug_if_id_instr),
        .debug_id_op_instr(debug_id_op_instr),
        .debug_op_ex_instr(debug_op_ex_instr),
        .debug_mem_wb_instr(debug_mem_wb_instr),
        .debug_ex_mem_instr(debug_ex_mem_instr),
        .debug_if_id_opcode(debug_if_id_opcode),
        .debug_id_op_opcode(debug_id_op_opcode),
        .debug_op_ex_opcode(debug_op_ex_opcode),
        .debug_ex_mem_opcode(debug_ex_mem_opcode),
        .debug_mem_wb_opcode(debug_mem_wb_opcode),
        .debug_if_id_decoded_valid(debug_if_id_decoded_valid),
        .debug_id_op_decoded_valid(debug_id_op_decoded_valid),
        .debug_op_ex_decoded_valid(debug_op_ex_decoded_valid),
        .debug_ex_mem_decoded_valid(debug_ex_mem_decoded_valid),
        .debug_mem_wb_decoded_valid(debug_mem_wb_decoded_valid),
        .debug_retired_count(debug_retired_count),
        .debug_retire_valid(debug_retire_valid),
        .debug_retire_pc(debug_retire_pc),
        .debug_retire_opcode(debug_retire_opcode),
        .debug_reg_write(debug_reg_write),
        .debug_mem_write(debug_mem_write),
        .debug_mem_read(debug_mem_read),
        .debug_mem_addr(debug_mem_addr),
        .debug_mem_write_data(debug_mem_write_data),
        .debug_mem_read_data(debug_mem_read_data),
        .debug_load_use_stall(debug_load_use_stall),
        .debug_redirect_valid(debug_redirect_valid),
        .debug_redirect_pc(debug_redirect_pc),
        .debug_flush_valid(debug_flush_valid),
        .debug_branch_taken(debug_branch_taken),
        .debug_jump_taken(debug_jump_taken),
        .debug_writeback_valid(debug_writeback_valid),
        .debug_writeback_rd(debug_writeback_rd),
        .debug_writeback_data(debug_writeback_data),
        .debug_stall_active(debug_stall_active),
        .debug_x0(debug_x0),
        .debug_x1(debug_x1),
        .debug_x2(debug_x2),
        .debug_x3(debug_x3),
        .debug_x4(debug_x4),
        .debug_x5(debug_x5),
        .debug_x6(debug_x6),
        .debug_x7(debug_x7),
        .debug_x8(debug_x8),
        .debug_x9(debug_x9),
        .debug_x10(debug_x10),
        .debug_x11(debug_x11),
        .debug_x12(debug_x12),
        .debug_x13(debug_x13)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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

    task automatic step_clock();
        @(posedge clk);
        #1;
    endtask

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

    task automatic check_equal_int(input string name, input int actual, input int expected);
        tests_run++;
        if (actual == expected) begin
            $display("PASS: %s | value=%0d", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s | actual=%0d expected=%0d", name, actual, expected);
        end
    endtask

    task automatic check_greater_than_zero(input string name, input int actual);
        tests_run++;
        if (actual > 0) begin
            $display("PASS: %s | value=%0d", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s | actual=%0d expected > 0", name, actual);
        end
    endtask

    task automatic clear_state();
        logic [31:0] nop_word;

        nop_word = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = nop_word;
            retire_seen[i] = 0;
        end

        for (int i = 0; i < DMEM_DEPTH; i++) begin
            dut.data_mem_inst.mem[i] = 32'h0000_0000;
            mem_write_seen[i] = 0;
        end

        bench_cycle_count = 0;
        bench_retired_count = 0;
        bench_mem_write_count = 0;
        branch_taken_count = 0;
        jump_taken_count = 0;
        redirect_count = 0;
        flush_count = 0;
        load_use_stall_count = 0;
        write_x0_failures = 0;
        retire_alignment_failures = 0;
        memory_alignment_failures = 0;
        pause_side_effect_failures = 0;
        measurement_active = 1'b0;
        done_seen = 1'b0;
        pause_done = 1'b0;
    endtask

    task automatic put_instr(input int word_index, input logic [31:0] instruction);
        dut.instr_mem_inst.mem[word_index] = instruction;
    endtask

    task automatic load_full_program();
        clear_state();

        put_instr(0,  instr(OP_ADDI,  5'd1,  5'd0,  5'd0, imm13_signed(64)));
        put_instr(1,  instr(OP_ADDI,  5'd2,  5'd0,  5'd0, imm13_signed(0)));
        put_instr(2,  instr(OP_ADDI,  5'd3,  5'd0,  5'd0, imm13_signed(3)));
        put_instr(3,  instr(OP_ADDI,  5'd4,  5'd0,  5'd0, imm13_signed(1)));
        put_instr(4,  instr(OP_ADDI,  5'd12, 5'd0,  5'd0, imm13_signed(-1)));
        put_instr(5,  instr(OP_ADDI,  5'd0,  5'd0,  5'd0, imm13_signed(55)));
        put_instr(6,  instr(OP_ADD,   5'd5,  5'd3,  5'd4, imm13_signed(0)));
        put_instr(7,  instr(OP_SUB,   5'd6,  5'd5,  5'd4, imm13_signed(0)));
        put_instr(8,  instr(OP_AND,   5'd7,  5'd5,  5'd6, imm13_signed(0)));
        put_instr(9,  instr(OP_OR,    5'd8,  5'd5,  5'd6, imm13_signed(0)));
        put_instr(10, instr(OP_XOR,   5'd9,  5'd8,  5'd4, imm13_signed(0)));
        put_instr(11, instr(OP_STORE, 5'd0,  5'd1,  5'd9, imm13_signed(8)));
        put_instr(12, instr(OP_LOAD,  5'd10, 5'd1,  5'd0, imm13_signed(8)));
        put_instr(13, instr(OP_ADDI,  5'd11, 5'd10, 5'd0, imm13_signed(1)));
        put_instr(14, instr(OP_STORE, 5'd0,  5'd1,  5'd11, imm13_signed(12)));
        put_instr(15, instr(OP_ADDI,  5'd13, 5'd0,  5'd0, imm13_signed(76)));
        put_instr(16, instr(OP_LOAD,  5'd6,  5'd13, 5'd0, imm13_signed(-4)));
        put_instr(17, instr(OP_STORE, 5'd0,  5'd1,  5'd6, imm13_signed(20)));
        put_instr(18, instr(OP_ADDI,  5'd13, 5'd0,  5'd0, imm13_signed(123)));
        put_instr(19, instr(OP_ADDI,  5'd5,  5'd0,  5'd0, imm13_signed(5)));
        put_instr(20, instr(OP_ADDI,  5'd6,  5'd0,  5'd0, imm13_signed(5)));
        put_instr(21, instr(OP_BEQ,   5'd0,  5'd5,  5'd6, imm13_signed(2)));
        put_instr(22, instr(OP_STORE, 5'd0,  5'd1,  5'd13, imm13_signed(16)));
        put_instr(23, instr(OP_ADDI,  5'd7,  5'd0,  5'd0, imm13_signed(44)));
        put_instr(24, instr(OP_ADDI,  5'd5,  5'd0,  5'd0, imm13_signed(1)));
        put_instr(25, instr(OP_ADDI,  5'd6,  5'd0,  5'd0, imm13_signed(2)));
        put_instr(26, instr(OP_BEQ,   5'd0,  5'd5,  5'd6, imm13_signed(2)));
        put_instr(27, instr(OP_ADDI,  5'd8,  5'd0,  5'd0, imm13_signed(88)));
        put_instr(28, instr(OP_JUMP,  5'd0,  5'd0,  5'd0, imm13_signed(2)));
        put_instr(29, instr(OP_ADDI,  5'd8,  5'd0,  5'd0, imm13_signed(99)));
        put_instr(30, instr(OP_ADDI,  5'd9,  5'd0,  5'd0, imm13_signed(22)));
        put_instr(31, instr(OP_LOAD,  5'd0,  5'd1,  5'd0, imm13_signed(8)));
        put_instr(32, instr(4'hf,     5'd13, 5'd0,  5'd0, imm13_signed(0)));
        put_instr(33, instr(OP_NOP,   5'd0,  5'd0,  5'd0, imm13_signed(0)));
        put_instr(34, instr(OP_ADDI,  5'd2,  5'd0,  5'd0, imm13_signed(0)));
        put_instr(35, instr(OP_ADDI,  5'd3,  5'd0,  5'd0, imm13_signed(3)));
        put_instr(36, instr(OP_ADDI,  5'd4,  5'd0,  5'd0, imm13_signed(1)));
        put_instr(37, instr(OP_ADD,   5'd2,  5'd2,  5'd4, imm13_signed(0)));
        put_instr(38, instr(OP_SUB,   5'd3,  5'd3,  5'd4, imm13_signed(0)));
        put_instr(39, instr(OP_STORE, 5'd0,  5'd1,  5'd2, imm13_signed(0)));
        put_instr(40, instr(OP_LOAD,  5'd10, 5'd1,  5'd0, imm13_signed(0)));
        put_instr(41, instr(OP_STORE, 5'd0,  5'd1,  5'd10, imm13_signed(4)));
        put_instr(42, instr(OP_BEQ,   5'd0,  5'd3,  5'd0, imm13_signed(2)));
        put_instr(43, instr(OP_JUMP,  5'd0,  5'd0,  5'd0, imm13_signed(-6)));
        put_instr(44, instr(OP_STORE, 5'd0,  5'd1,  5'd2, imm13_signed(4)));
        put_instr(45, instr(OP_ADDI,  5'd6,  5'd10, 5'd0, imm13_signed(1)));
        put_instr(46, instr(OP_STORE, 5'd0,  5'd1,  5'd6, imm13_signed(8)));
        put_instr(47, instr(OP_NOP,   5'd0,  5'd0,  5'd0, imm13_signed(0)));
    endtask

    task automatic reset_core();
        enable = 1'b0;
        rst = 1'b1;
        repeat (4) begin
            step_clock();
        end
        rst = 1'b0;
        repeat (2) begin
            step_clock();
        end

        check_equal32("reset fetch PC", debug_fetch_pc, 32'h0000_0000);
        check_true("reset IF/ID invalid", debug_if_id_valid === 1'b0);
        check_true("reset ID/OP invalid", debug_id_op_valid === 1'b0);
        check_true("reset OP/EX invalid", debug_op_ex_valid === 1'b0);
        check_true("reset EX/MEM invalid", debug_ex_mem_valid === 1'b0);
        check_true("reset MEM/WB invalid", debug_mem_wb_valid === 1'b0);
        check_equal32("reset retired count", debug_retired_count, 32'd0);
        check_equal32("reset x0", debug_x0, 32'd0);
    endtask

    task automatic pause_pipeline_once();
        logic [31:0] hold_fetch_pc;
        logic [31:0] hold_if_id_pc;
        logic [31:0] hold_id_op_pc;
        logic [31:0] hold_op_ex_pc;
        logic [31:0] hold_ex_mem_pc;
        logic [31:0] hold_mem_wb_pc;
        logic [31:0] hold_if_id_instr;
        logic [31:0] hold_id_op_instr;
        logic [31:0] hold_op_ex_instr;
        logic [31:0] hold_ex_mem_instr;
        logic [31:0] hold_mem_wb_instr;
        logic [31:0] hold_retired_count;

        $display("---- Phase 14F pause/resume checkpoint ----");
        hold_fetch_pc = debug_fetch_pc;
        hold_if_id_pc = debug_if_id_pc;
        hold_id_op_pc = debug_id_op_pc;
        hold_op_ex_pc = debug_op_ex_pc;
        hold_ex_mem_pc = debug_ex_mem_pc;
        hold_mem_wb_pc = debug_mem_wb_pc;
        hold_if_id_instr = debug_if_id_instr;
        hold_id_op_instr = debug_id_op_instr;
        hold_op_ex_instr = debug_op_ex_instr;
        hold_ex_mem_instr = debug_ex_mem_instr;
        hold_mem_wb_instr = debug_mem_wb_instr;
        hold_retired_count = debug_retired_count;

        enable = 1'b0;
        repeat (3) begin
            step_clock();
            check_equal32("pause fetch PC held", debug_fetch_pc, hold_fetch_pc);
            check_equal32("pause IF/ID PC held", debug_if_id_pc, hold_if_id_pc);
            check_equal32("pause ID/OP PC held", debug_id_op_pc, hold_id_op_pc);
            check_equal32("pause OP/EX PC held", debug_op_ex_pc, hold_op_ex_pc);
            check_equal32("pause EX/MEM PC held", debug_ex_mem_pc, hold_ex_mem_pc);
            check_equal32("pause MEM/WB PC held", debug_mem_wb_pc, hold_mem_wb_pc);
            check_equal32("pause IF/ID instruction held", debug_if_id_instr, hold_if_id_instr);
            check_equal32("pause ID/OP instruction held", debug_id_op_instr, hold_id_op_instr);
            check_equal32("pause OP/EX instruction held", debug_op_ex_instr, hold_op_ex_instr);
            check_equal32("pause EX/MEM instruction held", debug_ex_mem_instr, hold_ex_mem_instr);
            check_equal32("pause MEM/WB instruction held", debug_mem_wb_instr, hold_mem_wb_instr);
            check_equal32("pause retired count held", debug_retired_count, hold_retired_count);
            check_true("pause suppresses retirement", debug_retire_valid === 1'b0);
            check_true("pause suppresses register write", debug_writeback_valid === 1'b0);
            check_true("pause suppresses memory write", debug_mem_write === 1'b0);
            if (debug_retire_valid || debug_writeback_valid || debug_mem_write) begin
                pause_side_effect_failures++;
            end
        end
        enable = 1'b1;
        pause_done = 1'b1;
    endtask

    task automatic sample_enabled_cycle();
        bench_cycle_count++;

        if (debug_retire_valid) begin
            int word_index;

            bench_retired_count++;
            if (debug_retire_pc[1:0] != 2'b00) begin
                retire_alignment_failures++;
            end

            word_index = int'(debug_retire_pc >> 2);
            if ((word_index >= 0) && (word_index < IMEM_DEPTH)) begin
                retire_seen[word_index]++;
                if (word_index == DONE_INDEX) begin
                    done_seen = 1'b1;
                end
            end
        end

        if (debug_writeback_valid && (debug_writeback_rd == 5'd0)) begin
            write_x0_failures++;
        end

        if (debug_redirect_valid) begin
            redirect_count++;
        end

        if (debug_flush_valid) begin
            flush_count++;
        end

        if (debug_branch_taken) begin
            branch_taken_count++;
        end

        if (debug_jump_taken) begin
            jump_taken_count++;
        end

        if (debug_load_use_stall) begin
            load_use_stall_count++;
        end

        if ((debug_mem_read || debug_mem_write) && (debug_mem_addr[1:0] != 2'b00)) begin
            memory_alignment_failures++;
        end
    endtask

    task automatic run_until_done(input int max_enabled_cycles);
        enable = 1'b1;
        measurement_active = 1'b1;

        while (!done_seen && (bench_cycle_count < max_enabled_cycles)) begin
            if (!pause_done && (bench_cycle_count >= 60)) begin
                pause_pipeline_once();
            end
            step_clock();
            sample_enabled_cycle();
        end

        enable = 1'b0;
        measurement_active = 1'b0;
        repeat (2) begin
            step_clock();
        end

        check_true("done NOP retired before timeout", done_seen);
        check_true("enabled-cycle timeout not reached", bench_cycle_count < max_enabled_cycles);
    endtask

    always @(negedge clk) begin
        if (measurement_active && debug_mem_write) begin
            int word_index;

            bench_mem_write_count++;
            word_index = int'(debug_mem_addr >> 2);
            if ((word_index >= 0) && (word_index < DMEM_DEPTH)) begin
                mem_write_seen[word_index]++;
            end
        end
    end

    initial begin
        real cpi;

        $dumpfile("tb_cpu_core_pipeline6_full_program.vcd");
        $dumpvars(0, tb_cpu_core_pipeline6_full_program);

        tests_run = 0;
        tests_failed = 0;
        rst = 1'b0;
        enable = 1'b0;

        load_full_program();
        reset_core();
        run_until_done(500);

        cpi = $itor(bench_cycle_count) / $itor(bench_retired_count);

        $display("");
        $display("PHASE 14F PIPELINE6 FULL PROGRAM PERFORMANCE");
        $display("  Enabled cycles       : %0d", bench_cycle_count);
        $display("  Retired instructions : %0d", bench_retired_count);
        $display("  CPI                  : %0.3f", cpi);
        $display("  Branch redirects     : %0d", branch_taken_count);
        $display("  Jump redirects       : %0d", jump_taken_count);
        $display("  Total redirects      : %0d", redirect_count);
        $display("  Flush pulses         : %0d", flush_count);
        $display("  Load-use stalls      : %0d", load_use_stall_count);
        $display("  Memory writes        : %0d", bench_mem_write_count);
        $display("");

        check_equal_int("retired instruction count", bench_retired_count, EXPECTED_RETIRED);
        check_equal_int("debug retired count matches measured", int'(debug_retired_count), EXPECTED_RETIRED);
        check_equal_int("memory write count", bench_mem_write_count, EXPECTED_MEM_WRITES);
        check_greater_than_zero("load-use stall observed", load_use_stall_count);
        check_equal_int("taken branch count", branch_taken_count, 2);
        check_equal_int("jump redirect count", jump_taken_count, 3);
        check_equal_int("wrong-path BEQ STORE PC22 did not retire", retire_seen[22], 0);
        check_equal_int("wrong-path JUMP ADDI PC29 did not retire", retire_seen[29], 0);
        check_equal_int("invalid opcode PC32 did not retire", retire_seen[32], 0);
        check_equal_int("done NOP retired once", retire_seen[DONE_INDEX], 1);
        check_equal_int("loop ADD retired three times", retire_seen[37], 3);
        check_equal_int("loop SUB retired three times", retire_seen[38], 3);
        check_equal_int("loop STORE retired three times", retire_seen[39], 3);
        check_equal_int("loop LOAD retired three times", retire_seen[40], 3);
        check_equal_int("loop load-use STORE retired three times", retire_seen[41], 3);
        check_equal_int("loop BEQ retired three times", retire_seen[42], 3);
        check_equal_int("loop JUMP retired twice", retire_seen[43], 2);

        check_equal32("x0 remains zero", debug_x0, 32'd0);
        check_equal32("x1 base register", debug_x1, 32'd64);
        check_equal32("x2 loop accumulator", debug_x2, 32'd3);
        check_equal32("x3 loop counter", debug_x3, 32'd0);
        check_equal32("x4 loop step", debug_x4, 32'd1);
        check_equal32("x5 BEQ not-taken operand", debug_x5, 32'd1);
        check_equal32("x6 final loaded-plus-one result", debug_x6, 32'd4);
        check_equal32("x7 BEQ taken target result", debug_x7, 32'd44);
        check_equal32("x8 JUMP wrong-path protection result", debug_x8, 32'd88);
        check_equal32("x9 JUMP target result", debug_x9, 32'd22);
        check_equal32("x10 final loaded accumulator", debug_x10, 32'd3);
        check_equal32("x11 load-use arithmetic result", debug_x11, 32'd7);
        check_equal32("x12 negative immediate sign extension", debug_x12, 32'hffff_ffff);
        check_equal32("x13 invalid opcode did not overwrite", debug_x13, 32'd123);

        check_equal32("data memory word 16 final accumulator", dut.data_mem_inst.mem[16], 32'd3);
        check_equal32("data memory word 17 final loop result", dut.data_mem_inst.mem[17], 32'd3);
        check_equal32("data memory word 18 final loaded-plus-one", dut.data_mem_inst.mem[18], 32'd4);
        check_equal32("data memory word 19 load-use arithmetic store", dut.data_mem_inst.mem[19], 32'd7);
        check_equal32("data memory word 20 wrong-path STORE blocked", dut.data_mem_inst.mem[20], 32'd0);
        check_equal32("data memory word 21 negative-offset LOAD result", dut.data_mem_inst.mem[21], 32'd6);
        check_equal_int("word 20 was never written", mem_write_seen[20], 0);

        check_equal_int("no x0 writeback pulses", write_x0_failures, 0);
        check_equal_int("no retire alignment failures", retire_alignment_failures, 0);
        check_equal_int("no memory alignment failures", memory_alignment_failures, 0);
        check_equal_int("no pause side-effect failures", pause_side_effect_failures, 0);

        if (cpi < 1.339) begin
            $display("INFO: Phase 14F measured CPI is below the Phase 13I CPI baseline of 1.339.");
        end else begin
            $display("INFO: Phase 14F measured CPI is not below the Phase 13I CPI baseline of 1.339.");
        end
        $display("INFO: No Phase 14 MIPS result is claimed without Phase 14G post-route timing.");

        if (tests_failed == 0) begin
            $display("PHASE 14F PIPELINE6 FULL PROGRAM TEST PASSED | checks=%0d failures=%0d", tests_run, tests_failed);
            $finish;
        end else begin
            $display("PHASE 14F PIPELINE6 FULL PROGRAM TEST FAILED | checks=%0d failures=%0d", tests_run, tests_failed);
            $fatal(1);
        end
    end

endmodule
