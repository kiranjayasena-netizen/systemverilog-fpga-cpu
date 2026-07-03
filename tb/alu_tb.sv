`timescale 1ns / 1ps

module alu_tb;

    localparam int WIDTH = 32;

    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [2:0] op;
    logic [WIDTH-1:0] y;
    int unsigned tests_run;
    int unsigned tests_failed;

    // Device Under Test
    alu #(
        .WIDTH(WIDTH)
    ) dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y)
    );

    function automatic logic [WIDTH-1:0] alu_ref(
        input logic [WIDTH-1:0] ref_a,
        input logic [WIDTH-1:0] ref_b,
        input logic [2:0] ref_op
    );
        case (ref_op)
            3'b000: alu_ref = ref_a + ref_b;
            3'b001: alu_ref = ref_a - ref_b;
            3'b010: alu_ref = ref_a & ref_b;
            3'b011: alu_ref = ref_a | ref_b;
            3'b100: alu_ref = ref_a ^ ref_b;
            default: alu_ref = '0;
        endcase
    endfunction

    task automatic check_case(
        input string case_name,
        input logic [WIDTH-1:0] test_a,
        input logic [WIDTH-1:0] test_b,
        input logic [2:0] test_op
    );
        logic [WIDTH-1:0] expected;
        begin
            a  = test_a;
            b  = test_b;
            op = test_op;
            #1;

            expected = alu_ref(test_a, test_b, test_op);
            tests_run++;

            if (y !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s a=0x%08h b=0x%08h op=0b%03b expected=0x%08h got=0x%08h",
                    case_name,
                    test_a,
                    test_b,
                    test_op,
                    expected,
                    y
                );
            end else begin
                $display(
                    "PASS: %s a=0x%08h b=0x%08h op=0b%03b y=0x%08h",
                    case_name,
                    test_a,
                    test_b,
                    test_op,
                    y
                );
            end
        end
    endtask

    initial begin
        // Generate VCD waveform file.
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        $display("Starting ALU simulation...");
        tests_run    = 0;
        tests_failed = 0;

        // ADD edge cases, including truncating wraparound behavior.
        check_case("ADD zero", 32'h0000_0000, 32'h0000_0000, 3'b000);
        check_case("ADD basic", 32'h0000_0005, 32'h0000_0007, 3'b000);
        check_case("ADD 32-bit wraparound", 32'hffff_ffff, 32'h0000_0001, 3'b000);
        check_case("ADD max plus max", 32'hffff_ffff, 32'hffff_ffff, 3'b000);
        check_case("ADD sign-bit operands", 32'h8000_0000, 32'h8000_0000, 3'b000);
        check_case("ADD alternating bits", 32'haaaa_aaaa, 32'h5555_5555, 3'b000);

        // SUB edge cases, including underflow wraparound behavior.
        check_case("SUB zero", 32'h0000_0000, 32'h0000_0000, 3'b001);
        check_case("SUB basic", 32'h0000_000a, 32'h0000_0003, 3'b001);
        check_case("SUB underflow", 32'h0000_0000, 32'h0000_0001, 3'b001);
        check_case("SUB max minus one", 32'hffff_ffff, 32'h0000_0001, 3'b001);
        check_case("SUB equal operands", 32'h8000_0000, 32'h8000_0000, 3'b001);
        check_case("SUB large underflow", 32'h7fff_ffff, 32'hffff_ffff, 3'b001);

        // AND directed bit-pattern tests.
        check_case("AND zero masks", 32'h0000_0000, 32'hffff_ffff, 3'b010);
        check_case("AND all ones", 32'hffff_ffff, 32'hffff_ffff, 3'b010);
        check_case("AND alternating bits", 32'haaaa_aaaa, 32'hcccc_cccc, 3'b010);
        check_case("AND disjoint nibbles", 32'hffff_0000, 32'h0000_ffff, 3'b010);

        // OR directed bit-pattern tests.
        check_case("OR zero", 32'h0000_0000, 32'h0000_0000, 3'b011);
        check_case("OR all ones", 32'hffff_ffff, 32'h0000_0000, 3'b011);
        check_case("OR alternating bits", 32'haaaa_aaaa, 32'hcccc_cccc, 3'b011);
        check_case("OR disjoint nibbles", 32'hffff_0000, 32'h0000_ffff, 3'b011);

        // XOR directed bit-pattern tests.
        check_case("XOR zero", 32'h0000_0000, 32'h0000_0000, 3'b100);
        check_case("XOR same operands", 32'hffff_ffff, 32'hffff_ffff, 3'b100);
        check_case("XOR alternating bits", 32'haaaa_aaaa, 32'hcccc_cccc, 3'b100);
        check_case("XOR inverse patterns", 32'haaaa_aaaa, 32'h5555_5555, 3'b100);

        // Invalid opcodes must use the default result.
        check_case("INVALID op 101", 32'h0000_0000, 32'hffff_ffff, 3'b101);
        check_case("INVALID op 110", 32'h5555_5555, 32'haaaa_aaaa, 3'b110);
        check_case("INVALID op 111", 32'hffff_ffff, 32'h0000_000f, 3'b111);

        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed != 0) begin
            $display("ALU TEST FAILED");
            $fatal(1, "%0d of %0d ALU tests failed.", tests_failed, tests_run);
        end

        $display("ALU TEST PASSED");
        $finish;
    end

endmodule
