import cpu_defs_pkg::*;

module tb_cpu_core_pipeline6_skeleton;

    localparam int unsigned IMEM_DEPTH = 32;

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

    int tests_run;
    int tests_failed;
    int side_effect_failures;
    int pause_retire_failures;
    int retire_seen [0:IMEM_DEPTH-1];

    logic [31:0] instr_nop0;
    logic [31:0] instr_addi1;
    logic [31:0] instr_add2;
    logic [31:0] instr_invalid3;
    logic [31:0] instr_nop4;
    logic [31:0] instr_nop5;

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
        .debug_mem_write(debug_mem_write)
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

    task automatic check_valid_controls(input string name);
        check_true(
            name,
            !$isunknown({
                debug_fetch_request_valid,
                debug_if_id_valid,
                debug_id_op_valid,
                debug_op_ex_valid,
                debug_ex_mem_valid,
                debug_mem_wb_valid,
                debug_retire_valid,
                debug_reg_write,
                debug_mem_write
            })
        );
    endtask

    task automatic check_aligned(input string name, input logic [31:0] value);
        check_true(name, value[1:0] == 2'b00);
    endtask

    task automatic clear_program();
        logic [31:0] nop_word;

        nop_word = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = nop_word;
            retire_seen[i] = 0;
        end

        side_effect_failures = 0;
        pause_retire_failures = 0;
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
        check_true("reset fetch request invalid", debug_fetch_request_valid === 1'b0);
        check_true("reset IF/ID invalid", debug_if_id_valid === 1'b0);
        check_true("reset ID/OP invalid", debug_id_op_valid === 1'b0);
        check_true("reset OP/EX invalid", debug_op_ex_valid === 1'b0);
        check_true("reset EX/MEM invalid", debug_ex_mem_valid === 1'b0);
        check_true("reset MEM/WB invalid", debug_mem_wb_valid === 1'b0);
        check_true("reset retire invalid", debug_retire_valid === 1'b0);
        check_equal32("reset retired count", debug_retired_count, 32'd0);
        check_true("reset no register write", debug_reg_write === 1'b0);
        check_true("reset no memory write", debug_mem_write === 1'b0);
        check_valid_controls("reset control signals known");
    endtask

    task automatic check_pause_holds();
        logic        hold_req_valid;
        logic [31:0] hold_req_pc;
        logic [31:0] hold_fetch_pc;
        logic        hold_if_id_valid;
        logic        hold_id_op_valid;
        logic        hold_op_ex_valid;
        logic        hold_ex_mem_valid;
        logic        hold_mem_wb_valid;
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

        hold_req_valid = debug_fetch_request_valid;
        hold_req_pc = debug_fetch_request_pc;
        hold_fetch_pc = debug_fetch_pc;
        hold_if_id_valid = debug_if_id_valid;
        hold_id_op_valid = debug_id_op_valid;
        hold_op_ex_valid = debug_op_ex_valid;
        hold_ex_mem_valid = debug_ex_mem_valid;
        hold_mem_wb_valid = debug_mem_wb_valid;
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
            check_true("pause fetch request valid held", debug_fetch_request_valid === hold_req_valid);
            check_equal32("pause fetch request PC held", debug_fetch_request_pc, hold_req_pc);
            check_equal32("pause fetch PC held", debug_fetch_pc, hold_fetch_pc);
            check_true("pause IF/ID valid held", debug_if_id_valid === hold_if_id_valid);
            check_true("pause ID/OP valid held", debug_id_op_valid === hold_id_op_valid);
            check_true("pause OP/EX valid held", debug_op_ex_valid === hold_op_ex_valid);
            check_true("pause EX/MEM valid held", debug_ex_mem_valid === hold_ex_mem_valid);
            check_true("pause MEM/WB valid held", debug_mem_wb_valid === hold_mem_wb_valid);
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
            check_true("pause no retirement pulse", debug_retire_valid === 1'b0);
            check_true("pause no register write", debug_reg_write === 1'b0);
            check_true("pause no memory write", debug_mem_write === 1'b0);
            check_valid_controls("pause control signals known");
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

        if (debug_reg_write || debug_mem_write) begin
            side_effect_failures++;
        end

        if (!enable && debug_retire_valid) begin
            pause_retire_failures++;
        end
    end

    initial begin
        tests_run = 0;
        tests_failed = 0;
        rst = 1'b0;
        enable = 1'b0;

        instr_nop0     = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        instr_addi1    = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd5);
        instr_add2     = instr(OP_ADD, 5'd2, 5'd1, 5'd1, 13'd0);
        instr_invalid3 = instr(4'hf, 5'd3, 5'd0, 5'd0, 13'd0);
        instr_nop4     = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        instr_nop5     = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);

        clear_program();
        put_instr(0, instr_nop0);
        put_instr(1, instr_addi1);
        put_instr(2, instr_add2);
        put_instr(3, instr_invalid3);
        put_instr(4, instr_nop4);
        put_instr(5, instr_nop5);

        reset_core();

        enable = 1'b1;
        step_clock();
        check_true("cycle 1 request valid", debug_fetch_request_valid === 1'b1);
        check_equal32("cycle 1 request PC 0", debug_fetch_request_pc, 32'h0000_0000);
        check_equal32("cycle 1 next fetch PC 4", debug_fetch_pc, 32'h0000_0004);
        check_true("cycle 1 no stale IF/ID instruction", debug_if_id_valid === 1'b0);

        step_clock();
        check_true("cycle 2 IF/ID valid NOP", debug_if_id_valid === 1'b1);
        check_equal32("cycle 2 IF/ID PC 0", debug_if_id_pc, 32'h0000_0000);
        check_equal32("cycle 2 IF/ID instruction NOP", debug_if_id_instr, instr_nop0);
        check_true("cycle 2 IF/ID opcode NOP", debug_if_id_opcode === OP_NOP);
        check_true("cycle 2 ID/OP still bubble", debug_id_op_valid === 1'b0);
        check_equal32("cycle 2 request PC 4", debug_fetch_request_pc, 32'h0000_0004);

        step_clock();
        check_true("cycle 3 ID/OP valid PC0", debug_id_op_valid === 1'b1);
        check_equal32("cycle 3 ID/OP PC0", debug_id_op_pc, 32'h0000_0000);
        check_equal32("cycle 3 IF/ID PC4", debug_if_id_pc, 32'h0000_0004);
        check_true("cycle 3 IF/ID ADDI valid", debug_if_id_valid === 1'b1);
        check_equal32("cycle 3 request PC 8", debug_fetch_request_pc, 32'h0000_0008);

        step_clock();
        check_true("cycle 4 OP/EX valid PC0", debug_op_ex_valid === 1'b1);
        check_equal32("cycle 4 OP/EX PC0", debug_op_ex_pc, 32'h0000_0000);
        check_equal32("cycle 4 ID/OP PC4", debug_id_op_pc, 32'h0000_0004);
        check_equal32("cycle 4 IF/ID PC8", debug_if_id_pc, 32'h0000_0008);
        check_equal32("cycle 4 request PC 12", debug_fetch_request_pc, 32'h0000_000c);

        check_pause_holds();

        step_clock();
        check_true("resume EX/MEM valid PC0", debug_ex_mem_valid === 1'b1);
        check_equal32("resume EX/MEM PC0", debug_ex_mem_pc, 32'h0000_0000);
        check_equal32("resume OP/EX PC4", debug_op_ex_pc, 32'h0000_0004);
        check_equal32("resume ID/OP PC8", debug_id_op_pc, 32'h0000_0008);
        check_true("invalid opcode converted to IF/ID bubble", debug_if_id_valid === 1'b0);
        check_equal32("resume request PC 16", debug_fetch_request_pc, 32'h0000_0010);

        repeat (12) begin
            step_clock();
            check_aligned("fetch PC word aligned", debug_fetch_pc);
            if (debug_if_id_valid) begin
                check_aligned("IF/ID PC word aligned", debug_if_id_pc);
            end
            if (debug_retire_valid) begin
                check_aligned("retire PC word aligned", debug_retire_pc);
                check_true("retired opcode valid", opcode_is_valid(debug_retire_opcode));
            end
            check_true("no register write side effect", debug_reg_write === 1'b0);
            check_true("no memory write side effect", debug_mem_write === 1'b0);
            check_valid_controls("runtime control signals known");
        end

        check_equal_int("PC0 NOP retired exactly once", retire_seen[0], 1);
        check_equal_int("PC4 ADDI placeholder retired exactly once", retire_seen[1], 1);
        check_equal_int("PC8 ADD placeholder retired exactly once", retire_seen[2], 1);
        check_equal_int("PC12 invalid opcode did not retire", retire_seen[3], 0);
        check_equal_int("PC16 following NOP retired exactly once", retire_seen[4], 1);
        check_equal_int("PC20 following NOP retired exactly once", retire_seen[5], 1);
        check_equal_int("no side-effect pulses observed", side_effect_failures, 0);
        check_equal_int("no retirement while paused", pause_retire_failures, 0);
        check_true("retired count advanced", debug_retired_count >= 32'd5);

        if (tests_failed == 0) begin
            $display("PHASE 14B PIPELINE6 SKELETON TEST PASSED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
        end else begin
            $display("PHASE 14B PIPELINE6 SKELETON TEST FAILED: tests_run=%0d tests_failed=%0d", tests_run, tests_failed);
            $fatal(1);
        end

        $finish;
    end

endmodule
