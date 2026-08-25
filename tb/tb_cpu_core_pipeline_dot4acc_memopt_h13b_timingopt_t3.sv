import cpu_defs_pkg::*;
import dot4acc_reference_pkg::*;

module tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t3;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;
    localparam int unsigned QUEUE_DEPTH = 4096;

    logic clk;
    logic rst;
    logic enable;

    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [3:0]  retire_opcode;
    logic [4:0]  retire_rd;
    logic        retire_reg_write;
    logic [31:0] retire_write_data;
    logic        retire_mem_write;
    logic        reg_write;
    logic        mem_write;
    logic        pc_redirect;
    logic [31:0] retired_instructions;
    logic [31:0] total_cycles;
    logic [31:0] load_use_stall_cycles;

    logic        dot_issue_valid;
    logic        dot_issue_accept;
    logic [4:0]  dot_issue_rd;
    logic [31:0] dot_issue_packed_a;
    logic [31:0] dot_issue_packed_b;
    logic [31:0] dot_issue_accumulator;
    logic        dot_issue_chain;
    logic [31:0] dot_issue_pc;
    logic [3:0]  dot_issue_opcode;
    logic [3:0]  dot_inflight_valid;
    logic [19:0] dot_inflight_rd;
    logic        dot_complete_valid;
    logic        dot_complete_eligible;
    logic [4:0]  dot_complete_rd;
    logic [31:0] dot_complete_result;
    logic [31:0] dot_complete_pc;
    logic [3:0]  dot_complete_opcode;
    logic        normal_wb_valid;
    logic        dot_wb_valid;
    logic        rf_write_enable;
    logic [4:0]  rf_write_addr;
    logic [31:0] rf_write_data;
    logic        dot_retire_valid;
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
    int retired_dot_total;
    int dot_write_total;
    int normal_write_total;
    int memory_write_total;
    int benchmark_cycles;
    int flushed_total;
    int cancel_total;
    int dependency_stall_total;
    int frontend_hold_total;
    int redirect_total;

    logic [31:0] expected_result_q [0:QUEUE_DEPTH-1];
    logic [4:0]  expected_rd_q [0:QUEUE_DEPTH-1];
    logic [31:0] expected_pc_q [0:QUEUE_DEPTH-1];
    logic        expected_eligible_q [0:QUEUE_DEPTH-1];
    int          expected_advance_q [0:QUEUE_DEPTH-1];
    int          expected_id_q [0:QUEUE_DEPTH-1];
    int q_head;
    int q_tail;

    logic [31:0] issued_a_history [0:QUEUE_DEPTH-1];
    logic [31:0] issued_b_history [0:QUEUE_DEPTH-1];
    logic [31:0] issued_acc_history [0:QUEUE_DEPTH-1];
    logic [4:0]  issued_rd_history [0:QUEUE_DEPTH-1];
    logic [31:0] issued_pc_history [0:QUEUE_DEPTH-1];
    logic        issued_chain_history [0:QUEUE_DEPTH-1];
    int          issued_advance_history [0:QUEUE_DEPTH-1];

    logic [31:0] chain_model_value;
    logic [4:0]  chain_model_rd;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t3 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_opcode(retire_opcode),
        .retire_rd(retire_rd),
        .retire_reg_write(retire_reg_write),
        .retire_write_data(retire_write_data),
        .retire_mem_write(retire_mem_write),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .pc_redirect(pc_redirect),
        .retired_instructions(retired_instructions),
        .total_cycles(total_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .dot_issue_valid(dot_issue_valid),
        .dot_issue_accept(dot_issue_accept),
        .dot_issue_rd(dot_issue_rd),
        .dot_issue_packed_a(dot_issue_packed_a),
        .dot_issue_packed_b(dot_issue_packed_b),
        .dot_issue_accumulator(dot_issue_accumulator),
        .dot_issue_chain(dot_issue_chain),
        .dot_issue_pc(dot_issue_pc),
        .dot_issue_opcode(dot_issue_opcode),
        .dot_inflight_valid(dot_inflight_valid),
        .dot_inflight_rd(dot_inflight_rd),
        .dot_complete_valid(dot_complete_valid),
        .dot_complete_eligible(dot_complete_eligible),
        .dot_complete_rd(dot_complete_rd),
        .dot_complete_result(dot_complete_result),
        .dot_complete_pc(dot_complete_pc),
        .dot_complete_opcode(dot_complete_opcode),
        .normal_wb_valid(normal_wb_valid),
        .dot_wb_valid(dot_wb_valid),
        .rf_write_enable(rf_write_enable),
        .rf_write_addr(rf_write_addr),
        .rf_write_data(rf_write_data),
        .dot_retire_valid(dot_retire_valid),
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
        while ((retired_dot_total < target) && (clocks < max_clocks)) begin
            step_clock();
            clocks++;
        end
        check_true("DOT retirement wait did not time out", clocks < max_clocks);
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

    task automatic run_single_dot_case(
        input string       name,
        input logic [31:0] accumulator,
        input logic [31:0] packed_a,
        input logic [31:0] packed_b
    );
        int target;
        logic [31:0] expected;
        prepare_test();
        dut.regs[1] = packed_a;
        dut.regs[2] = packed_b;
        dut.regs[5] = accumulator;
        expected = dot4acc_reference(accumulator, packed_a, packed_b);
        target = retired_dot_total + 1;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(target, 50);
        enable = 1'b0;
        check_equal32(name, dut.regs[5], expected);
    endtask

    // Registered issue appears at acceptance. Arithmetic completion follows
    // three advancing edges later and architectural writeback/retirement is
    // consumed exactly once on the fourth advancing edge.
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

            if (normal_wb_valid && dot_wb_valid) begin
                check_true("single write-port collision is explicitly deferred",
                           dut.dot_load_completion_deferred || dut.deferred_load_valid);
            end

            // Retirement is checked before the next arithmetic completion so
            // back-to-back DOTs can retire and complete on the same edge.
            if (dot_retire_valid) begin
                check_true("DOT retirement always has a queued transaction", q_head < q_tail);
                if (q_head < q_tail) begin
                    check_true("DOT retirement has exact four-advance latency",
                               advance_count == expected_advance_q[q_head] + 1);
                    check_true("DOT retirement PC remains ordered",
                               retire_pc == expected_pc_q[q_head]);
                    check_true("DOT retirement opcode identifies DOT4ACC",
                               retire_opcode == OP_DOT4ACC);
                    check_true("DOT retirement destination remains ordered",
                               retire_rd == expected_rd_q[q_head]);
                    check_equal32("DOT retirement result matches Stage A1 oracle",
                                  retire_write_data, expected_result_q[q_head]);
                    check_true("DOT retirement write eligibility is aligned",
                               retire_reg_write == expected_eligible_q[q_head]);
                    if (expected_eligible_q[q_head]) begin
                        check_equal32("architectural rd contains retired DOT result",
                                      dut.regs[expected_rd_q[q_head]],
                                      expected_result_q[q_head]);
                        dot_write_total++;
                    end else begin
                        check_equal32("x0 remains hardwired at DOT retirement",
                                      dut.regs[0], 32'h0000_0000);
                    end
                    q_head++;
                    retired_dot_total++;
                end
            end else if (retire_valid && retire_reg_write) begin
                normal_write_total++;
            end
            if (retire_mem_write) begin
                memory_write_total++;
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
                expected_pc_q[q_tail] = dot_issue_pc;
                expected_eligible_q[q_tail] = (dot_issue_rd != 5'd0);
                expected_advance_q[q_tail] = advance_count + 3;
                expected_id_q[q_tail] = accepted_total;
                q_tail++;

                issued_a_history[accepted_total] = dot_issue_packed_a;
                issued_b_history[accepted_total] = dot_issue_packed_b;
                issued_acc_history[accepted_total] = dot_issue_accumulator;
                issued_rd_history[accepted_total] = dot_issue_rd;
                issued_pc_history[accepted_total] = dot_issue_pc;
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
                    check_true("completion PC remains ordered",
                               dot_complete_pc == expected_pc_q[q_head]);
                    check_true("completion opcode identifies DOT4ACC",
                               dot_complete_opcode == OP_DOT4ACC);
                    check_true("completion eligibility remains aligned",
                               dot_complete_eligible == expected_eligible_q[q_head]);
                    check_equal32("completion arithmetic matches Stage A1 oracle",
                                  dot_complete_result, expected_result_q[q_head]);
                    completed_total++;
                end
            end

            if (mem_write) begin
                check_true("DOT completion never drives a memory write",
                           dut.ex_mem_reg.opcode != OP_DOT4ACC);
            end
            if ((|dot_inflight_valid) && dut.id_ex_reg.valid &&
                (dut.id_ex_reg.opcode != OP_DOT4ACC)) begin
                check_true("only a qualified LOAD may enter EX while DOT is in flight",
                           (dut.id_ex_reg.opcode == OP_LOAD) &&
                           (dut.load_overlap_reserved ||
                            dut.second_load_reserved));
            end
        end
    end

    // Independently prove the architectural retired-instruction counter has
    // exactly the same one-shot event equation as the CPU implementation.
    always @(posedge clk) begin
        logic [31:0] count_before;
        logic        event_before;
        count_before = retired_instructions;
        event_before = dut.mem_wb_reg.valid || dot_complete_valid ||
                       dut.deferred_load_valid;
        #1;
        if (rst) begin
            check_equal32("reset clears retired-instruction counter",
                          retired_instructions, 32'd0);
        end else if (enable) begin
            check_equal32("retired-instruction counter advances exactly once per event",
                          retired_instructions,
                          count_before + {31'd0, event_before});
        end else begin
            check_equal32("retired-instruction counter freezes while disabled",
                          retired_instructions, count_before);
        end
    end

    task automatic test_signed_architectural_vectors();
        $display("---- Signed architectural arithmetic vectors ----");
        run_single_dot_case("all-positive architectural vector",
                            32'h0000_0010, 32'h7f7f_7f7f, 32'h0102_0304);
        run_single_dot_case("mixed-sign architectural vector",
                            32'hffff_ff00, 32'h807f_ff01, 32'h7f80_01ff);
        run_single_dot_case("-128 by -128 architectural vector",
                            32'h0000_0000, 32'h8080_8080, 32'h8080_8080);
        run_single_dot_case("-128 by +127 architectural vector",
                            32'h0000_0000, 32'h8080_8080, 32'h7f7f_7f7f);
        run_single_dot_case("positive modulo-2^32 wrap",
                            32'hffff_ff00, 32'h7f7f_7f7f, 32'h7f7f_7f7f);
        run_single_dot_case("negative modulo-2^32 wrap",
                            32'h0000_0100, 32'h8080_8080, 32'h7f7f_7f7f);
    endtask

    task automatic test_decode_and_single_issue();
        int accepted_before;
        int completed_target;
        logic [31:0] expected;
        $display("---- Stage D decode, writeback and retirement ----");
        prepare_test();
        dut.regs[1] = 32'h0403_0201;
        dut.regs[2] = 32'h0807_0605;
        dut.regs[5] = 32'h0000_0010;
        expected = dot4acc_reference(dut.regs[5], dut.regs[1], dut.regs[2]);
        accepted_before = accepted_total;
        completed_target = retired_dot_total + 1;
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
        check_equal32("single DOT updates architectural destination", dut.regs[5], expected);
        check_true("noncanonical reserved bits are rejected", dut.if_id_reg.instruction[12:0] == 13'd0 || !dut.if_id_reg.valid);

        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        accepted_before = accepted_total;
        completed_target = retired_dot_total + 1;
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
        completion_target = retired_dot_total + 4;
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
        completion_target = retired_dot_total + 3;
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
        completion_target = retired_dot_total + 8;
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
        completion_target = retired_dot_total + 8;
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
        for (int i = 0; i < 8; i++) begin
            logical_accumulator = dot4acc_reference(
                logical_accumulator, dut.regs[1], dut.regs[2]);
        end
        check_equal32("Stage D chain writes the final logical accumulator",
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
        completion_target = retired_dot_total + 2;
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
        completion_target = retired_dot_total + 2;
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
        completion_target = retired_dot_total + 3;
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
        completion_target = retired_dot_total + 2;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, instr(OP_ADDI, 5'd20, 5'd0, 5'd0, imm13_signed(1)));
        put_instruction(2, encode_dot4acc(5'd5, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completion_target, 100);
        enable = 1'b0;
        check_true("scalar instruction breaks contiguous same-rd chain",
                   !issued_chain_history[issue_base + 1]);
        check_equal32("post-break DOT rereads architectural accumulator",
                      issued_acc_history[issue_base + 1],
                      dot4acc_reference(32'd7, 32'h0101_0101, 32'h0202_0202));
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
        completion_target = retired_dot_total + 1;
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

    task automatic test_normal_writeback_arbitration();
        int target;
        int normal_before;
        logic [31:0] expected;
        $display("---- Single-port normal/DOT writeback arbitration ----");

        prepare_test();
        dut.regs[1] = 32'd11;
        dut.regs[2] = 32'd7;
        dut.regs[6] = 32'h0101_0101;
        dut.regs[7] = 32'h0202_0202;
        dut.regs[5] = 32'd9;
        expected = dot4acc_reference(32'd9, dut.regs[6], dut.regs[7]);
        normal_before = normal_write_total;
        target = retired_dot_total + 1;
        put_instruction(0, instr(OP_ADD, 5'd3, 5'd1, 5'd2, 13'd0));
        put_instruction(1, encode_dot4acc(5'd5, 5'd6, 5'd7));
        enable = 1'b1;
        run_until_completed(target, 70);
        enable = 1'b0;
        check_equal32("older ADD writes before younger DOT", dut.regs[3], 32'd18);
        check_equal32("DOT survives older ADD writeback", dut.regs[5], expected);
        check_true("older ADD writeback was observed exactly once",
                   normal_write_total == normal_before + 1);

        prepare_test();
        dut.regs[10] = 32'd64;
        dut.data_mem_inst.mem[16] = 32'h1234_5678;
        dut.regs[6] = 32'h0101_0101;
        dut.regs[7] = 32'h0202_0202;
        target = retired_dot_total + 1;
        normal_before = normal_write_total;
        put_instruction(0, instr(OP_LOAD, 5'd3, 5'd10, 5'd0, 13'd0));
        put_instruction(1, encode_dot4acc(5'd5, 5'd6, 5'd7));
        enable = 1'b1;
        run_until_completed(target, 70);
        enable = 1'b0;
        check_equal32("older LOAD writes before younger DOT",
                      dut.regs[3], 32'h1234_5678);
        check_true("older LOAD writeback was observed exactly once",
                   normal_write_total == normal_before + 1);
    endtask

    task automatic test_dot_to_scalar_consumers();
        int target;
        int stores_before;
        logic [31:0] expected;
        $display("---- DOT result visibility to resumed scalar consumers ----");
        prepare_test();
        dut.regs[1] = 32'h0102_0304;
        dut.regs[2] = 32'h0506_0708;
        dut.regs[3] = 32'd21;
        dut.regs[5] = 32'd13;
        dut.regs[10] = 32'd64;
        expected = dot4acc_reference(dut.regs[5], dut.regs[1], dut.regs[2]);
        dut.regs[4] = expected;
        target = retired_dot_total + 1;
        stores_before = memory_write_total;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, instr(OP_ADD, 5'd6, 5'd5, 5'd3, 13'd0));
        put_instruction(2, instr(OP_SUB, 5'd7, 5'd3, 5'd5, 13'd0));
        put_instruction(3, instr(OP_STORE, 5'd0, 5'd10, 5'd5, imm13_signed(4)));
        put_instruction(4, instr(OP_BEQ, 5'd0, 5'd5, 5'd4, imm13_signed(2)));
        put_instruction(5, instr(OP_ADDI, 5'd20, 5'd0, 5'd0, imm13_signed(1)));
        put_instruction(6, instr(OP_ADDI, 5'd20, 5'd0, 5'd0, imm13_signed(2)));
        enable = 1'b1;
        run_until_completed(target, 60);
        run_clocks(45);
        enable = 1'b0;
        check_equal32("DOT-to-ADD consumer sees new rd",
                      dut.regs[6], expected + 32'd21);
        check_equal32("DOT-to-SUB consumer sees new rd",
                      dut.regs[7], 32'd21 - expected);
        check_equal32("DOT-to-STORE consumer sees new rd",
                      dut.data_mem_inst.mem[17], expected);
        check_true("DOT-dependent STORE executes exactly once",
                   memory_write_total == stores_before + 1);
        check_equal32("DOT-to-BEQ consumer takes branch using new rd",
                      dut.regs[20], 32'd2);
    endtask

    task automatic test_completion_freeze();
        int target;
        int retired_before;
        logic [31:0] frozen_result;
        logic [31:0] frozen_pc;
        logic [4:0]  frozen_rd;
        logic [31:0] original_rd;
        $display("---- Completion freeze and exactly-once resume ----");
        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[5] = 32'd17;
        original_rd = dut.regs[5];
        target = retired_dot_total + 1;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        enable = 1'b1;
        while (!dot_complete_valid) step_clock();
        frozen_result = dot_complete_result;
        frozen_pc = dot_complete_pc;
        frozen_rd = dot_complete_rd;
        retired_before = retired_dot_total;
        enable = 1'b0;
        run_clocks(4);
        check_true("completion validity remains stable while frozen", dot_complete_valid);
        check_equal32("completion result remains stable while frozen",
                      dot_complete_result, frozen_result);
        check_equal32("completion PC remains stable while frozen",
                      dot_complete_pc, frozen_pc);
        check_true("completion destination remains stable while frozen",
                   dot_complete_rd == frozen_rd);
        check_true("frozen completion is not retired", retired_dot_total == retired_before);
        check_equal32("frozen completion has not written architectural rd",
                      dut.regs[5], original_rd);
        enable = 1'b1;
        run_until_completed(target, 20);
        enable = 1'b0;
        check_true("resumed completion retires exactly once",
                   retired_dot_total == retired_before + 1);
        check_equal32("resumed completion writes expected result",
                      dut.regs[5], frozen_result);
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
        completion_target = retired_dot_total + 1;
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
        completion_target = retired_dot_total + 1;
        put_instruction(0, encode_dot4acc(5'd6, 5'd1, 5'd2));
        enable = 1'b1;
        run_until_completed(completion_target, 50);
        drain_dot(20);
        enable = 1'b0;
        check_true("normal DOT issue resumes after reset", !dot_active);
    endtask

    task automatic test_deterministic_stress();
        int accepted_before;
        int retired_before;
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
        retired_before = retired_dot_total;
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
        check_true("stress retires or reset-flushes every accepted DOT",
                   (retired_dot_total - retired_before) +
                   (flushed_total - flushed_before) ==
                   (accepted_total - accepted_before));
        check_true("stress exercises redirect cancellation",
                   cancel_total > cancel_before);
        check_true("stress leaves no queued transaction", q_head == q_tail);
        check_true("stress leaves no active DOT metadata", !dot_active);
    endtask

    task automatic test_g1_chain_redirect_boundaries();
        int accepted_before;
        int cancel_before;
        int history_start;
        bit found_nonchain_dot;
        $display("---- G1 chain/redirect boundary equivalence ----");

        // A taken branch is a non-DOT contiguity break; the younger DOT is
        // wrong-path and must never be accepted.
        prepare_test();
        dut.regs[1] = 32'h0101_0101;
        dut.regs[2] = 32'h0202_0202;
        dut.regs[3] = 32'd7;
        dut.regs[4] = 32'd7;
        accepted_before = accepted_total;
        cancel_before = cancel_total;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(2, instr(OP_BEQ, 5'd0, 5'd3, 5'd4, imm13_signed(2)));
        put_instruction(3, encode_dot4acc(5'd6, 5'd1, 5'd2));
        put_instruction(4, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));
        enable = 1'b1;
        run_clocks(90);
        enable = 1'b0;
        check_true("G1 taken branch preserves accepted DOT chain members",
                   accepted_total == accepted_before + 2);
        check_true("G1 taken branch cancels wrong-path DOT",
                   cancel_total > cancel_before);

        // A not-taken branch still breaks same-rd contiguity, so the DOT
        // after it may issue but must not be marked as a continuation.
        prepare_test();
        dut.regs[1] = 32'h0303_0303;
        dut.regs[2] = 32'h0404_0404;
        dut.regs[3] = 32'd7;
        dut.regs[4] = 32'd8;
        accepted_before = accepted_total;
        history_start = accepted_total;
        put_instruction(0, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(1, encode_dot4acc(5'd5, 5'd1, 5'd2));
        put_instruction(2, instr(OP_BEQ, 5'd0, 5'd3, 5'd4, imm13_signed(2)));
        put_instruction(3, encode_dot4acc(5'd5, 5'd1, 5'd2));
        enable = 1'b1;
        run_clocks(100);
        enable = 1'b0;
        found_nonchain_dot = 1'b0;
        for (int i = history_start; i < accepted_total; i++) begin
            if (issued_pc_history[i] == 32'd12) begin
                found_nonchain_dot = 1'b1;
                check_true("G1 not-taken branch ends DOT chain",
                           !issued_chain_history[i]);
            end
        end
        check_true("G1 not-taken branch permits following DOT",
                   accepted_total >= accepted_before + 3);
        check_true("G1 following DOT was observed after chain break",
                   found_nonchain_dot);
    endtask

    task automatic test_executable_program();
        int dot_before;
        int store_before;
        int clocks;
        logic [31:0] expected;
        $display("---- Executable Stage D DOT4ACC program ----");
        prepare_test();
        $readmemh("programs/dot4acc_stage_d.mem", dut.instr_mem_inst.mem, 0, 7);
        dut.data_mem_inst.mem[16] = 32'h0102_0304;
        dut.data_mem_inst.mem[17] = 32'h0506_0708;
        dut.data_mem_inst.mem[18] = 32'h0000_0020;
        expected = dot4acc_reference(32'h0000_0020,
                                     32'h0102_0304, 32'h0506_0708);
        expected = dot4acc_reference(expected,
                                     32'h0102_0304, 32'h0506_0708);
        dot_before = retired_dot_total;
        store_before = memory_write_total;
        clocks = 0;
        enable = 1'b1;
        while ((memory_write_total == store_before) && (clocks < 120)) begin
            step_clock();
            clocks++;
        end
        benchmark_cycles = total_cycles;
        enable = 1'b0;
        check_true("executable program reaches final STORE", clocks < 120);
        check_true("executable program retires both DOT instructions",
                   retired_dot_total == dot_before + 2);
        check_equal32("executable program final architectural rd",
                      dut.regs[5], expected);
        check_equal32("executable program stored result",
                      dut.data_mem_inst.mem[0], expected);
        $display("Stage D executable program: cycles=%0d result=0x%08h",
                 benchmark_cycles, expected);
    endtask

    initial begin
        tests_run = 0;
        tests_failed = 0;
        advance_count = 0;
        accepted_total = 0;
        completed_total = 0;
        retired_dot_total = 0;
        dot_write_total = 0;
        normal_write_total = 0;
        memory_write_total = 0;
        benchmark_cycles = 0;
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

        test_signed_architectural_vectors();
        test_decode_and_single_issue();
        test_scalar_and_load_forwarding();
        test_independent_and_chain_traffic();
        test_dot_dependencies_and_chain_break();
        test_younger_hold_and_enable_freeze();
        test_normal_writeback_arbitration();
        test_dot_to_scalar_consumers();
        test_completion_freeze();
        test_redirects();
        test_g1_chain_redirect_boundaries();
        test_reset_flush();
        test_executable_program();
        test_deterministic_stress();

        $display("Stage D totals: accepted=%0d completed=%0d retired=%0d writes=%0d reset_flushed=%0d cancelled_before_issue=%0d",
                 accepted_total, completed_total, retired_dot_total, dot_write_total,
                 flushed_total, cancel_total);
        $display("Stage D checks: %0d, failures: %0d", tests_run, tests_failed);
        if (tests_failed != 0) begin
            $fatal(1, "TEST FAILED: Stage D DOT4ACC architectural verification");
        end
        $display("TEST PASSED: Stage D DOT4ACC architectural verification");
        $finish;
    end

endmodule
