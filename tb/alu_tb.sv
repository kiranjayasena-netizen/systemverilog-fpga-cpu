`timescale 1ns / 1ps

module alu_tb;

    logic [7:0] a;
    logic [7:0] b;
    logic [2:0] op;
    logic [7:0] y;
    int unsigned tests_run;
    int unsigned tests_failed;

    // Device Under Test
    alu dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y)
    );

    function automatic logic [7:0] alu_ref(
        input logic [7:0] ref_a,
        input logic [7:0] ref_b,
        input logic [2:0] ref_op
    );
        case (ref_op)
            3'b000: alu_ref = ref_a + ref_b;
            3'b001: alu_ref = ref_a - ref_b;
            3'b010: alu_ref = ref_a & ref_b;
            3'b011: alu_ref = ref_a | ref_b;
            3'b100: alu_ref = ref_a ^ ref_b;
            default: alu_ref = 8'h00;
        endcase
    endfunction

    task automatic check_case(
        input string case_name,
        input logic [7:0] test_a,
        input logic [7:0] test_b,
        input logic [2:0] test_op
    );
        logic [7:0] expected;
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
                    "%s failed: a=0x%02h b=0x%02h op=0b%03b expected=0x%02h got=0x%02h",
                    case_name,
                    test_a,
                    test_b,
                    test_op,
                    expected,
                    y
                );
            end
        end
    endtask

    initial begin
        // Generate waveform file for Icarus/GTKWave
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        $display("Starting ALU simulation...");
        tests_run    = 0;
        tests_failed = 0;

        // ADD edge cases, including truncating wraparound behavior.
        check_case("ADD zero", 8'h00, 8'h00, 3'b000);
        check_case("ADD basic", 8'h05, 8'h07, 3'b000);
        check_case("ADD carry wrap", 8'hff, 8'h01, 3'b000);
        check_case("ADD max plus max", 8'hff, 8'hff, 3'b000);
        check_case("ADD sign-bit operands", 8'h80, 8'h80, 3'b000);
        check_case("ADD alternating bits", 8'haa, 8'h55, 3'b000);

        // SUB edge cases, including underflow wraparound behavior.
        check_case("SUB zero", 8'h00, 8'h00, 3'b001);
        check_case("SUB basic", 8'h0a, 8'h03, 3'b001);
        check_case("SUB underflow", 8'h00, 8'h01, 3'b001);
        check_case("SUB max minus one", 8'hff, 8'h01, 3'b001);
        check_case("SUB equal operands", 8'h80, 8'h80, 3'b001);
        check_case("SUB large underflow", 8'h7f, 8'hff, 3'b001);

        // AND directed bit-pattern tests.
        check_case("AND zero masks", 8'h00, 8'hff, 3'b010);
        check_case("AND all ones", 8'hff, 8'hff, 3'b010);
        check_case("AND alternating bits", 8'haa, 8'hcc, 3'b010);
        check_case("AND disjoint nibbles", 8'hf0, 8'h0f, 3'b010);

        // OR directed bit-pattern tests.
        check_case("OR zero", 8'h00, 8'h00, 3'b011);
        check_case("OR all ones", 8'hff, 8'h00, 3'b011);
        check_case("OR alternating bits", 8'haa, 8'hcc, 3'b011);
        check_case("OR disjoint nibbles", 8'hf0, 8'h0f, 3'b011);

        // XOR directed bit-pattern tests.
        check_case("XOR zero", 8'h00, 8'h00, 3'b100);
        check_case("XOR same operands", 8'hff, 8'hff, 3'b100);
        check_case("XOR alternating bits", 8'haa, 8'hcc, 3'b100);
        check_case("XOR inverse patterns", 8'haa, 8'h55, 3'b100);

        // Invalid opcodes must use the default result.
        check_case("INVALID op 101", 8'h00, 8'hff, 3'b101);
        check_case("INVALID op 110", 8'h55, 8'haa, 3'b110);
        check_case("INVALID op 111", 8'hff, 8'h0f, 3'b111);

        if (tests_failed != 0) begin
            $fatal(1, "%0d of %0d ALU tests failed.", tests_failed, tests_run);
        end

        $display("All %0d ALU tests passed.", tests_run);
        $finish;
    end

endmodule
