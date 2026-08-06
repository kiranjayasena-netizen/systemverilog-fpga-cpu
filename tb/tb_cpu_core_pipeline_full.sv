import cpu_defs_pkg::*;

`ifdef MAC8_TIMINGOPT_DUT
    `define PIPELINE_FULL_DUT cpu_core_pipeline_mac8_timingopt
`else
    `define PIPELINE_FULL_DUT cpu_core_pipeline_full
`endif

module tb_cpu_core_pipeline_full;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;

    logic        clk;
    logic        rst;
    logic        enable;
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
    int aggregate_cycles;
    int aggregate_retired;

    int current_retired;
    bit forbidden_word [0:IMEM_DEPTH-1];
    int retire_seen [0:IMEM_DEPTH-1];
    bit allow_repeated_retire;

    `PIPELINE_FULL_DUT #(
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

    task automatic check_nonzero(input string name, input logic [31:0] actual);
        tests_run++;
        if (actual != 32'd0) begin
            $display("PASS: %s | value=%0d", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s | expected nonzero", name);
        end
    endtask

    task automatic clear_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            forbidden_word[i] = 1'b0;
            retire_seen[i] = 0;
        end

        for (int i = 0; i < DMEM_DEPTH; i++) begin
            dut.data_mem_inst.mem[i] = 32'h0000_0000;
        end
    endtask

    task automatic put_instr(input int word_index, input logic [31:0] instruction);
        dut.instr_mem_inst.mem[word_index] = instruction;
    endtask

    task automatic forbid_retire(input int word_index);
        forbidden_word[word_index] = 1'b1;
    endtask

    task automatic reset_core();
        enable = 1'b0;
        rst = 1'b1;
        allow_repeated_retire = 1'b0;
        repeat (4) begin
            step_clock();
        end
        rst = 1'b0;
        repeat (2) begin
            step_clock();
        end

        check_equal32("reset fetch PC", fetch_pc, 32'h0000_0000);
        check_true("reset IF/ID invalid", if_id_valid === 1'b0);
        check_true("reset retire invalid", retire_valid === 1'b0);
        check_equal32("reset cycle counter", total_cycles, 32'd0);
        check_equal32("reset retired counter", retired_instructions, 32'd0);
    endtask

    task automatic start_program();
        current_retired = 0;
        enable = 1'b1;
    endtask

    task automatic observe_retire(input string program_name);
        int word_index;

        if (retire_valid) begin
            current_retired++;
            check_true($sformatf("%s retire PC aligned", program_name), retire_pc[1:0] == 2'b00);
            check_true($sformatf("%s invalid opcode never retires", program_name), opcode_is_valid(retire_opcode));
            word_index = int'(retire_pc >> 2);

            if ((word_index >= 0) && (word_index < IMEM_DEPTH)) begin
                retire_seen[word_index]++;
                check_true(
                    $sformatf("%s forbidden PC %0d did not retire", program_name, word_index),
                    !forbidden_word[word_index]
                );
                if (!allow_repeated_retire) begin
                    check_true(
                        $sformatf("%s PC %0d retires once", program_name, word_index),
                        retire_seen[word_index] == 1
                    );
                end
            end else begin
                check_true($sformatf("%s retire PC in range", program_name), 1'b0);
            end

            if (retire_reg_write) begin
                check_true($sformatf("%s retire writeback never targets x0", program_name), retire_rd != 5'd0);
            end
        end

        check_equal32($sformatf("%s x0 remains zero", program_name), dut.regs[0], 32'h0000_0000);
        check_true($sformatf("%s register write not unknown", program_name), !$isunknown(reg_write));
        check_true($sformatf("%s memory write not unknown", program_name), !$isunknown(mem_write));
    endtask

    task automatic run_until_retired(input string program_name, input int expected_retired, input int max_cycles);
        int cycles;

        start_program();
        cycles = 0;
        while ((current_retired < expected_retired) && (cycles < max_cycles)) begin
            step_clock();
            observe_retire(program_name);
            cycles++;
        end
        enable = 1'b0;
        step_clock();

        check_equal32($sformatf("%s retired instruction count", program_name), current_retired, expected_retired);
        check_true($sformatf("%s completed before timeout", program_name), cycles < max_cycles);

        aggregate_cycles += total_cycles;
        aggregate_retired += retired_instructions;

        if (retired_instructions != 0) begin
            real cpi;
            real mips_100;
            cpi = real'(total_cycles) / real'(retired_instructions);
            mips_100 = 100.0 / cpi;
            $display("");
            $display("BENCHMARK RESULT: %s", program_name);
            $display("  Cycles:                 %0d", total_cycles);
            $display("  Retired instructions:   %0d", retired_instructions);
            $display("  CPI:                    %0.3f", cpi);
            $display("  Estimated MIPS @100MHz: %0.3f", mips_100);
            $display("  Load-use stalls:        %0d", load_use_stall_cycles);
            $display("  Control flushes:        %0d", control_hazard_flush_cycles);
            $display("  Taken branches:         %0d", taken_branches);
            $display("  Not-taken branches:     %0d", not_taken_branches);
            $display("  Jumps:                  %0d", jumps);
            $display("  Wrong-path flushed:     %0d", wrong_path_instructions_flushed);
        end
    endtask

    task automatic prepare_program();
        clear_memories();
        reset_core();
    endtask

    task automatic run_independent_arithmetic();
        $display("");
        $display("---- Pipeline independent arithmetic benchmark ----");
        prepare_program();

        for (int i = 0; i < 80; i++) begin
            put_instr(i, instr(OP_ADDI, 5'((i % 31) + 1), 5'd0, 5'd0, imm13_signed(i + 1)));
        end
        put_instr(80, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));

        run_until_retired("independent arithmetic", 81, 220);
        check_equal32("independent arithmetic x1 final", dut.regs[1], 32'd63);
        check_equal32("independent arithmetic x18 final", dut.regs[18], 32'd80);
    endtask

    task automatic run_dependency_arithmetic();
        $display("");
        $display("---- Pipeline dependency-heavy arithmetic benchmark ----");
        prepare_program();

        put_instr(0,  instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(1)));
        put_instr(1,  instr(OP_ADD,  5'd2, 5'd1, 5'd1, 13'd0));
        put_instr(2,  instr(OP_ADD,  5'd3, 5'd2, 5'd1, 13'd0));
        put_instr(3,  instr(OP_SUB,  5'd4, 5'd3, 5'd1, 13'd0));
        put_instr(4,  instr(OP_OR,   5'd5, 5'd4, 5'd2, 13'd0));
        put_instr(5,  instr(OP_XOR,  5'd6, 5'd5, 5'd3, 13'd0));
        put_instr(6,  instr(OP_AND,  5'd7, 5'd6, 5'd5, 13'd0));
        put_instr(7,  instr(OP_ADDI, 5'd8, 5'd7, 5'd0, imm13_signed(-1)));
        put_instr(8,  instr(OP_ADD,  5'd9, 5'd8, 5'd1, 13'd0));
        put_instr(9,  instr(OP_ADDI, 5'd0, 5'd0, 5'd0, imm13_signed(123)));
        put_instr(10, instr(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0));

        run_until_retired("dependency arithmetic", 11, 80);
        check_equal32("dependency arithmetic x1", dut.regs[1], 32'd1);
        check_equal32("dependency arithmetic x2", dut.regs[2], 32'd2);
        check_equal32("dependency arithmetic x3", dut.regs[3], 32'd3);
        check_equal32("dependency arithmetic x4", dut.regs[4], 32'd2);
        check_equal32("dependency arithmetic x8", dut.regs[8], 32'hffff_ffff);
        check_equal32("dependency arithmetic x9", dut.regs[9], 32'd0);
        check_equal32("dependency arithmetic x0", dut.regs[0], 32'd0);
    endtask

    task automatic run_memory_offset();
        $display("");
        $display("---- Pipeline memory offset benchmark ----");
        prepare_program();

        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(64)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(123)));
        put_instr(2, instr(OP_STORE, 5'd0, 5'd1, 5'd2, imm13_signed(0)));
        put_instr(3, instr(OP_LOAD,  5'd3, 5'd1, 5'd0, imm13_signed(0)));
        put_instr(4, instr(OP_STORE, 5'd0, 5'd1, 5'd3, imm13_signed(4)));
        put_instr(5, instr(OP_LOAD,  5'd4, 5'd1, 5'd0, imm13_signed(4)));
        put_instr(6, instr(OP_ADDI,  5'd5, 5'd0, 5'd0, imm13_signed(68)));
        put_instr(7, instr(OP_LOAD,  5'd6, 5'd5, 5'd0, imm13_signed(-4)));
        put_instr(8, instr(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0));

        run_until_retired("memory offset", 9, 120);
        check_equal32("memory offset x1", dut.regs[1], 32'd64);
        check_equal32("memory offset x2", dut.regs[2], 32'd123);
        check_equal32("memory offset x3", dut.regs[3], 32'd123);
        check_equal32("memory offset x4", dut.regs[4], 32'd123);
        check_equal32("memory offset x5", dut.regs[5], 32'd68);
        check_equal32("memory offset x6", dut.regs[6], 32'd123);
        check_equal32("memory offset data word 16", dut.data_mem_inst.mem[16], 32'd123);
        check_equal32("memory offset data word 17", dut.data_mem_inst.mem[17], 32'd123);
        check_nonzero("memory offset load-use stall observed", load_use_stall_cycles);
    endtask

    task automatic run_load_use_dependency();
        $display("");
        $display("---- Pipeline load-use dependency benchmark ----");
        prepare_program();

        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(64)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(21)));
        put_instr(2, instr(OP_STORE, 5'd0, 5'd1, 5'd2, imm13_signed(0)));
        put_instr(3, instr(OP_LOAD,  5'd3, 5'd1, 5'd0, imm13_signed(0)));
        put_instr(4, instr(OP_ADD,   5'd4, 5'd3, 5'd3, 13'd0));
        put_instr(5, instr(OP_ADD,   5'd5, 5'd4, 5'd3, 13'd0));
        put_instr(6, instr(OP_STORE, 5'd0, 5'd1, 5'd5, imm13_signed(4)));
        put_instr(7, instr(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0));

        run_until_retired("load-use dependency", 8, 120);
        check_equal32("load-use x3", dut.regs[3], 32'd21);
        check_equal32("load-use x4", dut.regs[4], 32'd42);
        check_equal32("load-use x5", dut.regs[5], 32'd63);
        check_equal32("load-use data word 17", dut.data_mem_inst.mem[17], 32'd63);
        check_nonzero("load-use stall counter", load_use_stall_cycles);
    endtask

    task automatic run_branch_control();
        $display("");
        $display("---- Pipeline branch taken/not-taken benchmark ----");
        prepare_program();

        put_instr(0,  instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(1,  instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(2,  instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instr(3,  instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(4,  instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(42)));
        put_instr(5,  instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(1)));
        put_instr(6,  instr(OP_ADDI, 5'd5, 5'd0, 5'd0, imm13_signed(2)));
        put_instr(7,  instr(OP_BEQ,  5'd0, 5'd4, 5'd5, imm13_signed(2)));
        put_instr(8,  instr(OP_ADDI, 5'd6, 5'd0, 5'd0, imm13_signed(77)));
        put_instr(9,  instr(OP_ADDI, 5'd7, 5'd0, 5'd0, imm13_signed(88)));
        put_instr(10, instr(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0));
        forbid_retire(3);

        run_until_retired("branch control", 10, 140);
        check_equal32("branch x1", dut.regs[1], 32'd5);
        check_equal32("branch x2", dut.regs[2], 32'd5);
        check_equal32("branch x3", dut.regs[3], 32'd42);
        check_equal32("branch x6", dut.regs[6], 32'd77);
        check_equal32("branch x7", dut.regs[7], 32'd88);
        check_equal32("branch taken count", taken_branches, 32'd1);
        check_equal32("branch not-taken count", not_taken_branches, 32'd1);
    endtask

    task automatic run_jump_control();
        $display("");
        $display("---- Pipeline jump benchmark ----");
        prepare_program();

        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(11)));
        put_instr(1, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(2)));
        put_instr(2, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(3, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(22)));
        put_instr(4, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(33)));
        put_instr(5, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(2)));
        put_instr(6, instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(7, instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(44)));
        put_instr(8, instr(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0));
        forbid_retire(2);
        forbid_retire(6);

        run_until_retired("jump control", 7, 120);
        check_equal32("jump x1", dut.regs[1], 32'd11);
        check_equal32("jump x2", dut.regs[2], 32'd22);
        check_equal32("jump x3", dut.regs[3], 32'd33);
        check_equal32("jump x4", dut.regs[4], 32'd44);
        check_equal32("jump count", jumps, 32'd2);
    endtask

    task automatic run_simple_loop();
        $display("");
        $display("---- Pipeline backward loop benchmark ----");
        prepare_program();
        allow_repeated_retire = 1'b1;

        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(0)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(10)));
        put_instr(2, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(1)));
        put_instr(3, instr(OP_ADD,  5'd1, 5'd1, 5'd3, 13'd0));
        put_instr(4, instr(OP_SUB,  5'd2, 5'd2, 5'd3, 13'd0));
        put_instr(5, instr(OP_BEQ,  5'd0, 5'd2, 5'd0, imm13_signed(2)));
        put_instr(6, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(-3)));
        put_instr(7, instr(OP_STORE,5'd0, 5'd0, 5'd1, imm13_signed(0)));
        put_instr(8, instr(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0));

        run_until_retired("simple loop", 44, 320);
        check_equal32("loop x1", dut.regs[1], 32'd10);
        check_equal32("loop x2", dut.regs[2], 32'd0);
        check_equal32("loop x3", dut.regs[3], 32'd1);
        check_equal32("loop data word 0", dut.data_mem_inst.mem[0], 32'd10);
        check_equal32("loop taken branch count", taken_branches, 32'd1);
        check_equal32("loop not-taken branch count", not_taken_branches, 32'd9);
        check_equal32("loop jump count", jumps, 32'd9);
    endtask

    task automatic run_invalid_opcode();
        $display("");
        $display("---- Pipeline invalid opcode safety benchmark ----");
        prepare_program();

        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(10)));
        put_instr(1, instr(4'hc,   5'd3, 5'd1, 5'd1, 13'h123));
        put_instr(2, instr(OP_ADDI,5'd2, 5'd0, 5'd0, imm13_signed(20)));
        put_instr(3, instr(4'hf,   5'd4, 5'd2, 5'd2, 13'h456));
        put_instr(4, instr(OP_STORE,5'd0,5'd0, 5'd2, imm13_signed(0)));
        put_instr(5, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));
        forbid_retire(1);
        forbid_retire(3);

        run_until_retired("invalid opcode", 4, 100);
        check_equal32("invalid x1", dut.regs[1], 32'd10);
        check_equal32("invalid x2", dut.regs[2], 32'd20);
        check_equal32("invalid x3 unchanged", dut.regs[3], 32'd0);
        check_equal32("invalid x4 unchanged", dut.regs[4], 32'd0);
        check_equal32("invalid data word 0", dut.data_mem_inst.mem[0], 32'd20);
    endtask

    task automatic run_mixed_benchmark();
        $display("");
        $display("---- Pipeline complete mixed benchmark ----");
        prepare_program();
        allow_repeated_retire = 1'b1;

        put_instr(0,  instr(OP_ADDI, 5'd1,  5'd0,  5'd0, imm13_signed(0)));
        put_instr(1,  instr(OP_ADDI, 5'd2,  5'd0,  5'd0, imm13_signed(20)));
        put_instr(2,  instr(OP_ADDI, 5'd3,  5'd0,  5'd0, imm13_signed(1)));
        put_instr(3,  instr(OP_ADDI, 5'd10, 5'd0,  5'd0, imm13_signed(64)));
        put_instr(4,  instr(OP_ADD,  5'd1,  5'd1,  5'd3, 13'd0));
        put_instr(5,  instr(OP_STORE,5'd0,  5'd10, 5'd1, imm13_signed(0)));
        put_instr(6,  instr(OP_LOAD, 5'd4,  5'd10, 5'd0, imm13_signed(0)));
        put_instr(7,  instr(OP_ADD,  5'd5,  5'd4,  5'd1, 13'd0));
        put_instr(8,  instr(OP_SUB,  5'd2,  5'd2,  5'd3, 13'd0));
        put_instr(9,  instr(OP_BEQ,  5'd0,  5'd2,  5'd0, imm13_signed(2)));
        put_instr(10, instr(OP_JUMP, 5'd0,  5'd0,  5'd0, imm13_signed(-6)));
        put_instr(11, instr(OP_STORE,5'd0,  5'd0,  5'd5, imm13_signed(0)));
        put_instr(12, instr(OP_NOP,  5'd0,  5'd0,  5'd0, 13'd0));

        run_until_retired("mixed custom ISA", 145, 900);
        check_equal32("mixed x1", dut.regs[1], 32'd20);
        check_equal32("mixed x2", dut.regs[2], 32'd0);
        check_equal32("mixed x5", dut.regs[5], 32'd40);
        check_equal32("mixed memory word 16", dut.data_mem_inst.mem[16], 32'd20);
        check_equal32("mixed memory word 0", dut.data_mem_inst.mem[0], 32'd40);
    endtask

    initial begin
        $dumpfile("tb_cpu_core_pipeline_full.vcd");
        $dumpvars(0, tb_cpu_core_pipeline_full);

        rst = 1'b1;
        enable = 1'b0;
        tests_run = 0;
        tests_failed = 0;
        aggregate_cycles = 0;
        aggregate_retired = 0;

        run_independent_arithmetic();
        run_dependency_arithmetic();
        run_memory_offset();
        run_load_use_dependency();
        run_branch_control();
        run_jump_control();
        run_simple_loop();
        run_invalid_opcode();
        run_mixed_benchmark();

        $display("");
        $display("AGGREGATE PIPELINE PERFORMANCE");
        $display("  Aggregate cycles:       %0d", aggregate_cycles);
        $display("  Aggregate retired:      %0d", aggregate_retired);
        if (aggregate_retired != 0) begin
            real aggregate_cpi;
            real aggregate_mips_100;
            aggregate_cpi = real'(aggregate_cycles) / real'(aggregate_retired);
            aggregate_mips_100 = 100.0 / aggregate_cpi;
            $display("  Aggregate CPI:          %0.3f", aggregate_cpi);
            $display("  Aggregate MIPS @100MHz: %0.3f", aggregate_mips_100);
        end

        $display("");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed == 0) begin
            $display("PIPELINE FULL CUSTOM ISA TEST PASSED");
        end else begin
            $display("PIPELINE FULL CUSTOM ISA TEST FAILED");
            $fatal(1, "Pipeline full custom ISA test failed");
        end

        $finish;
    end

endmodule

`undef PIPELINE_FULL_DUT
