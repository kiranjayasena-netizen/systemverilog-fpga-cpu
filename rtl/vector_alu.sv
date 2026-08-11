// Standalone Stage 2 four-lane vector ALU.
//
// Lane 0 is the least-significant 32-bit slice.  The unit is intentionally
// combinational and independent of the CPU and vector register file.
module vector_alu (
    input  logic [127:0] vector_a,
    input  logic [127:0] vector_b,
    input  logic [3:0]   alu_op,
    output logic [127:0] vector_result
);

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

    logic [31:0] lane_a;
    logic [31:0] lane_b;
    logic signed [31:0] lane_a_signed;
    logic signed [31:0] lane_b_signed;

    always_comb begin
        vector_result = 128'h0;
        lane_a = 32'h0;
        lane_b = 32'h0;
        lane_a_signed = 32'sh0;
        lane_b_signed = 32'sh0;

        for (int lane = 0; lane < 4; lane++) begin
            lane_a = vector_a[lane*32 +: 32];
            lane_b = vector_b[lane*32 +: 32];
            lane_a_signed = $signed(lane_a);
            lane_b_signed = $signed(lane_b);

            case (alu_op)
                VADD:   vector_result[lane*32 +: 32] = lane_a + lane_b;
                VSUB:   vector_result[lane*32 +: 32] = lane_a - lane_b;
                VAND:   vector_result[lane*32 +: 32] = lane_a & lane_b;
                VOR:    vector_result[lane*32 +: 32] = lane_a | lane_b;
                VXOR:   vector_result[lane*32 +: 32] = lane_a ^ lane_b;
                VCMPEQ: vector_result[lane*32 +: 32] =
                            (lane_a == lane_b) ? 32'h1 : 32'h0;
                VCMPLT: vector_result[lane*32 +: 32] =
                            (lane_a_signed < lane_b_signed) ? 32'h1 : 32'h0;
                VSLL:   vector_result[lane*32 +: 32] = lane_a << lane_b[4:0];
                VSRL:   vector_result[lane*32 +: 32] = lane_a >> lane_b[4:0];
                VSRA:   vector_result[lane*32 +: 32] =
                            lane_a_signed >>> lane_b[4:0];
                default: vector_result[lane*32 +: 32] = 32'h0;
            endcase
        end
    end

endmodule
