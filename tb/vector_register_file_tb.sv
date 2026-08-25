module vector_register_file_tb;

    localparam int LANES = 4;
    localparam int ELEMENT_WIDTH = 32;
    localparam int REG_COUNT = 8;
    localparam int ADDR_WIDTH = $clog2(REG_COUNT);
    localparam int VECTOR_WIDTH = LANES * ELEMENT_WIDTH;

    logic clk = 1'b0;
    logic rst = 1'b0;
    logic we = 1'b0;
    logic [ADDR_WIDTH-1:0] waddr = '0;
    logic [VECTOR_WIDTH-1:0] wdata = '0;
    logic [ADDR_WIDTH-1:0] raddr_a = '0;
    logic [ADDR_WIDTH-1:0] raddr_b = '0;
    logic [VECTOR_WIDTH-1:0] rdata_a;
    logic [VECTOR_WIDTH-1:0] rdata_b;

    vector_register_file #(
        .LANES(LANES),
        .ELEMENT_WIDTH(ELEMENT_WIDTH),
        .REG_COUNT(REG_COUNT)
    ) dut (.*);

    always #5 clk = ~clk;

    function automatic logic [VECTOR_WIDTH-1:0] pack4(
        input logic [31:0] lane0,
        input logic [31:0] lane1,
        input logic [31:0] lane2,
        input logic [31:0] lane3
    );
        pack4 = {lane3, lane2, lane1, lane0};
    endfunction

    task automatic check_reads(
        input logic [VECTOR_WIDTH-1:0] expected_a,
        input logic [VECTOR_WIDTH-1:0] expected_b,
        input string description
    );
        begin
            #1;
            if (rdata_a !== expected_a) begin
                $fatal(1, "%s: read A mismatch got %h expected %h",
                       description, rdata_a, expected_a);
            end
            if (rdata_b !== expected_b) begin
                $fatal(1, "%s: read B mismatch got %h expected %h",
                       description, rdata_b, expected_b);
            end
            $display("PASS: %s", description);
        end
    endtask

    task automatic write_vector(
        input logic [ADDR_WIDTH-1:0] address,
        input logic [VECTOR_WIDTH-1:0] value
    );
        begin
            @(negedge clk);
            we = 1'b1;
            waddr = address;
            wdata = value;
            @(posedge clk);
            #1;
            we = 1'b0;
        end
    endtask

    initial begin
        logic [VECTOR_WIDTH-1:0] vector_a;
        logic [VECTOR_WIDTH-1:0] vector_b;
        logic [VECTOR_WIDTH-1:0] vector_c;

        vector_a = pack4(32'd1, 32'd2, 32'd3, 32'd4);
        vector_b = pack4(32'hffff_fffe, 32'h8000_0000,
                         32'h7fff_ffff, 32'h0000_0055);
        vector_c = pack4(32'hdead_beef, 32'h0123_4567,
                         32'h89ab_cdef, 32'h7654_3210);

        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;

        raddr_a = 0;
        raddr_b = 7;
        check_reads('0, '0, "reset clears all vector registers");

        write_vector(3, vector_a);
        write_vector(6, vector_b);
        raddr_a = 3;
        raddr_b = 6;
        check_reads(vector_a, vector_b, "independent vector writes and reads");

        write_vector(3, vector_c);
        raddr_a = 3;
        raddr_b = 6;
        check_reads(vector_c, vector_b, "whole-vector overwrite preserves lane order");

        @(negedge clk);
        we = 1'b0;
        waddr = 6;
        wdata = '0;
        @(posedge clk);
        raddr_a = 3;
        raddr_b = 6;
        check_reads(vector_c, vector_b, "write disabled holds stored vectors");

        @(negedge clk);
        rst = 1'b1;
        @(posedge clk);
        #1;
        rst = 1'b0;
        raddr_a = 3;
        raddr_b = 6;
        check_reads('0, '0, "reset has priority over a pending write");

        $display("VECTOR REGISTER FILE TEST PASSED");
        $finish;
    end

endmodule
