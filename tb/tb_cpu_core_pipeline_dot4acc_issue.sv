import cpu_defs_pkg::*;
import dot4acc_reference_pkg::*;

module tb_cpu_core_pipeline_dot4acc_issue;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;
    localparam int unsigned QUEUE_DEPTH = 4096;

    logic clk;
    logic rst;
    logic enable;

    logic        retire_valid;
    logic [3:0]  retire_opcode;
    logic        retire_reg_write;
    logic        retire_mem_write;
    logic        reg_write;
    logic        mem_write;
    logic        pc_redirect;
    logic [31:0] retired_instructions;
    logic [31:0] load_use_stall_cycles;

    logic        dot_issue_valid;
    logic        dot_issue_accept;
    logic [4:0]  dot_issue_rd;
    logic [31:0] dot_issue_packed_a;
    logic [31:0] dot_issue_packed_b;
    logic [31:0] dot_issue_accumulator;
    logic        dot_issue_chain;
    logic [3:0]  dot_inflight_valid;
    logic [19:0] dot_inflight_rd;
    logic        dot_complete_valid;
    logic        dot_complete_eligible;
    logic [4:0]  dot_complete_rd;
    logic [31:0] dot_complete_result;
    logic        dot_active;
    logic        dot_frontend_hold;
    logic        dot_dependency_stall;
    logic        dot_source_dependency_stall;
    logic        dot_accumulator_dependency_stall;
    logic        dot_cancel_event;

    int tests_run;
    int tests_failed;
    int advance_count;
    int accepted_total;
    int completed_total;
    int flushed_total;
    int cancel_total;
    int dependency_stall_total;
    int frontend_hold_total;
    int redirect_total;

    logic [31:0] expected_result_q [0:QUEUE_DEPTH-1];
    logic [4:0]  expected_rd_q [0:QUEUE_DEPTH-1];
    logic        expected_eligible_q [0:QUEUE_DEPTH-1];
    int          expected_advance_q [0:QUEUE_DEPTH-1];
    int          expected_id_q [0:QUEUE_DEPTH-1];
    int q_head;
    int q_tail;

    logic [31:0] issued_a_history [0:QUEUE_DEPTH-1];
    logic [31:0] issued_b_history [0:QUEUE_DEPTH-1];
    logic [31:0] issued_acc_history [0:QUEUE_DEPTH-1];
    logic [4:0]  issued_rd_history [0:QUEUE_DEPTH-1];
    logic        issued_chain_history [0:QUEUE_DEPTH-1];
    int          issued_advance_history [0:QUEUE_DEPTH-1];

    logic [31:0] chain_model_value;
    logic [4:0]  chain_model_rd;

    cpu_core_pipeline_dot4acc_issue #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .retire_valid(retire_valid),
        .retire_opcode(retire_opcode),
        .retire_reg_write(retire_reg_write),
        .retire_mem_write(retire_mem_write),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .pc_redirect(pc_redirect),
        .retired_instructions(retired_instructions),
        .load_use_stall_cycles(load_use_stall_cycles),
        .dot_issue_valid(dot_issue_valid),
        .dot_issue_accept(dot_issue_accept),
        .dot_issue_rd(dot_issue_rd),
        .dot_issue_packed_a(dot_issue_packed_a),
        .dot_issue_packed_b(dot_issue_packed_b),
        .dot_issue_accumulator(dot_issue_accumulator),
        .dot_issue_chain(dot_issue_chain),
        .dot_inflight_valid(dot_inflight_valid),
        .dot_inflight_rd(dot_inflight_rd),
        .dot_complete_valid(dot_complete_valid),
        .dot_complete_eligible(dot_complete_eligible),
        .dot_complete_rd(dot_complete_rd),
        .dot_complete_result(dot_complete_result),
        .dot_active(dot_active),
        .dot_frontend_hold(dot_frontend_hold),
        .dot_dependency_stall(dot_dependency_stall),
        .dot_source_dependency_stall(dot_source_dependency_stall),
        .dot_accumulator_dependency_stall(dot_accumulator_dependency_stall),
        .dot_cancel_event(dot_cancel_event)
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

    task automatic check_true(input string name, input bit condition);
        tests_run++;
        if (!condition) begin
            tests_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic check_equal32(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        tests_run++;
        if (actual !== expected) begin
            tests_failed++;
            $display("FAIL: %s | actual=0x%08h expected=0x%08h",
                     name, actual, expected);
        end
    endtask

    task automatic step_clock();
        @(posedge clk);
        #2;
    endtask

    task automatic run_clocks(input int count);
        repeat (count) step_clock();
    endtask

    task automatic clear_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        end
        for (int i = 0; i < DMEM_DEPTH; i++) begin
            dut.data_mem_inst.mem[i] = 32'h0000_0000;
        end
    endtask

    task automatic put_instruction(input int index, input logic [31:0] value);
        dut.instr_mem_inst.mem[index] = value;
    endtask

    task automatic reset_dut();
        enable = 1'b0;
        rst = 1'b1;
        run_clocks(4);
        rst = 1'b0;
        run_clocks(2);
        check_true("reset clears DOT activity", !dot_active && (dot_inflight_valid == 4'b0000));
        check_true("reset clears DOT completion", !dot_complete_valid);
        check_equal32("reset preserves architectural x0", dut.regs[0], 32'h0000_0000);
    endtask

    task automatic prepare_test();
        clear_memories();
        reset_dut();
    endtask

    task automatic run_until_completed(input int target, input int max_clocks);
        int clocks;
        clocks = 0;
        while ((completed_total < target) && (clocks < max_clocks)) begin
            step_clock();
            clocks++;
        end
        check_true("completion wait did not time out", clocks < max_clocks);
    endtask

    task automatic drain_dot(input int max_clocks);
        int clocks;
        clocks = 0;
        while (((q_head != q_tail) || dot_active) && (clocks < max_clocks)) begin
            step_clock();
            clocks++;
        end
        check_true("DOT path drained", (q_head == q_tail) && !dot_active);
    endtask

    // The scoreboard samples registered issue entries. One appears at the
    // issue-accept edge and must complete exactly three advancing edges later.
    always @(posedge clk) begin
        logic [31:0] expected;
        #1;
        if (rst) begin
            flushed_total = flushed_total + (q_tail - q_head);
            q_head = 0;
            q_tail = 0;
            advance_count = 0;
            chain_model_value = 32'h0000_0000;
            chain_model_rd = 5'd0;
            check_true("reset removes all DOT valid metadata",
                       (dot_inflight_valid == 4'b0000) && !dot_complete_valid);
        end else if (enable) begin
            advance_count++;

            if (dot_cancel_event) begin
                cancel_total++;
            end
            if (dot_dependency_stall) begin
                dependency_stall_total++;
            end
            if (dot_frontend_hold) begin
                frontend_hold_total++;
            end
            if (pc_redirect) begin
                redirect_total++;
            end

            if (dot_issue_valid) begin
                check_true("issue queue has capacity", q_tail < QUEUE_DEPTH);
                check_true("issued x0 is never eligible or chained",
                           (dot_issue_rd != 5'd0) || !dut.dot_issue_reg.eligible);
                check_true("chain bypass is restricted to a writable destination",
                           !dot_issue_chain || (dot_issue_rd != 5'd0));

                if (dot_issue_chain) begin
                    check_true("chain destination matches preceding logical accumulator",
                               dot_issue_rd == chain_model_rd);
                    expected = dot4acc_reference(
                        chain_model_value,
                        dot_issue_packed_a,
                        dot_issue_packed_b
                    );
                end else begin
                    expected = dot4acc_reference(
                        dot_issue_accumulator,
                        dot_issue_packed_a,
                        dot_issue_packed_b
                    );
                end

                expected_result_q[q_tail] = expected;
                expected_rd_q[q_tail] = dot_issue_rd;
                expected_eligible_q[q_tail] = (dot_issue_rd != 5'd0);
                expected_advance_q[q_tail] = advance_count + 3;
                expected_id_q[q_tail] = accepted_total;
                q_tail++;

                issued_a_history[accepted_total] = dot_issue_packed_a;
                issued_b_history[accepted_total] = dot_issue_packed_b;
                issued_acc_history[accepted_total] = dot_issue_accumulator;
                issued_rd_history[accepted_total] = dot_issue_rd;
                issued_chain_history[accepted_total] = dot_issue_chain;
                issued_advance_history[accepted_total] = advance_count;
                accepted_total++;

                chain_model_value = expected;
                chain_model_rd = dot_issue_rd;
            end

            if (dot_complete_valid) begin
                check_true("completion always has a queued transaction", q_head < q_tail);
                if (q_head < q_tail) begin
                    check_true("completion has exact three-advance latency",
                               advance_count == expected_advance_q[q_head]);
                    check_true("completion destination remains ordered",
                               dot_complete_rd == expected_rd_q[q_head]);
                    check_true("completion eligibility remains aligned",
                               dot_complete_eligible == expected_eligible_q[q_head]);
                    check_equal32("completion arithmetic matches Stage A1 oracle",
                                  dot_complete_result, expected_result_q[q_head]);
                    q_head++;
                    completed_total++;
                end
            end

            if (retire_valid) begin
                check_true("DOT4ACC never retires", retire_opcode != OP_DOT4ACC);
            end
            if (reg_write) begin
                check_true("DOT completion never drives register writeback",
                           dut.mem_wb_reg.opcode != OP_DOT4ACC);
            end
            if (mem_write) begin
                check_true("DOT completion never drives a memory write",
                           dut.ex_mem_reg.opcode != OP_DOT4ACC);
            end
            if ((|dot_inflight_valid) && dut.id_ex_reg.valid &&
                (dut.id_ex_reg.opcode != OP_DOT4ACC)) begin
                check_true("younger non-DOT cannot enter EX while DOT is in flight", 1'b0);
            end
        end
    end

    task automatic test_decode_and_single_issue();
        int accepted_before;
        int completed_target;
        logic [31:0] expected;
        $display("---- Stage C decode and isolated issue ----");
        prepare_test();
        dut.regs[1] = 32'h0403_0201;
        dut.regs[2] = 32'h0807_0605;
        dut.regs[5] = 32'h0000_0010;
        expected = dot4acc_reference(dut.regs[5], dut.regs[1], dut.regs[2]);
        accepted_before = accepted_total;
        completed_target = completed_total + 1;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, {OP_DOT4ACC, 5'd6, 5'd1, 5'd2, 13'h001});
        enable = 1'b1;
        run_until_completed(completed_target, 40);
        run_clocks(8);
        enable = 1'b0;
        check_true("only canonical DOT encoding issues", accepted_total == accepted_before + 1);
        check_equal32("single DOT result is observable", dot4acc_reference(
                      issued_acc_history[accepted_before],
                      issued_a_history[accepted_before],
                      issued_b_history[accepted_before]), expected);
        check_equal32("Stage C DOT cannot update destination register", dut.regs[5], 32'h0000_0010);
        check_true("noncanonical reserved bits are rejected", dut.if_id_reg.instruction[12:0] == 13'd0 || !dut.if_id_reg.valid);

        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        accepted_before = accepted_total;
        completed_target = completed_total + 1;
        put_instruction(0, encode_dot4acc(5'd0, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completed_target, 40);
        enable = 1'b0;
        check_true("rd=x0 issues once but is not eligible", accepted_total == accepted_before + 1);
        check_true("rd=x0 does not retain chain state", !issued_chain_history[accepted_before]);
        check_equal32("rd=x0 remains zero", dut.regs[0], 32'h0000_0000);
    endtask

    task automatic test_scalar_and_load_forwarding();
        int issue_base;
        int completion_target;
        int stall_before;
        $display("---- Scalar forwarding and LOAD dependencies ----");
        prepare_test();
        dut.regs[2] = 32'd3;
        dut.regs[4] = 32'd2;
        dut.regs[5] = 32'd9;
        dut.regs[6] = 32'd5;
        issue_base = accepted_total;
        completion_target = completed_total + 4;
        put_instruction(0, instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(7)));
        put_instruction(1, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(2, instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(-6)));
        put_instruction(3, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));
        put_instruction(4, encode_dot4acc(5'd6, 5'd3, 5'd4));
        put_instruction(5, instr(OP_ADDI, 5'd7, 5'd0, 5'd0, imm13_signed(11)));
        put_instruction(6, encode_dot4acc(5'd7, 5'd1, 5'd2));
        put_instruction(7, instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(12)));
        put_instruction(8, encode_dot4acc(5'd8, 5'd1, 5'd4));
        enable = 1'b1;
        run_until_completed(completion_target, 140);
        enable = 1'b0;
        check_equal32("EX/MEM scalar forwarding reaches DOT rs1",
                      issued_a_history[issue_base], 32'd7);
        check_equal32("MEM/WB scalar forwarding reaches DOT rs1",
                      issued_a_history[issue_base + 1], 32'hffff_fffa);
        check_equal32("scalar forwarding reaches DOT accumulator",
                      issued_acc_history[issue_base + 2], 32'd11);
        check_equal32("EX/MEM scalar forwarding reaches DOT rs2",
                      issued_b_history[issue_base + 3], 32'd12);
        check_true("all scalar-forwarding DOTs issue once",
                   accepted_total == issue_base + 4);

        prepare_test();
        dut.regs[10] = 32'd64;
        dut.regs[1] = 32'd2;
        dut.regs[2] = 32'd3;
        dut.regs[5] = 32'd10;
        dut.regs[6] = 32'd20;
        dut.regs[7] = 32'd30;
        dut.data_mem_inst.mem[16] = 32'h0102_0304;
        dut.data_mem_inst.mem[17] = 32'h0506_0708;
        dut.data_mem_inst.mem[18] = 32'h0000_0040;
        issue_base = accepted_total;
        completion_target = completed_total + 3;
        stall_before = load_use_stall_cycles;
        put_instruction(0, instr(OP_LOAD, 5'd1, 5'd10, 5'd0, imm13_signed(0)));
        put_instruction(1, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(2, instr(OP_LOAD, 5'd2, 5'd10, 5'd0, imm13_signed(4)));
        put_instruction(3, encode_dot4acc(5'd6, 5'd1, 5'd2));
        put_instruction(4, instr(OP_LOAD, 5'd7, 5'd10, 5'd0, imm13_signed(8)));
        put_instruction(5, encode_dot4acc(5'd7, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completion_target, 180);
        enable = 1'b0;
        check_equal32("LOAD forwarded into DOT rs1",
                      issued_a_history[issue_base], 32'h0102_0304);
        check_equal32("LOAD forwarded into DOT rs2",
                      issued_b_history[issue_base + 1], 32'h0506_0708);
        check_equal32("LOAD forwarded into DOT accumulator",
                      issued_acc_history[issue_base + 2], 32'h0000_0040);
        check_true("each LOAD dependency inserts exactly one decode bubble",
                   load_use_stall_cycles == stall_before + 3);
        check_true("LOAD-dependent DOTs are neither duplicated nor skipped",
                   accepted_total == issue_base + 3);
    endtask

    task automatic test_independent_and_chain_traffic();
        int issue_base;
        int completion_target;
        logic [31:0] logical_accumulator;
        $display("---- Independent II=1 and contiguous accumulator chains ----");
        prepare_test();
        dut.regs[1] = 32'h0403_0201;
        dut.regs[2] = 32'h0807_0605;
        for (int i = 0; i < 8; i++) begin
            dut.regs[8+i] = 32'h1000_0000 + i;
            put_instruction(i, encode_dot4acc(5'(8+i), 5'd1, 5'd2));
        end
        issue_base = accepted_total;
        completion_target = completed_total + 8;
        enable = 1'b1;
        run_until_completed(completion_target, 80);
        enable = 1'b0;
        check_true("eight independent DOT operations issue", accepted_total == issue_base + 8);
        for (int i = 1; i < 8; i++) begin
            check_true("independent DOT initiation interval is one",
                       issued_advance_history[issue_base+i] ==
                       issued_advance_history[issue_base+i-1] + 1);
            check_true("independent DOT never uses chain recurrence",
                       !issued_chain_history[issue_base+i]);
        end

        prepare_test();
        dut.regs[1] = 32'h0102_0304;
        dut.regs[2] = 32'h0506_0708;
        dut.regs[5] = 32'h0000_0020;
        for (int i = 0; i < 8; i++) begin
            put_instruction(i, encode_dot4acc(5'd5, 5'd1, 5'd2));
        end
        issue_base = accepted_total;
        completion_target = completed_total + 8;
        logical_accumulator = dut.regs[5];
        enable = 1'b1;
        run_until_completed(completion_target, 80);
        enable = 1'b0;
        check_true("eight same-rd DOT operations issue", accepted_total == issue_base + 8);
        check_true("chain head uses architectural accumulator",
                   !issued_chain_history[issue_base] &&
                   (issued_acc_history[issue_base] == logical_accumulator));
        for (int i = 1; i < 8; i++) begin
            check_true("same-rd chain initiation interval is one",
                       issued_advance_history[issue_base+i] ==
                       issued_advance_history[issue_base+i-1] + 1);
            check_true("same-rd continuation uses recurrence",
                       issued_chain_history[issue_base+i]);
            check_equal32("same-rd continuation isolates unavailable accumulator",
                          issued_acc_history[issue_base+i], 32'h0000_0000);
        end
        check_equal32("Stage C chain does not update architectural rd",
                      dut.regs[5], logical_accumulator);
    endtask

    task automatic test_dot_dependencies_and_chain_break();
        int issue_base;
        int completion_target;
        int stalls_before;
        $display("---- DOT destination dependencies and chain breaks ----");
        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[3] = 32'h0303_0303;
        dut.regs[5] = 32'd10;
        dut.regs[9] = 32'd20;
        issue_base = accepted_total;
        completion_target = completed_total + 2;
        stalls_before = dependency_stall_total;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, encode_dot4acc(5'd9, 5'd5, 5'd3));
        enable = 1'b1;
        run_until_completed(completion_target, 80);
        enable = 1'b0;
        check_true("packed-source dependency stalls before completion",
                   dependency_stall_total > stalls_before);
        check_equal32("completed DOT result forwards into dependent rs1",
                      issued_a_history[issue_base + 1],
                      dot4acc_reference(32'd10, 32'h0101_0101, 32'h0202_0202));
        check_true("dependent DOT issues exactly once", accepted_total == issue_base + 2);

        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[3] = 32'h0303_0303;
        dut.regs[5] = 32'd10;
        dut.regs[9] = 32'd20;
        issue_base = accepted_total;
        completion_target = completed_total + 2;
        stalls_before = dependency_stall_total;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, encode_dot4acc(5'd9, 5'd3, 5'd5));
        enable = 1'b1;
        run_until_completed(completion_target, 80);
        enable = 1'b0;
        check_true("second packed-source role stalls on in-flight DOT destination",
                   dependency_stall_total > stalls_before);
        check_equal32("completed DOT result forwards into dependent rs2",
                      issued_b_history[issue_base + 1],
                      dot4acc_reference(32'd10, 32'h0101_0101, 32'h0202_0202));

        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[3] = 32'h0303_0303;
        dut.regs[4] = 32'h0404_0404;
        dut.regs[5] = 32'd10;
        dut.regs[6] = 32'd20;
        issue_base = accepted_total;
        completion_target = completed_total + 3;
        stalls_before = dependency_stall_total;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, encode_dot4acc(5'd6, 5'd3, 5'd4));
        put_instruction(2, encode_dot4acc(5'd5, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completion_target, 100);
        enable = 1'b0;
        check_true("noncontiguous accumulator dependency stalls",
                   dependency_stall_total > stalls_before);
        check_true("noncontiguous same-rd operation is not a legal chain",
                   !issued_chain_history[issue_base + 2]);
        check_equal32("completed DOT result forwards into old-rd accumulator",
                      issued_acc_history[issue_base + 2],
                      dot4acc_reference(32'd10, 32'h0101_0101, 32'h0202_0202));

        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[5] = 32'd7;
        issue_base = accepted_total;
        completion_target = completed_total + 2;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, instr(OP_ADDI, 5'd20, 5'd0, 5'd0, imm13_signed(1)));
        put_instruction(2, encode_dot4acc(5'd5, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completion_target, 100);
        enable = 1'b0;
        check_true("scalar instruction breaks contiguous same-rd chain",
                   !issued_chain_history[issue_base + 1]);
        check_equal32("post-break DOT rereads architectural accumulator",
                      issued_acc_history[issue_base + 1], 32'd7);
        check_equal32("held scalar executes exactly once", dut.regs[20], 32'd1);
    endtask

    task automatic test_younger_hold_and_enable_freeze();
        int completion_target;
        logic [3:0] frozen_valid;
        logic [19:0] frozen_rd;
        int hold_before;
        $display("---- Younger non-DOT hold and global-enable freeze ----");
        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[5] = 32'd3;
        hold_before = frontend_hold_total;
        completion_target = completed_total + 1;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, instr(OP_ADDI, 5'd20, 5'd0, 5'd0, imm13_signed(9)));
        put_instruction(2, instr(OP_LOAD, 5'd21, 5'd0, 5'd0, imm13_signed(0)));
        put_instruction(3, instr(OP_STORE, 5'd0, 5'd0, 5'd20, imm13_signed(4)));
        put_instruction(4, instr(OP_BEQ, 5'd0, 5'd1, 5'd2, imm13_signed(1)));
        put_instruction(5, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(1)));
        enable = 1'b1;
        while (!dot_issue_valid) step_clock();
        frozen_valid = dot_inflight_valid;
        frozen_rd = dot_inflight_rd;
        enable = 1'b0;
        run_clocks(4);
        check_true("disable freezes every in-flight valid bit",
                   dot_inflight_valid == frozen_valid);
        check_true("disable freezes every in-flight destination",
                   dot_inflight_rd == frozen_rd);
        check_true("disable suppresses architectural side effects",
                   !reg_write && !mem_write && !retire_valid);
        enable = 1'b1;
        run_until_completed(completion_target, 80);
        run_clocks(35);
        enable = 1'b0;
        check_true("younger non-DOT frontend hold was exercised",
                   frontend_hold_total > hold_before);
        check_equal32("held ADD executes after DOT drain", dut.regs[20], 32'd9);
        check_equal32("held LOAD executes after DOT drain", dut.regs[21], 32'h0000_0000);
        check_equal32("held STORE executes after DOT drain", dut.data_mem_inst.mem[1], 32'd9);
        check_true("held branch and jump eventually resume without deadlock",
                   redirect_total > 0);
    endtask

    task automatic test_redirects();
        int issue_before;
        int cancel_before;
        int redirect_before;
        int completion_target;
        $display("---- Redirect age correctness ----");
        prepare_test();
        dut.regs[1] = 32'd1;
        dut.regs[2] = 32'd1;
        issue_before = accepted_total;
        cancel_before = cancel_total;
        put_instruction(0, instr(OP_BEQ, 5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instruction(1, encode_dot4acc(5'd5, 5'd3, 5'd4));
        enable = 1'b1;
        run_clocks(35);
        enable = 1'b0;
        check_true("taken older branch cancels younger DOT before issue",
                   accepted_total == issue_before);
        check_true("taken branch reports younger DOT cancellation",
                   cancel_total > cancel_before);

        prepare_test();
        dut.regs[1] = 32'd1;
        dut.regs[2] = 32'd2;
        dut.regs[3] = 32'h0101_0101;
        dut.regs[4] = 32'h0202_0202;
        issue_before = accepted_total;
        completion_target = completed_total + 1;
        put_instruction(0, instr(OP_BEQ, 5'd0, 5'd1, 5'd2, imm13_signed(2)));
        put_instruction(1, encode_dot4acc(5'd5, 5'd3, 5'd4));
        enable = 1'b1;
        run_until_completed(completion_target, 60);
        enable = 1'b0;
        check_true("not-taken branch permits younger DOT issue",
                   accepted_total == issue_before + 1);

        prepare_test();
        issue_before = accepted_total;
        redirect_before = redirect_total;
        put_instruction(0, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(2)));
        put_instruction(1, encode_dot4acc(5'd5, 5'd3, 5'd4));
        enable = 1'b1;
        run_clocks(35);
        enable = 1'b0;
        check_true("jump skips younger DOT before issue", accepted_total == issue_before);
        check_true("jump redirect occurs", redirect_total > redirect_before);
        check_true("redirect plus hold leaves DOT path drained", !dot_active);
    endtask

    task automatic test_reset_flush();
        int issue_target;
        int completion_before;
        int flushed_before;
        int completion_target;
        $display("---- Reset flush and recovery ----");
        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[5] = 32'd1;
        for (int i = 0; i < 8; i++) begin
            put_instruction(i, encode_dot4acc(5'd5, 5'd1, 5'd2));
        end
        issue_target = accepted_total + 4;
        enable = 1'b1;
        while (accepted_total < issue_target) step_clock();
        completion_before = completed_total;
        flushed_before = flushed_total;
        rst = 1'b1;
        run_clocks(2);
        rst = 1'b0;
        enable = 1'b0;
        run_clocks(3);
        check_true("reset flushes all accepted in-flight DOTs",
                   flushed_total > flushed_before);
        check_true("no pre-reset completion survives reset",
                   completed_total == completion_before);
        check_true("reset clears chain and frontend hold state",
                   !dot_active && !dot_frontend_hold && !dut.dot_chain_open_reg);

        clear_memories();
        dut.regs[1] = 32'h0303_0303;
        dut.regs[2] = 32'h0404_0404;
        dut.regs[6] = 32'd2;
        completion_target = completed_total + 1;
        put_instruction(0, encode_dot4acc(5'd6, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completion_target, 50);
        drain_dot(20);
        enable = 1'b0;
        check_true("normal DOT issue resumes after reset", !dot_active);
    endtask

    task automatic test_deterministic_stress();
        int accepted_before;
        int completed_before;
        int flushed_before;
        int cancel_before;
        $display("---- Deterministic 520-cycle issue-control stress ----");
        prepare_test();
        dut.regs[1] = 32'h0102_0304;
        dut.regs[2] = 32'h0506_0708;
        dut.regs[3] = 32'hfefd_fc80;
        dut.regs[4] = 32'h7f01_ff02;
        for (int block = 0; block < 15; block++) begin
            int base;
            base = block * 16;
            put_instruction(base+0, encode_dot4acc(5'd5, 5'd1, 5'd2));
            put_instruction(base+1, encode_dot4acc(5'd5, 5'd3, 5'd4));
            put_instruction(base+2, encode_dot4acc(5'd6, 5'd1, 5'd4));
            put_instruction(base+3, instr(OP_ADDI, 5'd20, 5'd20, 5'd0, imm13_signed(1)));
            put_instruction(base+4, instr(OP_LOAD, 5'd1, 5'd0, 5'd0, imm13_signed(0)));
            put_instruction(base+5, encode_dot4acc(5'd7, 5'd1, 5'd2));
            put_instruction(base+6, instr(OP_BEQ, 5'd0, 5'd0, 5'd0, imm13_signed(2)));
            put_instruction(base+7, encode_dot4acc(5'd8, 5'd3, 5'd4));
            put_instruction(base+8, encode_dot4acc(5'd9, 5'd2, 5'd3));
            put_instruction(base+9, instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(2)));
            put_instruction(base+10, encode_dot4acc(5'd10, 5'd1, 5'd2));
            put_instruction(base+11, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));
            put_instruction(base+12, encode_dot4acc(5'd11, 5'd3, 5'd4));
            put_instruction(base+13, encode_dot4acc(5'd12, 5'd1, 5'd2));
            put_instruction(base+14, instr(OP_STORE, 5'd0, 5'd0, 5'd20, imm13_signed(4)));
            put_instruction(base+15, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));
        end
        accepted_before = accepted_total;
        completed_before = completed_total;
        flushed_before = flushed_total;
        cancel_before = cancel_total;
        enable = 1'b1;
        for (int cycle = 0; cycle < 520; cycle++) begin
            if ((cycle == 170) || (cycle == 350)) begin
                rst = 1'b1;
            end else if ((cycle == 172) || (cycle == 352)) begin
                rst = 1'b0;
            end
            enable = ((cycle % 17) != 6);
            step_clock();
        end
        rst = 1'b0;
        enable = 1'b1;
        drain_dot(100);
        enable = 1'b0;
        check_true("stress accepts many DOT transactions",
                   accepted_total - accepted_before >= 45);
        check_true("stress completes or reset-flushes every accepted DOT",
                   (completed_total - completed_before) +
                   (flushed_total - flushed_before) ==
                   (accepted_total - accepted_before));
        check_true("stress exercises redirect cancellation",
                   cancel_total > cancel_before);
        check_true("stress leaves no queued transaction", q_head == q_tail);
        check_true("stress leaves no active DOT metadata", !dot_active);
    endtask

    initial begin
        tests_run = 0;
        tests_failed = 0;
        advance_count = 0;
        accepted_total = 0;
        completed_total = 0;
        flushed_total = 0;
        cancel_total = 0;
        dependency_stall_total = 0;
        frontend_hold_total = 0;
        redirect_total = 0;
        q_head = 0;
        q_tail = 0;
        chain_model_value = 32'h0000_0000;
        chain_model_rd = 5'd0;
        rst = 1'b0;
        enable = 1'b0;

        test_decode_and_single_issue();
        test_scalar_and_load_forwarding();
        test_independent_and_chain_traffic();
        test_dot_dependencies_and_chain_break();
        test_younger_hold_and_enable_freeze();
        test_redirects();
        test_reset_flush();
        test_deterministic_stress();

        $display("Stage C totals: accepted=%0d completed=%0d reset_flushed=%0d cancelled_before_issue=%0d",
                 accepted_total, completed_total, flushed_total, cancel_total);
        $display("Stage C checks: %0d, failures: %0d", tests_run, tests_failed);
        if (tests_failed != 0) begin
            $fatal(1, "TEST FAILED: Stage C DOT4ACC issue-control verification");
        end
        $display("TEST PASSED: Stage C DOT4ACC issue-control verification");
        $finish;
    end

endmodule
