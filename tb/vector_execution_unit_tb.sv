`timescale 1ns / 1ps

module vector_execution_unit_tb;

    localparam logic [3:0] VADD   = 4'h0;
    localparam logic [3:0] VSUB   = 4'h1;
    localparam logic [3:0] VXOR   = 4'h4;
    localparam logic [3:0] VOR    = 4'h3;
    localparam logic [3:0] VCMPLT = 4'h6;
    localparam logic [3:0] VSRA   = 4'h9;

    logic clk = 1'b0;
    logic rst = 1'b0;
    logic [2:0] src_a = '0;
    logic [2:0] src_b = '0;
    logic [2:0] dst = '0;
    logic [3:0] alu_op = VADD;
    logic execute_enable = 1'b0;
    logic load_enable = 1'b0;
    logic [2:0] load_addr = '0;
    logic [127:0] load_data = '0;
    logic debug_read_enable = 1'b0;
    logic [2:0] debug_read_addr = '0;
    logic [127:0] debug_read_data;
    logic [127:0] alu_result;
    int unsigned tests_run;
    int unsigned tests_failed;

    vector_execution_unit dut (.*);

    always #5 clk = ~clk;

    function automatic logic [127:0] pack4(
        input logic [31:0] lane0,
        input logic [31:0] lane1,
        input logic [31:0] lane2,
        input logic [31:0] lane3
    );
        pack4 = {lane3, lane2, lane1, lane0};
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
                $error("FAIL: %s address=%0d expected=%h got=%h",
                       description, address, expected, debug_read_data);
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
            execute_enable = 1'b0;
            @(posedge clk);
            #1;
            load_enable = 1'b0;
            $display("PASS: %s", description);
        end
    endtask

    task automatic execute_vector(
        input logic [2:0] source_a,
        input logic [2:0] source_b,
        input logic [2:0] destination,
        input logic [3:0] operation,
        input logic [127:0] expected_result,
        input string description
    );
        begin
            @(negedge clk);
            src_a = source_a;
            src_b = source_b;
            dst = destination;
            alu_op = operation;
            execute_enable = 1'b1;
            load_enable = 1'b0;
            #1;
            if (alu_result !== expected_result) begin
                tests_failed++;
                $error("FAIL: %s combinational result expected=%h got=%h",
                       description, expected_result, alu_result);
            end
            @(posedge clk);
            #1;
            execute_enable = 1'b0;
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
            execute_enable = 1'b1;
            load_addr = 3'd7;
            load_data = {4{32'hffff_ffff}};
            @(posedge clk);
            #1;
            rst = 1'b0;
            load_enable = 1'b0;
            execute_enable = 1'b0;
            check_debug(0, 128'h0, {description, " register 0"});
            check_debug(7, 128'h0, {description, " register 7"});
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
        v6 = pack4(32'h1, 32'h1, 32'h1, 32'h1);
        lane_data = pack4(32'h1111_1111, 32'h2222_2222,
                          32'h3333_3333, 32'h4444_4444);

        reset_unit("reset priority");

        load_vector(1, v1, "external load V1");
        load_vector(2, v2, "external load V2");
        check_debug(1, v1, "debug read V1");
        check_debug(2, v2, "debug read V2");

        execute_vector(1, 2, 3, VADD, v3, "basic VADD V3,V1,V2");
        check_debug(1, v1, "VADD preserves V1");
        check_debug(2, v2, "VADD preserves V2");

        execute_vector(3, 1, 4, VSUB, v4, "VSUB V4,V3,V1");
        execute_vector(3, 4, 5, VXOR, v5, "VXOR V5,V3,V4");
        execute_vector(1, 2, 6, VCMPLT, v6, "VCMPLT V6,V1,V2");

        // Destination equal to source A: old V1 must feed the ALU before the
        // rising edge writes the new V1.
        load_vector(1, v1, "reload V1 for source-A alias test");
        load_vector(2, pack4(10, 20, 30, 40),
                    "load V2 for source-A alias test");
        execute_vector(1, 2, 1, VADD, pack4(11, 22, 33, 44),
                       "VADD V1,V1,V2");
        check_debug(1, pack4(11, 22, 33, 44), "source-A alias writeback");

        // Destination equal to source B.
        load_vector(1, v1, "reload V1 for source-B alias test");
        load_vector(2, pack4(10, 20, 30, 40),
                    "reload V2 for source-B alias test");
        execute_vector(1, 2, 2, VSUB,
                       pack4(32'hffff_fff7, 32'hffff_ffee,
                              32'hffff_ffe5, 32'hffff_ffdc),
                       "VSUB V2,V1,V2");
        check_debug(2, pack4(32'hffff_fff7, 32'hffff_ffee,
                             32'hffff_ffe5, 32'hffff_ffdc),
                    "source-B alias writeback");

        // Execute disabled must not change a destination.
        load_vector(7, lane_data, "load protected destination");
        @(negedge clk);
        src_a = 1;
        src_b = 2;
        dst = 7;
        alu_op = VADD;
        execute_enable = 1'b0;
        @(posedge clk);
        #1;
        check_debug(7, lane_data, "execute disabled holds destination");

        // Load has priority over execute on the same edge.
        @(negedge clk);
        src_a = 1;
        src_b = 2;
        dst = 5;
        alu_op = VADD;
        execute_enable = 1'b1;
        load_enable = 1'b1;
        load_addr = 5;
        load_data = lane_data;
        @(posedge clk);
        #1;
        execute_enable = 1'b0;
        load_enable = 1'b0;
        check_debug(5, lane_data, "load priority over execute");

        execute_vector(1, 2, 6, 4'hf, 128'h0,
                       "invalid ALU operation writes zero");

        load_vector(1, pack4(32'h8000_0000, 32'hffff_ffff,
                             32'h7fff_ffff, 32'h0000_0001),
                    "load signed comparison operands A");
        load_vector(2, pack4(32'h7fff_ffff, 32'hffff_ffff,
                             32'h8000_0000, 32'h0000_0002),
                    "load signed comparison operands B");
        execute_vector(1, 2, 6, VCMPLT,
                       pack4(32'h1, 32'h0, 32'h0, 32'h1),
                       "integrated signed VCMPLT");

        load_vector(1, pack4(32'h8000_0000, 32'hffff_ffff,
                             32'h7fff_ffff, 32'h4000_0000),
                    "load arithmetic shift operands");
        load_vector(2, pack4(1, 1, 1, 1), "load arithmetic shift amounts");
        execute_vector(1, 2, 6, VSRA,
                       pack4(32'hc000_0000, 32'hffff_ffff,
                             32'h3fff_ffff, 32'h2000_0000),
                       "integrated signed VSRA");

        load_vector(1, lane_data, "load lane-order pattern");
        check_debug(1, 128'h4444_4444_3333_3333_2222_2222_1111_1111,
                    "lane-order debug read");
        execute_vector(1, 0, 3, VOR, lane_data,
                       "lane-order preserving operation");
        check_debug(3, lane_data, "lane-order result readback");

        $display("Tests run: %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        if (tests_failed != 0) begin
            $display("VECTOR EXECUTION UNIT TEST FAILED");
            $fatal(1, "%0d vector execution unit checks failed", tests_failed);
        end
        $display("VECTOR EXECUTION UNIT TEST PASSED");
        $finish;
    end

endmodule
