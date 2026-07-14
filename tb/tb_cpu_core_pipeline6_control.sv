import cpu_defs_pkg::*;

module tb_cpu_core_pipeline6_control;

    localparam int unsigned IMEM_DEPTH = 96;
    localparam int unsigned DMEM_DEPTH = 64;

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
    int write_x0_failures;
    int pause_mem_write_failures;
    int branch_taken_count;
    int jump_taken_count;
    int redirect_count;
    int flush_count;
    int load_use_stall_count;
    int mem_write_count;
    int mem_write_seen [0:DMEM_DEPTH-1];
    int retire_seen [0:IMEM_DEPTH-1];

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
        .debug_ex_mem_instr(debug_ex_mem_instr),
        .debug_mem_wb_instr(debug_mem_wb_instr),
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

    task automatic clear_memories();
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

        write_x0_failures = 0;
        pause_mem_write_failures = 0;
        branch_taken_count = 0;
        jump_taken_count = 0;
        redirect_count = 0;
        flush_count = 0;
        load_use_stall_count = 0;
        mem_write_count = 0;
    endtask

    task automatic put_instr(input int word_index, input logic [31:0] instruction);
        dut.instr_mem_inst.mem[word_index] = instruction;
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
        check_true("reset no redirect", debug_redirect_valid === 1'b0);
        check_true("reset no memory write", debug_mem_write === 1'b0);
        check_equal32("reset x0", debug_x0, 32'd0);
    endtask

    task automatic run_enabled(input int cycles);
        repeat (cycles) begin
            step_clock();
            check_true("x0 remains zero", debug_x0 === 32'h0000_0000);
            if (debug_retire_valid) begin
                check_true("retire PC aligned", debug_retire_pc[1:0] == 2'b00);
                check_true("retired opcode valid", opcode_is_valid(debug_retire_opcode));
            end
            if (debug_mem_read || debug_mem_write) begin
                check_true("memory address aligned", debug_mem_addr[1:0] == 2'b00);
            end
        end
    endtask

    task automatic run_control_case(input string case_name, input int cycles);
        $display("---- %s ----", case_name);
        reset_core();
        enable = 1'b1;
        run_enabled(cycles);
        enable = 1'b0;
        repeat (2) begin
            step_clock();
        end
    endtask

    task automatic pause_when_control_in_ex(input string case_name);
        int wait_cycles;
        logic [31:0] hold_fetch_pc;
        logic [31:0] hold_if_id_instr;
        logic [31:0] hold_id_op_instr;
        logic [31:0] hold_op_ex_instr;
        logic [31:0] hold_ex_mem_instr;
        logic [31:0] hold_retired_count;

        wait_cycles = 0;
        while (!(debug_op_ex_valid && ((debug_op_ex_opcode == OP_BEQ) || (debug_op_ex_opcode == OP_JUMP))) &&
               (wait_cycles < 80)) begin
            step_clock();
            wait_cycles++;
        end
        check_true({case_name, " reached control instruction in EX"}, debug_op_ex_valid &&
                   ((debug_op_ex_opcode == OP_BEQ) || (debug_op_ex_opcode == OP_JUMP)));

        hold_fetch_pc = debug_fetch_pc;
        hold_if_id_instr = debug_if_id_instr;
        hold_id_op_instr = debug_id_op_instr;
        hold_op_ex_instr = debug_op_ex_instr;
        hold_ex_mem_instr = debug_ex_mem_instr;
        hold_retired_count = debug_retired_count;

        enable = 1'b0;
        repeat (3) begin
            step_clock();
            check_equal32({case_name, " pause fetch PC held"}, debug_fetch_pc, hold_fetch_pc);
            check_equal32({case_name, " pause IF/ID held"}, debug_if_id_instr, hold_if_id_instr);
            check_equal32({case_name, " pause ID/OP held"}, debug_id_op_instr, hold_id_op_instr);
            check_equal32({case_name, " pause OP/EX held"}, debug_op_ex_instr, hold_op_ex_instr);
            check_equal32({case_name, " pause EX/MEM held"}, debug_ex_mem_instr, hold_ex_mem_instr);
            check_equal32({case_name, " pause retired count held"}, debug_retired_count, hold_retired_count);
            check_true({case_name, " pause suppresses retire"}, debug_retire_valid === 1'b0);
            check_true({case_name, " pause suppresses reg write"}, debug_writeback_valid === 1'b0);
            check_true({case_name, " pause suppresses mem write"}, debug_mem_write === 1'b0);
        end
        enable = 1'b1;
    endtask

    task automatic case_beq_not_taken();
        clear_memories();
        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(6)));
        put_instr(2, instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instr(3, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(11)));
        put_instr(4, instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(22)));
        run_control_case("BEQ not taken", 70);
        check_equal32("BEQ not taken x3 fall-through", debug_x3, 32'd11);
        check_equal32("BEQ not taken x4 sequential", debug_x4, 32'd22);
        check_equal_int("BEQ not taken branch redirect count", branch_taken_count, 0);
        check_equal_int("BEQ not taken PC3 retired once", retire_seen[3], 1);
    endtask

    task automatic case_beq_taken();
        clear_memories();
        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(2, instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instr(3, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(4, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(42)));
        run_control_case("BEQ taken", 80);
        check_equal32("BEQ taken target x3", debug_x3, 32'd42);
        check_equal_int("BEQ taken wrong-path PC3 did not retire", retire_seen[3], 0);
        check_true("BEQ taken redirect observed", branch_taken_count >= 1);
        check_true("BEQ taken flush observed", flush_count >= 1);
    endtask

    task automatic case_beq_wrong_store();
        clear_memories();
        put_instr(0, instr(OP_ADDI,  5'd1, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(1, instr(OP_ADDI,  5'd2, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(2, instr(OP_ADDI,  5'd9, 5'd0, 5'd0, imm13_signed(123)));
        put_instr(3, instr(OP_BEQ,   5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instr(4, instr(OP_STORE, 5'd0, 5'd0, 5'd9, imm13_signed(0)));
        put_instr(5, instr(OP_ADDI,  5'd3, 5'd0, 5'd0, imm13_signed(77)));
        run_control_case("BEQ wrong-path STORE", 90);
        check_equal32("BEQ wrong-path STORE target x3", debug_x3, 32'd77);
        check_equal32("BEQ wrong-path STORE blocked word 0", dut.data_mem_inst.mem[0], 32'd0);
        check_equal_int("BEQ wrong-path STORE PC4 did not retire", retire_seen[4], 0);
        check_equal_int("BEQ wrong-path STORE no memory writes", mem_write_count, 0);
    endtask

    task automatic case_jump_forward();
        clear_memories();
        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(11)));
        put_instr(1, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(2)));
        put_instr(2, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(3, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(22)));
        run_control_case("JUMP forward", 70);
        check_equal32("JUMP forward x1", debug_x1, 32'd11);
        check_equal32("JUMP forward target x2", debug_x2, 32'd22);
        check_equal_int("JUMP forward wrong-path PC2 did not retire", retire_seen[2], 0);
        check_true("JUMP forward redirect observed", jump_taken_count >= 1);
    endtask

    task automatic case_jump_wrong_store();
        clear_memories();
        put_instr(0, instr(OP_ADDI,  5'd5, 5'd0, 5'd0, imm13_signed(55)));
        put_instr(1, instr(OP_JUMP,  5'd0, 5'd0, 5'd0, imm13_signed(2)));
        put_instr(2, instr(OP_STORE, 5'd0, 5'd0, 5'd5, imm13_signed(4)));
        put_instr(3, instr(OP_ADDI,  5'd6, 5'd0, 5'd0, imm13_signed(33)));
        run_control_case("JUMP wrong-path STORE", 80);
        check_equal32("JUMP wrong-path STORE target x6", debug_x6, 32'd33);
        check_equal32("JUMP wrong-path STORE blocked word 1", dut.data_mem_inst.mem[1], 32'd0);
        check_equal_int("JUMP wrong-path STORE PC2 did not retire", retire_seen[2], 0);
        check_equal_int("JUMP wrong-path STORE no memory writes", mem_write_count, 0);
    endtask

    task automatic case_beq_arithmetic_forward();
        clear_memories();
        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(4)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(4)));
        put_instr(2, instr(OP_ADD,  5'd3, 5'd1, 5'd2, imm13_signed(0)));
        put_instr(3, instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(8)));
        put_instr(4, instr(OP_BEQ,  5'd0, 5'd3, 5'd4, imm13_signed(2)));
        put_instr(5, instr(OP_ADDI, 5'd7, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(6, instr(OP_ADDI, 5'd7, 5'd0, 5'd0, imm13_signed(44)));
        run_control_case("BEQ arithmetic forwarding", 100);
        check_equal32("BEQ arithmetic forwarding x7", debug_x7, 32'd44);
        check_equal_int("BEQ arithmetic forwarding wrong-path PC5 did not retire", retire_seen[5], 0);
        check_true("BEQ arithmetic forwarding redirect observed", branch_taken_count >= 1);
    endtask

    task automatic case_beq_load_forward();
        clear_memories();
        dut.data_mem_inst.mem[0] = 32'd10;
        put_instr(0, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(10)));
        put_instr(1, instr(OP_LOAD, 5'd1, 5'd0, 5'd0, imm13_signed(0)));
        put_instr(2, instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instr(3, instr(OP_ADDI, 5'd8, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(4, instr(OP_ADDI, 5'd8, 5'd0, 5'd0, imm13_signed(66)));
        run_control_case("BEQ load forwarding", 110);
        check_equal32("BEQ load forwarding x1", debug_x1, 32'd10);
        check_equal32("BEQ load forwarding target x8", debug_x8, 32'd66);
        check_equal_int("BEQ load forwarding wrong-path PC3 did not retire", retire_seen[3], 0);
        check_true("BEQ load forwarding load-use stall observed", load_use_stall_count > 0);
        check_true("BEQ load forwarding redirect observed", branch_taken_count >= 1);
    endtask

    task automatic case_backward_loop();
        clear_memories();
        put_instr(0, instr(OP_ADDI,  5'd1, 5'd0, 5'd0, imm13_signed(0)));
        put_instr(1, instr(OP_ADDI,  5'd2, 5'd0, 5'd0, imm13_signed(3)));
        put_instr(2, instr(OP_ADDI,  5'd3, 5'd0, 5'd0, imm13_signed(1)));
        put_instr(3, instr(OP_ADD,   5'd1, 5'd1, 5'd3, imm13_signed(0)));
        put_instr(4, instr(OP_SUB,   5'd2, 5'd2, 5'd3, imm13_signed(0)));
        put_instr(5, instr(OP_BEQ,   5'd0, 5'd2, 5'd0, imm13_signed(2)));
        put_instr(6, instr(OP_JUMP,  5'd0, 5'd0, 5'd0, imm13_signed(-3)));
        put_instr(7, instr(OP_STORE, 5'd0, 5'd0, 5'd1, imm13_signed(0)));
        put_instr(8, instr(OP_NOP,   5'd0, 5'd0, 5'd0, imm13_signed(0)));
        run_control_case("backward loop", 180);
        check_equal32("backward loop accumulator x1", debug_x1, 32'd3);
        check_equal32("backward loop counter x2", debug_x2, 32'd0);
        check_equal32("backward loop data word 0", dut.data_mem_inst.mem[0], 32'd3);
        check_true("backward loop jump redirects observed", jump_taken_count >= 2);
        check_true("backward loop branch redirect observed", branch_taken_count >= 1);
        check_equal_int("backward loop store occurred once", mem_write_seen[0], 1);
    endtask

    task automatic case_invalid_and_nop_after_redirect();
        clear_memories();
        put_instr(0, instr(OP_JUMP, 5'd0,  5'd0, 5'd0, imm13_signed(2)));
        put_instr(1, instr(OP_ADDI, 5'd11, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(2, instr(4'hf,    5'd11, 5'd0, 5'd0, imm13_signed(0)));
        put_instr(3, instr(OP_NOP,  5'd0,  5'd0, 5'd0, imm13_signed(0)));
        put_instr(4, instr(OP_ADDI, 5'd11, 5'd0, 5'd0, imm13_signed(12)));
        run_control_case("invalid target and NOP", 90);
        check_equal32("invalid target final x11", debug_x11, 32'd12);
        check_equal_int("wrong-path PC1 did not retire", retire_seen[1], 0);
        check_equal_int("invalid target PC2 did not retire", retire_seen[2], 0);
        check_true("NOP after invalid target retired", retire_seen[3] >= 1);
        check_true("JUMP to invalid target observed", jump_taken_count >= 1);
    endtask

    task automatic case_pause_around_redirect();
        clear_memories();
        put_instr(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(1, instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(5)));
        put_instr(2, instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instr(3, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(99)));
        put_instr(4, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(33)));
        $display("---- pause around redirect ----");
        reset_core();
        enable = 1'b1;
        pause_when_control_in_ex("pause around redirect");
        run_enabled(80);
        enable = 1'b0;
        repeat (2) begin
            step_clock();
        end
        check_equal32("pause around redirect target x3", debug_x3, 32'd33);
        check_equal_int("pause around redirect wrong-path PC3 did not retire", retire_seen[3], 0);
        check_true("pause around redirect branch observed", branch_taken_count >= 1);
    endtask

    always @(posedge clk) begin
        #1;

        if (debug_retire_valid && (debug_retire_pc[1:0] == 2'b00)) begin
            int word_index;
            word_index = int'(debug_retire_pc >> 2);
            if ((word_index >= 0) && (word_index < IMEM_DEPTH)) begin
                retire_seen[word_index]++;
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
    end

    always @(negedge clk) begin
        if (debug_load_use_stall) begin
            load_use_stall_count++;
        end

        if (debug_mem_write) begin
            int word_index;
            word_index = int'(debug_mem_addr >> 2);
            mem_write_count++;
            if ((word_index >= 0) && (word_index < DMEM_DEPTH)) begin
                mem_write_seen[word_index]++;
            end
        end

        if (!enable && debug_mem_write) begin
            pause_mem_write_failures++;
        end
    end

    initial begin
        tests_run = 0;
        tests_failed = 0;
        rst = 1'b0;
        enable = 1'b0;

        case_beq_not_taken();
        case_beq_taken();
        case_beq_wrong_store();
        case_jump_forward();
        case_jump_wrong_store();
        case_beq_arithmetic_forward();
        case_beq_load_forward();
        case_backward_loop();
        case_invalid_and_nop_after_redirect();
        case_pause_around_redirect();

        check_equal_int("no writeback to x0 observed in final case", write_x0_failures, 0);
        check_equal_int("no memory write while paused in final case", pause_mem_write_failures, 0);

        if (tests_failed == 0) begin
            $display("PHASE 14E PIPELINE6 CONTROL TEST PASSED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
        end else begin
            $display("PHASE 14E PIPELINE6 CONTROL TEST FAILED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
            $fatal(1);
        end

        $finish;
    end

endmodule
