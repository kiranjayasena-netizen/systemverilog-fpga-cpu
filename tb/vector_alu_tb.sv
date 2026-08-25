`timescale 1ns / 1ps

module vector_alu_tb;

    localparam logic [3:0] VADD   = 4'h0;
    localparam logic [3:0] VSUB   = 4'h1;
    localparam logic [3:0] VAND   = 4'h2;
    localparam logic [3:0] VOR    = 4'h3;
    localparam logic [3:0] VXOR   = 4'h4;
    localparam logic [3:0] VCMPEQ = 4'h5;
    localparam logic [3:0] VCMPLT = 4'h6;
    localparam logic [3:0] VSLL   = 4'h7;
    localparam logic [3:0] VSRL   = 4'h8;
    localparam logic [3:0] VSRA   = 4'h9;

    logic [127:0] vector_a;
    logic [127:0] vector_b;
    logic [3:0]   alu_op;
    logic [127:0] vector_result;
    int unsigned tests_run;
    int unsigned tests_failed;

    vector_alu dut (.*);

    function automatic logic [127:0] pack4(
        input logic [31:0] lane0,
        input logic [31:0] lane1,
        input logic [31:0] lane2,
        input logic [31:0] lane3
    );
        pack4 = {lane3, lane2, lane1, lane0};
    endfunction

    function automatic logic [127:0] vector_ref(
        input logic [127:0] ref_a,
        input logic [127:0] ref_b,
        input logic [3:0] ref_op
    );
        logic [31:0] a_lane;
        logic [31:0] b_lane;
        logic signed [31:0] signed_a;
        logic signed [31:0] signed_b;
        begin
            vector_ref = 128'h0;
            for (int lane = 0; lane < 4; lane++) begin
                a_lane = ref_a[lane*32 +: 32];
                b_lane = ref_b[lane*32 +: 32];
                signed_a = $signed(a_lane);
                signed_b = $signed(b_lane);
                case (ref_op)
                    VADD: vector_ref[lane*32 +: 32] = a_lane + b_lane;
                    VSUB: vector_ref[lane*32 +: 32] = a_lane - b_lane;
                    VAND: vector_ref[lane*32 +: 32] = a_lane & b_lane;
                    VOR: vector_ref[lane*32 +: 32] = a_lane | b_lane;
                    VXOR: vector_ref[lane*32 +: 32] = a_lane ^ b_lane;
                    VCMPEQ: vector_ref[lane*32 +: 32] =
                        (a_lane == b_lane) ? 32'h1 : 32'h0;
                    VCMPLT: vector_ref[lane*32 +: 32] =
                        (signed_a < signed_b) ? 32'h1 : 32'h0;
                    VSLL: vector_ref[lane*32 +: 32] = a_lane << b_lane[4:0];
                    VSRL: vector_ref[lane*32 +: 32] = a_lane >> b_lane[4:0];
                    VSRA: vector_ref[lane*32 +: 32] =
                        signed_a >>> b_lane[4:0];
                    default: vector_ref[lane*32 +: 32] = 32'h0;
                endcase
            end
        end
    endfunction

    task automatic check_case(
        input string case_name,
        input logic [127:0] test_a,
        input logic [127:0] test_b,
        input logic [3:0] test_op
    );
        logic [127:0] expected;
        begin
            vector_a = test_a;
            vector_b = test_b;
            alu_op = test_op;
            #1;
            expected = vector_ref(test_a, test_b, test_op);
            tests_run++;
            if (vector_result !== expected) begin
                tests_failed++;
                $error("FAIL: %s op=%h expected=%h got=%h",
                       case_name, test_op, expected, vector_result);
            end else begin
                $display("PASS: %s result=%h", case_name, vector_result);
            end
        end
    endtask

    initial begin
        $dumpfile("vector_alu_tb.vcd");
        $dumpvars(0, vector_alu_tb);
        tests_run = 0;
        tests_failed = 0;

        check_case("VADD normal lane independence",
            pack4(1, 2, 3, 4), pack4(10, 20, 30, 40), VADD);
        check_case("VADD zero",
            pack4(0, 0, 0, 0), pack4(0, 0, 0, 0), VADD);
        check_case("VADD unsigned wraparound",
            pack4(32'hffff_ffff, 32'h7fff_ffff, 32'h0, 32'h8000_0000),
            pack4(1, 1, 32'hffff_ffff, 32'h8000_0000), VADD);

        check_case("VSUB normal lane independence",
            pack4(10, 20, 30, 40), pack4(1, 2, 3, 4), VSUB);
        check_case("VSUB equal operands",
            pack4(7, 8, 9, 10), pack4(7, 8, 9, 10), VSUB);
        check_case("VSUB underflow wraparound",
            pack4(0, 32'h8000_0000, 1, 32'hffff_ffff),
            pack4(1, 1, 2, 2), VSUB);

        check_case("VAND patterns",
            pack4(32'hf0f0_f0f0, 32'hffff_0000, 32'haaaa_aaaa, 32'h1234_5678),
            pack4(32'h0ff0_0ff0, 32'h00ff_00ff, 32'h5555_5555, 32'h8765_4321), VAND);
        check_case("VOR patterns",
            pack4(32'hf0f0_f0f0, 32'hffff_0000, 32'haaaa_aaaa, 32'h1234_5678),
            pack4(32'h0ff0_0ff0, 32'h00ff_00ff, 32'h5555_5555, 32'h8765_4321), VOR);
        check_case("VXOR patterns",
            pack4(32'hf0f0_f0f0, 32'hffff_0000, 32'haaaa_aaaa, 32'h1234_5678),
            pack4(32'h0ff0_0ff0, 32'h00ff_00ff, 32'h5555_5555, 32'h8765_4321), VXOR);

        check_case("VCMPEQ mixed lanes",
            pack4(5, 1, 32'hffff_ffff, 7), pack4(5, 2, 32'hffff_ffff, 8), VCMPEQ);
        check_case("VCMPLT signed mixed lanes",
            pack4(1, 5, 32'hffff_fffe, 32'hffff_fffd),
            pack4(2, 3, 1, 32'hffff_fffc), VCMPLT);
        check_case("VCMPLT equal and negative cases",
            pack4(32'h8000_0000, 32'h8000_0000, 32'hffff_ffff, 7),
            pack4(32'h7fff_ffff, 32'h8000_0000, 0, 7), VCMPLT);

        check_case("VSLL shift zero and one",
            pack4(1, 2, 32'h8000_0000, 32'h0000_0003),
            pack4(0, 1, 32'hffff_ffe1, 32'h0000_0001), VSLL);
        check_case("VSLL shift by 31",
            pack4(1, 32'h8000_0000, 3, 4),
            pack4(31, 31, 31, 31), VSLL);
        check_case("VSRL logical sign-bit clear",
            pack4(32'h8000_0000, 32'hffff_ffff, 32'h4000_0000, 8),
            pack4(1, 1, 2, 3), VSRL);
        check_case("VSRL high shift bits ignored",
            pack4(32'h8000_0000, 16, 32'hffff_ffff, 32'h1234_5678),
            pack4(32'hffff_ffe1, 32'hffff_ffe0, 32'hffff_ffff, 32'hffff_ffe2), VSRL);
        check_case("VSRA positive and negative",
            pack4(32'h8000_0000, 32'hffff_ffff, 32'h7fff_ffff, 32'h4000_0000),
            pack4(1, 1, 1, 1), VSRA);
        check_case("VSRA shift by 31",
            pack4(32'h8000_0000, 32'hffff_ffff, 32'h7fff_ffff, 0),
            pack4(31, 31, 31, 31), VSRA);

        check_case("lane order preserved with VOR zero",
            pack4(32'h1111_1111, 32'h2222_2222, 32'h3333_3333, 32'h4444_4444),
            128'h0, VOR);
        check_case("invalid operation defaults to zero",
            128'hffff_ffff_0000_0000_aaaa_aaaa_5555_5555,
            128'h1234_5678_9abc_def0_0fed_cba9_8765_4321, 4'hf);

        $display("Tests run: %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        if (tests_failed != 0) begin
            $display("VECTOR ALU TEST FAILED");
            $fatal(1, "%0d of %0d vector ALU tests failed", tests_failed, tests_run);
        end
        $display("VECTOR ALU TEST PASSED");
        $finish;
    end

endmodule
