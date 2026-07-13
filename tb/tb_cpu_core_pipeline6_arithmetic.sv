import cpu_defs_pkg::*;

module tb_cpu_core_pipeline6_arithmetic;

    localparam int unsigned IMEM_DEPTH = 64;

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
    int mem_write_failures;
    int write_x0_failures;
    int pause_retire_failures;
    int retire_seen [0:IMEM_DEPTH-1];

    cpu_core_pipeline6 #(
        .IMEM_DEPTH(IMEM_DEPTH),
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

    task automatic clear_program();
        logic [31:0] nop_word;

        nop_word = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = nop_word;
            retire_seen[i] = 0;
        end

        mem_write_failures = 0;
        write_x0_failures = 0;
        pause_retire_failures = 0;
    endtask

    task automatic put_instr(input int word_index, input logic [31:0] instruction);
        dut.instr_mem_inst.mem[word_index] = instruction;
    endtask

    task automatic load_arithmetic_program();
        clear_program();
        put_instr(0,  instr(OP_ADDI, 5'd1,  5'd0,  5'd0, imm13_signed(5)));
        put_instr(1,  instr(OP_ADDI, 5'd2,  5'd0,  5'd0, imm13_signed(7)));
        put_instr(2,  instr(OP_ADD,  5'd3,  5'd1,  5'd2, 13'd0));
        put_instr(3,  instr(OP_SUB,  5'd4,  5'd3,  5'd1, 13'd0));
        put_instr(4,  instr(OP_AND,  5'd5,  5'd3,  5'd4, 13'd0));
        put_instr(5,  instr(OP_OR,   5'd6,  5'd1,  5'd2, 13'd0));
        put_instr(6,  instr(OP_XOR,  5'd7,  5'd6,  5'd1, 13'd0));
        put_instr(7,  instr(OP_ADDI, 5'd8,  5'd0,  5'd0, imm13_signed(-1)));
        put_instr(8,  instr(OP_ADDI, 5'd0,  5'd0,  5'd0, imm13_signed(123)));
        put_instr(9,  instr(OP_ADDI, 5'd10, 5'd0,  5'd0, imm13_signed(1)));
        put_instr(10, instr(OP_ADDI, 5'd11, 5'd10, 5'd0, imm13_signed(2)));
        put_instr(11, instr(OP_ADD,  5'd12, 5'd11, 5'd10, 13'd0));
        put_instr(12, instr(OP_SUB,  5'd13, 5'd12, 5'd10, 13'd0));
        put_instr(13, instr(OP_NOP,  5'd0,  5'd0,  5'd0, 13'd0));
        put_instr(14, instr(4'hf,    5'd9,  5'd0,  5'd0, 13'd0));
        put_instr(15, instr(OP_NOP,  5'd0,  5'd0,  5'd0, 13'd0));
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
        check_true("reset no retirement", debug_retire_valid === 1'b0);
        check_true("reset no writeback", debug_writeback_valid === 1'b0);
        check_equal32("reset x0", debug_x0, 32'd0);
        check_equal32("reset x1", debug_x1, 32'd0);
        check_equal32("reset x8", debug_x8, 32'd0);
        check_equal32("reset retired count", debug_retired_count, 32'd0);
    endtask

    task automatic check_pause_holds();
        logic [31:0] hold_fetch_pc;
        logic [31:0] hold_if_id_instr;
        logic [31:0] hold_id_op_instr;
        logic [31:0] hold_op_ex_instr;
        logic [31:0] hold_ex_mem_instr;
        logic [31:0] hold_x1;
        logic [31:0] hold_x2;
        logic [31:0] hold_retired_count;
        logic        hold_if_id_valid;
        logic        hold_id_op_valid;
        logic        hold_op_ex_valid;
        logic        hold_ex_mem_valid;

        hold_fetch_pc = debug_fetch_pc;
        hold_if_id_instr = debug_if_id_instr;
        hold_id_op_instr = debug_id_op_instr;
        hold_op_ex_instr = debug_op_ex_instr;
        hold_ex_mem_instr = debug_ex_mem_instr;
        hold_x1 = debug_x1;
        hold_x2 = debug_x2;
        hold_retired_count = debug_retired_count;
        hold_if_id_valid = debug_if_id_valid;
        hold_id_op_valid = debug_id_op_valid;
        hold_op_ex_valid = debug_op_ex_valid;
        hold_ex_mem_valid = debug_ex_mem_valid;

        enable = 1'b0;
        repeat (3) begin
            step_clock();
            check_equal32("pause fetch PC held", debug_fetch_pc, hold_fetch_pc);
            check_true("pause IF/ID valid held", debug_if_id_valid === hold_if_id_valid);
            check_true("pause ID/OP valid held", debug_id_op_valid === hold_id_op_valid);
            check_true("pause OP/EX valid held", debug_op_ex_valid === hold_op_ex_valid);
            check_true("pause EX/MEM valid held", debug_ex_mem_valid === hold_ex_mem_valid);
            check_equal32("pause IF/ID instruction held", debug_if_id_instr, hold_if_id_instr);
            check_equal32("pause ID/OP instruction held", debug_id_op_instr, hold_id_op_instr);
            check_equal32("pause OP/EX instruction held", debug_op_ex_instr, hold_op_ex_instr);
            check_equal32("pause EX/MEM instruction held", debug_ex_mem_instr, hold_ex_mem_instr);
            check_equal32("pause x1 held", debug_x1, hold_x1);
            check_equal32("pause x2 held", debug_x2, hold_x2);
            check_equal32("pause retired count held", debug_retired_count, hold_retired_count);
            check_true("pause no retirement pulse", debug_retire_valid === 1'b0);
            check_true("pause no writeback pulse", debug_writeback_valid === 1'b0);
            check_true("pause no memory write", debug_mem_write === 1'b0);
        end
        enable = 1'b1;
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

        if (debug_mem_write) begin
            mem_write_failures++;
        end

        if (debug_writeback_valid && (debug_writeback_rd == 5'd0)) begin
            write_x0_failures++;
        end

    end

    initial begin
        tests_run = 0;
        tests_failed = 0;
        rst = 1'b0;
        enable = 1'b0;

        load_arithmetic_program();
        reset_core();

        enable = 1'b1;
        repeat (6) begin
            step_clock();
        end
        check_pause_holds();

        repeat (60) begin
            step_clock();
            check_true("x0 remains zero during execution", debug_x0 === 32'h0000_0000);
            check_true("stall inactive for Phase 14C arithmetic", debug_stall_active === 1'b0);
            check_true("no memory write during Phase 14C arithmetic", debug_mem_write === 1'b0);
            if (debug_retire_valid) begin
                check_true("retire PC aligned", debug_retire_pc[1:0] == 2'b00);
                check_true("retired opcode valid", opcode_is_valid(debug_retire_opcode));
            end
        end

        check_equal32("ADDI x1 = 5", debug_x1, 32'd5);
        check_equal32("ADDI x2 = 7", debug_x2, 32'd7);
        check_equal32("ADD x3 = x1 + x2", debug_x3, 32'd12);
        check_equal32("SUB x4 = x3 - x1", debug_x4, 32'd7);
        check_equal32("AND x5 = x3 & x4", debug_x5, 32'd4);
        check_equal32("OR x6 = x1 | x2", debug_x6, 32'd7);
        check_equal32("XOR x7 = x6 ^ x1", debug_x7, 32'd2);
        check_equal32("ADDI x8 = -1 sign-extended", debug_x8, 32'hffff_ffff);
        check_equal32("x0 write ignored", debug_x0, 32'd0);
        check_equal32("dependency ADDI x10 = 1", debug_x10, 32'd1);
        check_equal32("dependency ADDI x11 = x10 + 2", debug_x11, 32'd3);
        check_equal32("dependency ADD x12 = x11 + x10", debug_x12, 32'd4);
        check_equal32("dependency SUB x13 = x12 - x10", debug_x13, 32'd3);
        check_equal32("invalid opcode target x9 unchanged", debug_x9, 32'd0);

        check_equal_int("PC0 retired once", retire_seen[0], 1);
        check_equal_int("PC8 ADD retired once", retire_seen[2], 1);
        check_equal_int("PC13 NOP retired once", retire_seen[13], 1);
        check_equal_int("PC14 invalid opcode did not retire", retire_seen[14], 0);
        check_equal_int("PC15 NOP after invalid retired once", retire_seen[15], 1);
        check_equal_int("no memory writes observed", mem_write_failures, 0);
        check_equal_int("no writeback to x0 observed", write_x0_failures, 0);
        check_equal_int("no retirement while paused", pause_retire_failures, 0);

        if (tests_failed == 0) begin
            $display("PHASE 14C PIPELINE6 ARITHMETIC TEST PASSED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
        end else begin
            $display("PHASE 14C PIPELINE6 ARITHMETIC TEST FAILED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
            $fatal(1);
        end

        $finish;
    end

endmodule
