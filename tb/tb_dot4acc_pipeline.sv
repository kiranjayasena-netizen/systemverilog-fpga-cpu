import dot4acc_reference_pkg::*;

module tb_dot4acc_pipeline;

    localparam int PIPELINE_STAGES = 3;
    localparam int MAX_EXPECTED_TRANSACTIONS = 4096;

    logic clk;
    logic rst;
    logic enable;
    logic input_valid;
    logic [31:0] accumulator;
    logic [31:0] packed_a;
    logic [31:0] packed_b;
    logic output_valid;
    logic [31:0] result;

    logic [31:0] expected_result [0:MAX_EXPECTED_TRANSACTIONS-1];
    int unsigned expected_id [0:MAX_EXPECTED_TRANSACTIONS-1];
    int unsigned expected_advance [0:MAX_EXPECTED_TRANSACTIONS-1];
    int unsigned queue_head;
    int unsigned queue_tail;
    int unsigned next_transaction_id;
    int unsigned advance_count;
    int unsigned accepted_count;
    int unsigned completed_count;
    int unsigned flushed_count;
    int unsigned tests_run;
    int unsigned tests_failed;

    dot4acc_pipeline dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .input_valid(input_valid),
        .accumulator(accumulator),
        .packed_a(packed_a),
        .packed_b(packed_b),
        .output_valid(output_valid),
        .result(result)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function automatic logic [31:0] pack_lanes(
        input int signed lane0,
        input int signed lane1,
        input int signed lane2,
        input int signed lane3
    );
        pack_lanes = {lane3[7:0], lane2[7:0], lane1[7:0], lane0[7:0]};
    endfunction

    // Independent scalar-lane model used only as a cross-check on the Stage A1
    // canonical oracle. Its sequential 64-bit accumulation does not reproduce
    // the RTL's balanced, explicitly widened adder tree.
    function automatic logic [31:0] four_scalar_mac_model(
        input logic [31:0] initial_accumulator,
        input logic [31:0] source_a,
        input logic [31:0] source_b
    );
        logic signed [63:0] running_sum;
        int unsigned lane_a_bits;
        int unsigned lane_b_bits;
        int signed lane_a_value;
        int signed lane_b_value;

        running_sum = $signed({{32{initial_accumulator[31]}}, initial_accumulator});
        for (int lane = 0; lane < 4; lane++) begin
            lane_a_bits = (source_a >> (lane * 8)) & 32'h0000_00ff;
            lane_b_bits = (source_b >> (lane * 8)) & 32'h0000_00ff;
            lane_a_value = (lane_a_bits >= 128) ? int'(lane_a_bits) - 256 : int'(lane_a_bits);
            lane_b_value = (lane_b_bits >= 128) ? int'(lane_b_bits) - 256 : int'(lane_b_bits);
            running_sum = running_sum + (lane_a_value * lane_b_value);
        end
        four_scalar_mac_model = running_sum[31:0];
    endfunction

    task automatic record_check(input string name, input bit condition);
        tests_run++;
        if (!condition) begin
            tests_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic mark_group(input string name, input int unsigned failures_before);
        record_check(name, tests_failed == failures_before);
        if (tests_failed == failures_before) begin
            $display("PASS: %s", name);
        end
    endtask

    task automatic drive_cycle(
        input logic cycle_rst,
        input logic cycle_enable,
        input logic cycle_valid,
        input logic [31:0] cycle_accumulator,
        input logic [31:0] cycle_a,
        input logic [31:0] cycle_b
    );
        @(negedge clk);
        rst = cycle_rst;
        enable = cycle_enable;
        input_valid = cycle_valid;
        accumulator = cycle_accumulator;
        packed_a = cycle_a;
        packed_b = cycle_b;
        @(posedge clk);
        #2;
    endtask

    task automatic reset_pipeline;
        drive_cycle(1'b1, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
        drive_cycle(1'b0, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
    endtask

    task automatic send_transaction(
        input logic [31:0] transaction_accumulator,
        input logic [31:0] transaction_a,
        input logic [31:0] transaction_b
    );
        drive_cycle(
            1'b0,
            1'b1,
            1'b1,
            transaction_accumulator,
            transaction_a,
            transaction_b
        );
    endtask

    task automatic advance_bubble;
        drive_cycle(1'b0, 1'b1, 1'b0, 32'hdead_beef, 32'h89ab_cdef, 32'h0123_4567);
    endtask

    task automatic drain_pipeline;
        repeat (PIPELINE_STAGES) begin
            advance_bubble();
        end
        record_check("pipeline drain leaves scoreboard empty", queue_head == queue_tail);
        record_check("pipeline drain clears output valid", output_valid === 1'b0);
    endtask

    task automatic send_directed(
        input logic [31:0] transaction_accumulator,
        input logic [31:0] transaction_a,
        input logic [31:0] transaction_b
    );
        logic [31:0] canonical_result;
        logic [31:0] scalar_result;

        canonical_result = dot4acc_reference(
            transaction_accumulator,
            transaction_a,
            transaction_b
        );
        scalar_result = four_scalar_mac_model(
            transaction_accumulator,
            transaction_a,
            transaction_b
        );
        record_check("Stage A1 oracle equals four scalar MACs", canonical_result == scalar_result);
        send_transaction(transaction_accumulator, transaction_a, transaction_b);
    endtask

    // The monitor samples after the DUT's nonblocking assignments. The
    // acceptance edge is stage advance 1, so completion is due on advance 3:
    // accepted_advance + PIPELINE_STAGES - 1.
    always @(posedge clk) begin : scoreboard_monitor
        logic held_output_valid;
        logic [31:0] held_result;
        logic held_stage1_valid;
        logic held_stage2_valid;
        dot4acc_product_t held_product0;
        dot4acc_product_t held_product1;
        dot4acc_product_t held_product2;
        dot4acc_product_t held_product3;
        dot4acc_pair_sum_t held_pair0;
        dot4acc_pair_sum_t held_pair1;
        logic signed [31:0] held_stage1_accumulator;
        logic signed [31:0] held_stage2_accumulator;
        int unsigned current_advance;
        int unsigned due_id;
        logic [31:0] due_result;

        held_output_valid = output_valid;
        held_result = result;
        held_stage1_valid = dut.stage1_valid_reg;
        held_stage2_valid = dut.stage2_valid_reg;
        held_product0 = dut.product0_reg;
        held_product1 = dut.product1_reg;
        held_product2 = dut.product2_reg;
        held_product3 = dut.product3_reg;
        held_pair0 = dut.pair0_reg;
        held_pair1 = dut.pair1_reg;
        held_stage1_accumulator = dut.stage1_accumulator_reg;
        held_stage2_accumulator = dut.stage2_accumulator_reg;

        #1;
        if (rst) begin
            flushed_count = flushed_count + (queue_tail - queue_head);
            queue_head = 0;
            queue_tail = 0;
            advance_count = 0;
            record_check("reset clears stage 1 valid", dut.stage1_valid_reg === 1'b0);
            record_check("reset clears stage 2 valid", dut.stage2_valid_reg === 1'b0);
            record_check("reset clears output valid", output_valid === 1'b0);
        end else if (!enable) begin
            record_check("disabled stage 1 valid stable", dut.stage1_valid_reg === held_stage1_valid);
            record_check("disabled stage 2 valid stable", dut.stage2_valid_reg === held_stage2_valid);
            record_check("disabled output valid stable", output_valid === held_output_valid);
            record_check("disabled result stable", result === held_result);
            record_check("disabled product 0 stable", dut.product0_reg === held_product0);
            record_check("disabled product 1 stable", dut.product1_reg === held_product1);
            record_check("disabled product 2 stable", dut.product2_reg === held_product2);
            record_check("disabled product 3 stable", dut.product3_reg === held_product3);
            record_check("disabled pair 0 stable", dut.pair0_reg === held_pair0);
            record_check("disabled pair 1 stable", dut.pair1_reg === held_pair1);
            record_check(
                "disabled stage 1 accumulator stable",
                dut.stage1_accumulator_reg === held_stage1_accumulator
            );
            record_check(
                "disabled stage 2 accumulator stable",
                dut.stage2_accumulator_reg === held_stage2_accumulator
            );
        end else begin
            current_advance = advance_count + 1;
            advance_count = current_advance;

            if ((queue_head < queue_tail) &&
                (expected_advance[queue_head] == current_advance)) begin
                due_id = expected_id[queue_head];
                due_result = expected_result[queue_head];
                record_check("due transaction asserts output_valid", output_valid === 1'b1);
                record_check(
                    $sformatf("transaction %0d result matches Stage A1", due_id),
                    result === due_result
                );
                queue_head++;
                completed_count++;
            end else begin
                record_check("bubble/non-due advance has no output_valid", output_valid === 1'b0);
            end

            if (input_valid) begin
                record_check(
                    "scoreboard capacity",
                    queue_tail < MAX_EXPECTED_TRANSACTIONS
                );
                if (queue_tail < MAX_EXPECTED_TRANSACTIONS) begin
                    expected_result[queue_tail] = dot4acc_reference(
                        accumulator,
                        packed_a,
                        packed_b
                    );
                    expected_id[queue_tail] = next_transaction_id;
                    expected_advance[queue_tail] =
                        current_advance + PIPELINE_STAGES - 1;
                    queue_tail++;
                    next_transaction_id++;
                    accepted_count++;
                end
            end
        end
    end

    initial begin
        int unsigned failures_before;
        int unsigned completed_before;
        int unsigned accepted_before;
        logic [31:0] lcg_state;
        logic stress_enable;
        logic stress_valid;
        logic stress_reset;
        logic [31:0] stress_accumulator;
        logic [31:0] stress_a;
        logic [31:0] stress_b;

        rst = 1'b0;
        enable = 1'b0;
        input_valid = 1'b0;
        accumulator = 32'd0;
        packed_a = 32'd0;
        packed_b = 32'd0;
        queue_head = 0;
        queue_tail = 0;
        next_transaction_id = 0;
        advance_count = 0;
        accepted_count = 0;
        completed_count = 0;
        flushed_count = 0;
        tests_run = 0;
        tests_failed = 0;

        $display("---- DOT4ACC pipeline arithmetic ----");
        reset_pipeline();
        failures_before = tests_failed;
        send_directed(32'h0000_0000, pack_lanes(0, 0, 0, 0), pack_lanes(0, 0, 0, 0));
        send_directed(32'h0000_0000, pack_lanes(1, 2, 3, 4), pack_lanes(5, 6, 7, 8));
        send_directed(32'h0000_0000, pack_lanes(-1, -2, -3, -4), pack_lanes(-5, -6, -7, -8));
        send_directed(32'h0000_0000, pack_lanes(1, -2, 3, -4), pack_lanes(-5, 6, -7, 8));
        send_directed(32'h0000_0000, pack_lanes(1, 1, 1, 1), pack_lanes(10, -10, 20, -20));
        send_directed(32'h0000_0000, pack_lanes(1, 2, 3, 4), pack_lanes(8, 7, 6, 5));
        send_directed(32'h0000_0000, pack_lanes(127, 0, 0, 0), pack_lanes(127, 0, 0, 0));
        send_directed(32'h0000_0000, pack_lanes(-128, 0, 0, 0), pack_lanes(-128, 0, 0, 0));
        send_directed(32'h0000_0000, pack_lanes(-128, 0, 0, 0), pack_lanes(127, 0, 0, 0));
        send_directed(32'h0000_0000, pack_lanes(127, 0, 0, 0), pack_lanes(-128, 0, 0, 0));
        send_directed(32'h0000_0000, pack_lanes(-128, -128, -128, -128), pack_lanes(-128, -128, -128, -128));
        send_directed(32'h0000_0000, pack_lanes(-128, -128, -128, -128), pack_lanes(127, 127, 127, 127));
        send_directed(32'h0000_0064, pack_lanes(1, 2, 3, 4), pack_lanes(5, 6, 7, 8));
        send_directed(32'hffff_ff9c, pack_lanes(1, 2, 3, 4), pack_lanes(5, 6, 7, 8));
        send_directed(32'h0000_0064, pack_lanes(1, -2, 3, -4), pack_lanes(-5, 6, -7, 8));
        send_directed(32'hffff_ff9c, pack_lanes(-1, -2, -3, -4), pack_lanes(-5, -6, -7, -8));
        send_directed(32'h7fff_ffff, pack_lanes(1, 0, 0, 0), pack_lanes(1, 0, 0, 0));
        send_directed(32'h8000_0000, pack_lanes(-1, 0, 0, 0), pack_lanes(1, 0, 0, 0));
        drain_pipeline();
        mark_group("directed arithmetic, ranges, wrapping, and scalar equivalence", failures_before);

        $display("---- DOT4ACC latency, II=1, traffic, and bubbles ----");
        reset_pipeline();
        failures_before = tests_failed;
        send_transaction(32'd7, pack_lanes(1, 2, 3, 4), pack_lanes(4, 3, 2, 1));
        advance_bubble();
        record_check("isolated input not complete after stage 2", output_valid === 1'b0);
        advance_bubble();
        record_check("isolated input completes on stage 3", output_valid === 1'b1);
        advance_bubble();
        record_check("isolated completion is not duplicated", output_valid === 1'b0);

        completed_before = completed_count;
        accepted_before = accepted_count;
        for (int index = 0; index < 16; index++) begin
            send_transaction(
                32'h1000_0000 + index,
                32'h0102_0304 + (index * 32'h0101_0101),
                32'hf8f9_fafb - (index * 32'h0101_0101)
            );
        end
        drain_pipeline();
        record_check("16 back-to-back operations accepted", accepted_count - accepted_before == 16);
        record_check("16 back-to-back operations completed", completed_count - completed_before == 16);

        completed_before = completed_count;
        for (int index = 0; index < 64; index++) begin
            send_transaction(index, 32'h1122_3344 ^ index, 32'h81fe_7f02 + index);
        end
        drain_pipeline();
        record_check("continuous II=1 traffic returns one ordered result per advance", completed_count - completed_before == 64);

        send_transaction(32'h0000_0001, 32'h0102_0304, 32'h0506_0708);
        advance_bubble();
        send_transaction(32'h1111_1111, 32'hf8f9_fafb, 32'h0102_0304);
        send_transaction(32'h2222_2222, 32'h7f80_7f80, 32'h807f_807f);
        advance_bubble();
        advance_bubble();
        send_transaction(32'h3333_3333, 32'h1020_3040, 32'hf0e0_d0c0);
        drain_pipeline();
        mark_group("exact three-stage latency, II=1, ordering, and bubbles", failures_before);

        $display("---- DOT4ACC enable freeze ----");
        reset_pipeline();
        failures_before = tests_failed;
        drive_cycle(1'b0, 1'b0, 1'b0, 32'd0, 32'd0, 32'd0);
        send_transaction(32'h0102_0304, 32'h1020_3040, 32'h0102_0304);
        drive_cycle(1'b0, 1'b0, 1'b0, 32'hffff_ffff, 32'hffff_ffff, 32'hffff_ffff);
        repeat (4) begin
            drive_cycle(1'b0, 1'b0, 1'b1, 32'hbad0_0000, 32'h8080_8080, 32'h7f7f_7f7f);
        end
        drive_cycle(1'b0, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
        drive_cycle(1'b0, 1'b0, 1'b0, 32'd0, 32'd0, 32'd0);
        drive_cycle(1'b0, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
        record_check("disabled input_valid transactions were not accepted", queue_head == queue_tail);

        send_transaction(32'h0000_0010, 32'h0102_0304, 32'h0506_0708);
        send_transaction(32'h0000_0020, 32'h1112_1314, 32'h1516_1718);
        send_transaction(32'h0000_0030, 32'h8182_8384, 32'h7f7e_7d7c);
        drive_cycle(1'b0, 1'b0, 1'b1, 32'hffff_0001, 32'h1111_1111, 32'h2222_2222);
        repeat (3) begin
            drive_cycle(1'b0, 1'b0, 1'b0, 32'd0, 32'd0, 32'd0);
        end
        drain_pipeline();
        record_check("freeze/resume returns all accepted operations once", queue_head == queue_tail);
        mark_group("empty, partial, full, repeated, and payload-stable enable freezes", failures_before);

        $display("---- DOT4ACC reset flush ----");
        reset_pipeline();
        failures_before = tests_failed;
        drive_cycle(1'b1, 1'b0, 1'b1, 32'hffff_ffff, 32'hffff_ffff, 32'hffff_ffff);
        send_transaction(32'h1000_0000, 32'h0102_0304, 32'h0506_0708);
        drive_cycle(1'b1, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
        repeat (4) advance_bubble();
        record_check("reset after one input discards it", queue_head == queue_tail);

        send_transaction(32'h2000_0000, 32'h1112_1314, 32'h1516_1718);
        send_transaction(32'h3000_0000, 32'h2122_2324, 32'h2526_2728);
        drive_cycle(1'b1, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
        repeat (4) advance_bubble();
        record_check("reset with multiple in flight discards all", queue_head == queue_tail);

        send_transaction(32'h4000_0000, 32'h3132_3334, 32'h3536_3738);
        advance_bubble();
        drive_cycle(1'b1, 1'b1, 1'b0, 32'd0, 32'd0, 32'd0);
        repeat (4) advance_bubble();
        record_check("reset before completion suppresses stale output", output_valid === 1'b0);
        send_transaction(32'h5000_0000, 32'h4142_4344, 32'h4546_4748);
        drain_pipeline();
        record_check("normal operation resumes after reset", queue_head == queue_tail);
        mark_group("reset empty/in-flight/pre-completion flush and recovery", failures_before);

        $display("---- DOT4ACC deterministic stress ----");
        reset_pipeline();
        failures_before = tests_failed;
        lcg_state = 32'h4acc_a202;
        for (int cycle_index = 0; cycle_index < 700; cycle_index++) begin
            lcg_state = (lcg_state * 32'd1664525) + 32'd1013904223;
            stress_accumulator = lcg_state;
            lcg_state = (lcg_state * 32'd1664525) + 32'd1013904223;
            stress_a = lcg_state;
            lcg_state = (lcg_state * 32'd1664525) + 32'd1013904223;
            stress_b = lcg_state;
            stress_enable = (lcg_state[3:0] != 4'h0) && (lcg_state[7:4] != 4'h0);
            stress_valid = lcg_state[8] ^ lcg_state[13] ^ lcg_state[21];
            stress_reset = (cycle_index == 137) || (cycle_index == 389) || (cycle_index == 611);
            drive_cycle(
                stress_reset,
                stress_enable,
                stress_valid,
                stress_accumulator,
                stress_a,
                stress_b
            );
        end
        drain_pipeline();
        record_check("stress scoreboard empty after drain", queue_head == queue_tail);
        record_check("stress exercised accepted transactions", accepted_count > 300);
        record_check("stress exercised enable freezes", tests_run > 1000);
        record_check("stress exercised reset flushing", flushed_count > 0);
        mark_group("700-cycle deterministic bubbles/freezes/resets stress", failures_before);

        $display("");
        $display("Tests run:             %0d", tests_run);
        $display("Tests failed:          %0d", tests_failed);
        $display("Transactions accepted: %0d", accepted_count);
        $display("Transactions completed:%0d", completed_count);
        $display("Transactions flushed:  %0d", flushed_count);
        if (tests_failed == 0) begin
            $display("DOT4ACC PIPELINE TEST PASSED");
        end else begin
            $display("DOT4ACC PIPELINE TEST FAILED");
            $fatal(1, "DOT4ACC pipeline test failed");
        end
        $finish;
    end

endmodule
