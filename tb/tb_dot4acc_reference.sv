import cpu_defs_pkg::*;
import dot4acc_reference_pkg::*;

module tb_dot4acc_reference;

    int tests_run;
    int tests_failed;

    function automatic logic [31:0] pack_lanes(
        input int signed lane0,
        input int signed lane1,
        input int signed lane2,
        input int signed lane3
    );
        pack_lanes = {lane3[7:0], lane2[7:0], lane1[7:0], lane0[7:0]};
    endfunction

    // Structurally independent comparison model. It extracts one byte at a
    // time as an unsigned integer, converts values 128..255 to signed INT8,
    // and accumulates products sequentially in 64 bits. This intentionally
    // does not reproduce the canonical balanced-tree expression.
    function automatic logic [31:0] dot4acc_sequential_model(
        input logic [31:0] rd_value,
        input logic [31:0] rs1_value,
        input logic [31:0] rs2_value
    );
        logic signed [63:0] running_sum;
        int unsigned lane_a_bits;
        int unsigned lane_b_bits;
        int signed lane_a_value;
        int signed lane_b_value;
        int signed lane_product;

        running_sum = $signed({{32{rd_value[31]}}, rd_value});
        for (int lane = 0; lane < 4; lane++) begin
            lane_a_bits = (rs1_value >> (lane * 8)) & 32'h0000_00ff;
            lane_b_bits = (rs2_value >> (lane * 8)) & 32'h0000_00ff;
            lane_a_value = (lane_a_bits >= 128) ? int'(lane_a_bits) - 256 : int'(lane_a_bits);
            lane_b_value = (lane_b_bits >= 128) ? int'(lane_b_bits) - 256 : int'(lane_b_bits);
            lane_product = lane_a_value * lane_b_value;
            running_sum = running_sum + lane_product;
        end
        dot4acc_sequential_model = running_sum[31:0];
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

    task automatic check_equal32(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        tests_run++;
        if (actual === expected) begin
            $display("PASS: %s | value=0x%08h", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s | actual=0x%08h expected=0x%08h", name, actual, expected);
        end
    endtask

    task automatic check_case(
        input string name,
        input logic [31:0] accumulator,
        input logic [31:0] packed_a,
        input logic [31:0] packed_b,
        input logic [31:0] expected
    );
        logic [31:0] canonical;
        logic [31:0] sequential;

        canonical = dot4acc_reference(accumulator, packed_a, packed_b);
        sequential = dot4acc_sequential_model(accumulator, packed_a, packed_b);
        check_equal32({name, " canonical"}, canonical, expected);
        check_equal32({name, " sequential equivalence"}, sequential, expected);
    endtask

    initial begin
        logic [31:0] encoded;
        logic [31:0] lcg_state;
        logic [31:0] random_accumulator;
        logic [31:0] random_rs1;
        logic [31:0] random_rs2;

        tests_run = 0;
        tests_failed = 0;

        $display("---- DOT4ACC reserved encoding ----");
        encoded = encode_dot4acc(5'd3, 5'd4, 5'd5);
        check_equal32("exact canonical instruction", encoded, 32'hc190_a000);
        check_true("OP_DOT4ACC reserves opcode 0xc", OP_DOT4ACC == 4'hc);
        check_true("encoder opcode field", encoded[31:28] == 4'hc);
        check_true("encoder rd field", encoded[27:23] == 5'd3);
        check_true("encoder rs1 field", encoded[22:18] == 5'd4);
        check_true("encoder rs2 field", encoded[17:13] == 5'd5);
        check_true("encoder reserved immediate is zero", encoded[12:0] == 13'd0);
        check_true("canonical encoding accepted by reference check", dot4acc_encoding_is_canonical(encoded));
        check_true(
            "nonzero reserved immediate flagged by reference check",
            !dot4acc_encoding_is_canonical(encoded | 32'h0000_0001)
        );
        check_true("shared validity still rejects DOT4ACC", !opcode_is_valid(OP_DOT4ACC));
        check_true("shared write predicate rejects DOT4ACC", !opcode_writes_rd(OP_DOT4ACC));
        check_true("shared rs1 predicate rejects DOT4ACC", !opcode_uses_rs1(OP_DOT4ACC));
        check_true("shared rs2 predicate rejects DOT4ACC", !opcode_uses_rs2(OP_DOT4ACC));
        check_true("opcode 0xd remains invalid", !opcode_is_valid(4'hd));

        $display("---- DOT4ACC directed arithmetic ----");
        check_case("all-zero lanes", 32'h0000_0000, pack_lanes(0, 0, 0, 0), pack_lanes(0, 0, 0, 0), 32'h0000_0000);
        check_case("all-positive lanes", 32'h0000_0000, pack_lanes(1, 2, 3, 4), pack_lanes(5, 6, 7, 8), 32'd70);
        check_case("all-negative inputs give positive products", 32'h0000_0000, pack_lanes(-1, -2, -3, -4), pack_lanes(-5, -6, -7, -8), 32'd70);
        check_case("mixed-sign products", 32'h0000_0000, pack_lanes(1, -2, 3, -4), pack_lanes(-5, 6, -7, 8), 32'hffff_ffba);
        check_case("lane cancellation", 32'h0000_0000, pack_lanes(1, 1, 1, 1), pack_lanes(10, -10, 20, -20), 32'h0000_0000);
        check_case("+127 times +127", 32'h0000_0000, pack_lanes(127, 0, 0, 0), pack_lanes(127, 0, 0, 0), 32'd16129);
        check_case("-128 times -128", 32'h0000_0000, pack_lanes(-128, 0, 0, 0), pack_lanes(-128, 0, 0, 0), 32'd16384);
        check_case("-128 times +127", 32'h0000_0000, pack_lanes(-128, 0, 0, 0), pack_lanes(127, 0, 0, 0), 32'hffff_c080);
        check_case("+127 times -128", 32'h0000_0000, pack_lanes(127, 0, 0, 0), pack_lanes(-128, 0, 0, 0), 32'hffff_c080);
        check_case("maximum positive four-lane sum", 32'h0000_0000, pack_lanes(-128, -128, -128, -128), pack_lanes(-128, -128, -128, -128), 32'h0001_0000);
        check_case("minimum negative four-lane sum", 32'h0000_0000, pack_lanes(-128, -128, -128, -128), pack_lanes(127, 127, 127, 127), 32'hffff_0200);
        check_case("nonzero initial accumulator", 32'd100, pack_lanes(1, 2, 3, 4), pack_lanes(5, 6, 7, 8), 32'd170);
        check_case("positive accumulator plus negative dot", 32'd100, pack_lanes(1, -2, 3, -4), pack_lanes(-5, 6, -7, 8), 32'd30);
        check_case("negative accumulator plus positive dot", 32'hffff_ff9c, pack_lanes(1, 2, 3, 4), pack_lanes(5, 6, 7, 8), 32'hffff_ffe2);
        check_case("positive 32-bit wraparound", 32'h7fff_ffff, pack_lanes(1, 0, 0, 0), pack_lanes(1, 0, 0, 0), 32'h8000_0000);
        check_case("negative 32-bit wraparound", 32'h8000_0000, pack_lanes(-1, 0, 0, 0), pack_lanes(1, 0, 0, 0), 32'h7fff_ffff);
        check_case("distinct lane order", 32'h0000_0000, pack_lanes(1, 2, 3, 4), pack_lanes(8, 7, 6, 5), 32'd60);
        check_equal32("declared maximum dot range", DOT4ACC_MAX_DOT, 32'h0001_0000);
        check_equal32("declared minimum dot range", {{14{DOT4ACC_MIN_DOT[17]}}, DOT4ACC_MIN_DOT}, 32'hffff_0200);

        $display("---- DOT4ACC deterministic model cross-check ----");
        lcg_state = 32'h4acc_2026;
        for (int vector_index = 0; vector_index < 256; vector_index++) begin
            lcg_state = (lcg_state * 32'd1664525) + 32'd1013904223;
            random_accumulator = lcg_state;
            lcg_state = (lcg_state * 32'd1664525) + 32'd1013904223;
            random_rs1 = lcg_state;
            lcg_state = (lcg_state * 32'd1664525) + 32'd1013904223;
            random_rs2 = lcg_state;
            check_equal32(
                $sformatf("deterministic vector %0d", vector_index),
                dot4acc_reference(random_accumulator, random_rs1, random_rs2),
                dot4acc_sequential_model(random_accumulator, random_rs1, random_rs2)
            );
        end

        $display("");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        if (tests_failed == 0) begin
            $display("DOT4ACC REFERENCE TEST PASSED");
        end else begin
            $display("DOT4ACC REFERENCE TEST FAILED");
            $fatal(1, "DOT4ACC reference test failed");
        end
        $finish;
    end

endmodule
