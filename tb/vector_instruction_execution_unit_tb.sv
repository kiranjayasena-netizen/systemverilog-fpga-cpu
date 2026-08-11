`timescale 1ns / 1ps

module vector_instruction_execution_unit_tb;

    localparam logic [3:0] VADD = 4'h0;
    localparam logic [3:0] VSUB = 4'h1;
    localparam logic [3:0] VOR = 4'h3;
    localparam logic [3:0] VXOR = 4'h4;
    localparam logic [3:0] VCMPLT = 4'h6;
    localparam logic [3:0] VSRA = 4'h9;

    logic clk = 1'b0;
    logic rst = 1'b0;
    logic [15:0] instruction = '0;
    logic instruction_enable = 1'b0;
    logic load_enable = 1'b0;
    logic [2:0] load_addr = '0;
    logic [127:0] load_data = '0;
    logic debug_read_enable = 1'b0;
    logic [2:0] debug_read_addr = '0;
    logic [127:0] debug_read_data;
    logic [3:0] decoded_alu_op;
    logic [2:0] decoded_src_a;
    logic [2:0] decoded_src_b;
    logic [2:0] decoded_dst;
    logic instruction_valid;
    logic decoded_execute_enable;
    logic execute_enable;
    logic [127:0] alu_result;
    int unsigned tests_run;
    int unsigned tests_failed;

    vector_instruction_execution_unit dut (.*);

    always #5 clk = ~clk;

    function automatic logic [127:0] pack4(
        input logic [31:0] lane0,
        input logic [31:0] lane1,
        input logic [31:0] lane2,
        input logic [31:0] lane3
    );
        pack4 = {lane3, lane2, lane1, lane0};
    endfunction

    function automatic logic [15:0] encode_instruction(
        input logic [3:0] opcode,
        input logic [2:0] test_dst,
        input logic [2:0] test_src_a,
        input logic [2:0] test_src_b,
        input logic [2:0] reserved
    );
        encode_instruction = {opcode, test_dst, test_src_a, test_src_b, reserved};
    endfunction

    task automatic check_debug(
        input logic [2:0] address,
        input logic [127:0] expected,
        input string description
    );
        begin
            debug_read_enable = 1'b1;
            debug_read_addr = address;
            #1;
            tests_run++;
            if (debug_read_data !== expected) begin
                tests_failed++;
                $error("FAIL: %s expected=%h got=%h", description,
                       expected, debug_read_data);
            end else begin
                $display("PASS: %s value=%h", description, debug_read_data);
            end
            debug_read_enable = 1'b0;
        end
    endtask

    task automatic load_vector(
        input logic [2:0] address,
        input logic [127:0] value,
        input string description
    );
        begin
            @(negedge clk);
            load_enable = 1'b1;
            load_addr = address;
            load_data = value;
            instruction_enable = 1'b0;
            @(posedge clk);
            #1;
            load_enable = 1'b0;
            $display("PASS: %s", description);
        end
    endtask

    task automatic execute_instruction(
        input logic [15:0] encoded,
        input logic [127:0] expected_result,
        input string description
    );
        begin
            @(negedge clk);
            instruction = encoded;
            instruction_enable = 1'b1;
            #1;
            if (!instruction_valid || !decoded_execute_enable ||
                !execute_enable || alu_result !== expected_result) begin
                tests_failed++;
                $error("FAIL: %s decode/result instruction=%h valid=%b decoded_en=%b en=%b result=%h expected=%h",
                       description, encoded, instruction_valid,
                       decoded_execute_enable, execute_enable,
                       alu_result, expected_result);
            end
            @(posedge clk);
            #1;
            instruction_enable = 1'b0;
            tests_run++;
            if (alu_result === expected_result) begin
                $display("PASS: %s result=%h", description, alu_result);
            end
        end
    endtask

    task automatic reset_unit(input string description);
        begin
            @(negedge clk);
            rst = 1'b1;
            load_enable = 1'b1;
            instruction_enable = 1'b1;
            load_addr = 3'd7;
            load_data = {4{32'hffff_ffff}};
            instruction = encode_instruction(VADD, 7, 0, 0, 0);
            @(posedge clk);
            #1;
            rst = 1'b0;
            load_enable = 1'b0;
            instruction_enable = 1'b0;
            check_debug(0, 128'h0, {description, " V0"});
            check_debug(7, 128'h0, {description, " V7"});
        end
    endtask

    initial begin
        logic [127:0] v1;
        logic [127:0] v2;
        logic [127:0] v3;
        logic [127:0] v4;
        logic [127:0] v5;
        logic [127:0] v6;
        logic [127:0] lane_data;

        tests_run = 0;
        tests_failed = 0;
        v1 = pack4(1, 2, 3, 4);
        v2 = pack4(5, 6, 7, 8);
        v3 = pack4(6, 8, 10, 12);
        v4 = pack4(5, 6, 7, 8);
        v5 = pack4(32'h0000_0003, 32'h0000_000e,
                   32'h0000_000d, 32'h0000_0004);
        v6 = pack4(1, 1, 1, 1);
        lane_data = pack4(32'h1111_1111, 32'h2222_2222,
                          32'h3333_3333, 32'h4444_4444);

        reset_unit("reset priority");
        load_vector(1, v1, "load V1");
        load_vector(2, v2, "load V2");
        check_debug(1, v1, "read V1");
        check_debug(2, v2, "read V2");

        execute_instruction(encode_instruction(VADD, 3, 1, 2, 0),
                            v3, "encoded VADD V3,V1,V2");
        check_debug(1, v1, "encoded VADD preserves V1");
        check_debug(2, v2, "encoded VADD preserves V2");
        execute_instruction(encode_instruction(VSUB, 4, 3, 1, 0),
                            v4, "encoded VSUB V4,V3,V1");
        execute_instruction(encode_instruction(VXOR, 5, 3, 4, 0),
                            v5, "encoded VXOR V5,V3,V4");
        execute_instruction(encode_instruction(VCMPLT, 6, 1, 2, 0),
                            v6, "encoded VCMPLT V6,V1,V2");

        load_vector(1, v1, "reload V1 for dst=src_a");
        load_vector(2, pack4(10, 20, 30, 40), "load V2 for dst=src_a");
        execute_instruction(encode_instruction(VADD, 1, 1, 2, 0),
                            pack4(11, 22, 33, 44), "encoded VADD V1,V1,V2");
        check_debug(1, pack4(11, 22, 33, 44), "encoded dst=src_a readback");

        load_vector(1, v1, "reload V1 for dst=src_b");
        load_vector(2, pack4(10, 20, 30, 40), "reload V2 for dst=src_b");
        execute_instruction(encode_instruction(VSUB, 2, 1, 2, 0),
                            pack4(32'hffff_fff7, 32'hffff_ffee,
                                  32'hffff_ffe5, 32'hffff_ffdc),
                            "encoded VSUB V2,V1,V2");
        check_debug(2, pack4(32'hffff_fff7, 32'hffff_ffee,
                             32'hffff_ffe5, 32'hffff_ffdc),
                    "encoded dst=src_b readback");

        // Valid instruction presented while instruction_enable is low.
        load_vector(7, lane_data, "load disabled-execution destination");
        @(negedge clk);
        instruction = encode_instruction(VADD, 7, 1, 2, 0);
        instruction_enable = 1'b0;
        @(posedge clk);
        #1;
        check_debug(7, lane_data, "instruction_enable disabled holds state");

        // Invalid instruction must suppress Stage 3 execution entirely.
        instruction = encode_instruction(4'ha, 7, 1, 2, 0);
        instruction_enable = 1'b1;
        #1;
        tests_run++;
        if (instruction_valid || execute_enable) begin
            tests_failed++;
            $error("FAIL: invalid opcode was enabled");
        end else begin
            $display("PASS: invalid opcode decode suppression");
        end
        @(posedge clk);
        #1;
        instruction_enable = 1'b0;
        check_debug(7, lane_data, "invalid opcode preserves state");

        // Reserved bits do not change instruction meaning.
        load_vector(1, v1, "reload V1 for reserved-bit test");
        load_vector(2, v2, "reload V2 for reserved-bit test");
        execute_instruction(encode_instruction(VADD, 3, 1, 2, 3'b000),
                            v3, "reserved bits zero");
        execute_instruction(encode_instruction(VADD, 4, 1, 2, 3'b111),
                            v3, "reserved bits nonzero ignored");

        load_vector(1, pack4(32'h8000_0000, 32'hffff_ffff,
                             32'h7fff_ffff, 32'h1), "load compare A");
        load_vector(2, pack4(32'h7fff_ffff, 32'hffff_ffff,
                             32'h8000_0000, 32'h2), "load compare B");
        execute_instruction(encode_instruction(VCMPLT, 6, 1, 2, 0),
                            pack4(1, 0, 0, 1), "encoded signed VCMPLT");

        load_vector(1, pack4(32'h8000_0000, 32'hffff_ffff,
                             32'h7fff_ffff, 32'h4000_0000), "load shift A");
        load_vector(2, pack4(1, 1, 1, 1), "load shift B");
        execute_instruction(encode_instruction(VSRA, 6, 1, 2, 0),
                            pack4(32'hc000_0000, 32'hffff_ffff,
                                  32'h3fff_ffff, 32'h2000_0000),
                            "encoded signed VSRA");

        // Load must win over a simultaneous valid execution.
        @(negedge clk);
        instruction = encode_instruction(VOR, 5, 1, 2, 0);
        instruction_enable = 1'b1;
        load_enable = 1'b1;
        load_addr = 5;
        load_data = lane_data;
        @(posedge clk);
        #1;
        instruction_enable = 1'b0;
        load_enable = 1'b0;
        check_debug(5, lane_data, "load priority over encoded execution");

        // Final reset after activity.
        reset_unit("final reset");

        $display("Tests run: %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        if (tests_failed != 0) begin
            $display("VECTOR INSTRUCTION EXECUTION UNIT TEST FAILED");
            $fatal(1, "%0d Stage 4 integration checks failed", tests_failed);
        end
        $display("VECTOR INSTRUCTION EXECUTION UNIT TEST PASSED");
        $finish;
    end

endmodule
