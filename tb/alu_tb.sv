module alu_tb;

    logic [7:0] a;
    logic [7:0] b;
    logic [2:0] op;
    logic [7:0] y;

    alu dut (
        .a(a),
        .b(b),
        .op(op),
        .y(y)
    );

    initial begin
        a = 8'd5;
        b = 8'd7;
        op = 3'b000;
        #1;

        if (y !== 8'd12) begin
            $display("ADD test failed. Expected 12, got %0d", y);
            $finish;
        end

        a = 8'd10;
        b = 8'd3;
        op = 3'b001;
        #1;

        if (y !== 8'd7) begin
            $display("SUB test failed. Expected 7, got %0d", y);
            $finish;
        end

        a = 8'b10101010;
        b = 8'b11001100;
        op = 3'b010;
        #1;

        if (y !== 8'b10001000) begin
            $display("AND test failed.");
            $finish;
        end

        $display("All ALU tests passed.");
        $finish;
    end

endmodule
