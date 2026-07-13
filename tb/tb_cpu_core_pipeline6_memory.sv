import cpu_defs_pkg::*;

module tb_cpu_core_pipeline6_memory;

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
    int pause_retire_failures;
    int pause_mem_write_failures;
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
        pause_retire_failures = 0;
        pause_mem_write_failures = 0;
        load_use_stall_count = 0;
        mem_write_count = 0;
    endtask

    task automatic put_instr(input int word_index, input logic [31:0] instruction);
        dut.instr_mem_inst.mem[word_index] = instruction;
    endtask

    task automatic load_memory_program();
        clear_memories();
        put_instr(0,  instr(OP_ADDI,  5'd1,  5'd0,  5'd0, imm13_signed(64)));
        put_instr(1,  instr(OP_ADDI,  5'd2,  5'd0,  5'd0, imm13_signed(123)));
        put_instr(2,  instr(OP_STORE, 5'd0,  5'd1,  5'd2, imm13_signed(0)));
        put_instr(3,  instr(OP_LOAD,  5'd3,  5'd1,  5'd0, imm13_signed(0)));
        put_instr(4,  instr(OP_STORE, 5'd0,  5'd1,  5'd3, imm13_signed(4)));
        put_instr(5,  instr(OP_LOAD,  5'd4,  5'd1,  5'd0, imm13_signed(4)));
        put_instr(6,  instr(OP_ADDI,  5'd5,  5'd0,  5'd0, imm13_signed(68)));
        put_instr(7,  instr(OP_LOAD,  5'd6,  5'd5,  5'd0, imm13_signed(-4)));
        put_instr(8,  instr(OP_ADDI,  5'd7,  5'd0,  5'd0, imm13_signed(77)));
        put_instr(9,  instr(OP_STORE, 5'd0,  5'd0,  5'd7, imm13_signed(8)));
        put_instr(10, instr(OP_LOAD,  5'd8,  5'd0,  5'd0, imm13_signed(8)));
        put_instr(11, instr(OP_ADDI,  5'd9,  5'd8,  5'd0, imm13_signed(1)));
        put_instr(12, instr(OP_LOAD,  5'd10, 5'd0,  5'd0, imm13_signed(8)));
        put_instr(13, instr(OP_STORE, 5'd0,  5'd0,  5'd10, imm13_signed(12)));
        put_instr(14, instr(OP_LOAD,  5'd0,  5'd0,  5'd0, imm13_signed(8)));
        put_instr(15, instr(OP_ADDI,  5'd0,  5'd0,  5'd0, imm13_signed(55)));
        put_instr(16, instr(4'hf,     5'd11, 5'd0,  5'd0, imm13_signed(0)));
        put_instr(17, instr(OP_NOP,   5'd0,  5'd0,  5'd0, imm13_signed(0)));
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
        check_true("reset no memory write", debug_mem_write === 1'b0);
        check_equal32("reset x0", debug_x0, 32'd0);
        check_equal32("reset x1", debug_x1, 32'd0);
        check_equal32("reset retired count", debug_retired_count, 32'd0);
    endtask

    task automatic pause_during_memory_activity();
        int wait_cycles;
        logic [31:0] hold_fetch_pc;
        logic [31:0] hold_if_id_instr;
        logic [31:0] hold_id_op_instr;
        logic [31:0] hold_op_ex_instr;
        logic [31:0] hold_ex_mem_instr;
        logic [31:0] hold_mem_wb_instr;
        logic [31:0] hold_retired_count;
        logic [31:0] hold_x1;
        logic [31:0] hold_x2;

        wait_cycles = 0;
        while (!(debug_mem_read || debug_mem_write) && (wait_cycles < 80)) begin
            step_clock();
            wait_cycles++;
        end
        check_true("pause reached data-memory activity", debug_mem_read || debug_mem_write);

        hold_fetch_pc = debug_fetch_pc;
        hold_if_id_instr = debug_if_id_instr;
        hold_id_op_instr = debug_id_op_instr;
        hold_op_ex_instr = debug_op_ex_instr;
        hold_ex_mem_instr = debug_ex_mem_instr;
        hold_mem_wb_instr = debug_mem_wb_instr;
        hold_retired_count = debug_retired_count;
        hold_x1 = debug_x1;
        hold_x2 = debug_x2;

        enable = 1'b0;
        repeat (3) begin
            step_clock();
            check_equal32("pause fetch PC held during memory", debug_fetch_pc, hold_fetch_pc);
            check_equal32("pause IF/ID instruction held during memory", debug_if_id_instr, hold_if_id_instr);
            check_equal32("pause ID/OP instruction held during memory", debug_id_op_instr, hold_id_op_instr);
            check_equal32("pause OP/EX instruction held during memory", debug_op_ex_instr, hold_op_ex_instr);
            check_equal32("pause EX/MEM instruction held during memory", debug_ex_mem_instr, hold_ex_mem_instr);
            check_equal32("pause MEM/WB instruction held during memory", debug_mem_wb_instr, hold_mem_wb_instr);
            check_equal32("pause retired count held during memory", debug_retired_count, hold_retired_count);
            check_equal32("pause x1 held during memory", debug_x1, hold_x1);
            check_equal32("pause x2 held during memory", debug_x2, hold_x2);
            check_true("pause no retirement during memory", debug_retire_valid === 1'b0);
            check_true("pause no writeback during memory", debug_writeback_valid === 1'b0);
            check_true("pause no memory write during memory", debug_mem_write === 1'b0);
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

        if (debug_writeback_valid && (debug_writeback_rd == 5'd0)) begin
            write_x0_failures++;
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

        load_memory_program();
        reset_core();

        enable = 1'b1;
        pause_during_memory_activity();

        repeat (140) begin
            step_clock();
            check_true("x0 remains zero during memory execution", debug_x0 === 32'h0000_0000);
            if (debug_retire_valid) begin
                check_true("retire PC aligned", debug_retire_pc[1:0] == 2'b00);
                check_true("retired opcode valid", opcode_is_valid(debug_retire_opcode));
            end
            if (debug_mem_read || debug_mem_write) begin
                check_true("memory address word aligned", debug_mem_addr[1:0] == 2'b00);
            end
        end

        check_equal32("ADDI x1 = 64 base address", debug_x1, 32'd64);
        check_equal32("ADDI x2 = 123 store data", debug_x2, 32'd123);
        check_equal32("LOAD x3 from [x1 + 0]", debug_x3, 32'd123);
        check_equal32("LOAD x4 from [x1 + 4]", debug_x4, 32'd123);
        check_equal32("ADDI x5 = 68", debug_x5, 32'd68);
        check_equal32("LOAD x6 from [x5 - 4]", debug_x6, 32'd123);
        check_equal32("ADDI x7 = 77", debug_x7, 32'd77);
        check_equal32("LOAD x8 from [x0 + 8]", debug_x8, 32'd77);
        check_equal32("LOAD-use ADDI x9 = x8 + 1", debug_x9, 32'd78);
        check_equal32("LOAD x10 from [x0 + 8]", debug_x10, 32'd77);
        check_equal32("x0 remains zero after LOAD/ADDI to x0", debug_x0, 32'd0);
        check_equal32("invalid opcode target x11 unchanged", debug_x11, 32'd0);

        check_equal32("STORE wrote data memory word 16", dut.data_mem_inst.mem[16], 32'd123);
        check_equal32("STORE wrote data memory word 17", dut.data_mem_inst.mem[17], 32'd123);
        check_equal32("STORE-data forwarding wrote word 2", dut.data_mem_inst.mem[2], 32'd77);
        check_equal32("LOAD-use STORE wrote word 3", dut.data_mem_inst.mem[3], 32'd77);

        check_equal_int("word 16 store occurred once", mem_write_seen[16], 1);
        check_equal_int("word 17 store occurred once", mem_write_seen[17], 1);
        check_equal_int("word 2 store occurred once", mem_write_seen[2], 1);
        check_equal_int("word 3 store occurred once", mem_write_seen[3], 1);
        check_equal_int("total STORE memory writes", mem_write_count, 4);
        check_true("load-use stalls observed", load_use_stall_count > 0);
        check_equal_int("no writeback to x0 observed", write_x0_failures, 0);
        check_equal_int("no retirement while paused", pause_retire_failures, 0);
        check_equal_int("no memory write while paused", pause_mem_write_failures, 0);

        check_equal_int("PC16 invalid opcode did not retire", retire_seen[16], 0);
        check_equal_int("PC17 NOP retired once", retire_seen[17], 1);

        if (tests_failed == 0) begin
            $display("PHASE 14D PIPELINE6 MEMORY TEST PASSED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
        end else begin
            $display("PHASE 14D PIPELINE6 MEMORY TEST FAILED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
            $fatal(1);
        end

        $finish;
    end

endmodule
