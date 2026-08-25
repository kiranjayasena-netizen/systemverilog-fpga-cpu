package dot4acc_reference_pkg;

    import cpu_defs_pkg::*;

    typedef logic signed [7:0]  dot4acc_lane_t;
    typedef logic signed [15:0] dot4acc_product_t;
    typedef logic signed [16:0] dot4acc_pair_sum_t;
    typedef logic signed [17:0] dot4acc_sum_t;
    typedef logic signed [31:0] dot4acc_accumulator_t;

    // Four products range from -65,024 to +65,536. The range is asymmetric
    // because -128 * -128 is +16,384, while the most-negative lane product is
    // -128 * +127 = -16,256. Both extrema require a signed 18-bit sum.
    localparam dot4acc_sum_t DOT4ACC_MIN_DOT = -18'sd65024;
    localparam dot4acc_sum_t DOT4ACC_MAX_DOT =  18'sd65536;

    function automatic logic [31:0] encode_dot4acc(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        encode_dot4acc = {OP_DOT4ACC, rd, rs1, rs2, 13'd0};
    endfunction

    function automatic logic dot4acc_encoding_is_canonical(
        input logic [31:0] instruction
    );
        dot4acc_encoding_is_canonical =
            (instruction[31:28] == OP_DOT4ACC) &&
            (instruction[12:0] == 13'd0);
    endfunction

    // Canonical width-explicit reference model. Each lane is signed before
    // multiplication. Products, pair sums, and the final dot sum are widened
    // at their mathematical boundaries rather than relying on expression-size
    // propagation. Assignment to a 32-bit signed value defines modulo-2^32
    // wrapping for the final accumulator addition.
    function automatic logic [31:0] dot4acc_reference(
        input logic [31:0] rd_value,
        input logic [31:0] rs1_value,
        input logic [31:0] rs2_value
    );
        dot4acc_lane_t        a0;
        dot4acc_lane_t        a1;
        dot4acc_lane_t        a2;
        dot4acc_lane_t        a3;
        dot4acc_lane_t        b0;
        dot4acc_lane_t        b1;
        dot4acc_lane_t        b2;
        dot4acc_lane_t        b3;
        dot4acc_product_t     p0;
        dot4acc_product_t     p1;
        dot4acc_product_t     p2;
        dot4acc_product_t     p3;
        dot4acc_pair_sum_t    pair0;
        dot4acc_pair_sum_t    pair1;
        dot4acc_sum_t         dot_sum;
        dot4acc_accumulator_t dot_extended;
        dot4acc_accumulator_t accumulator;
        dot4acc_accumulator_t result;

        a0 = dot4acc_lane_t'(rs1_value[7:0]);
        a1 = dot4acc_lane_t'(rs1_value[15:8]);
        a2 = dot4acc_lane_t'(rs1_value[23:16]);
        a3 = dot4acc_lane_t'(rs1_value[31:24]);
        b0 = dot4acc_lane_t'(rs2_value[7:0]);
        b1 = dot4acc_lane_t'(rs2_value[15:8]);
        b2 = dot4acc_lane_t'(rs2_value[23:16]);
        b3 = dot4acc_lane_t'(rs2_value[31:24]);

        p0 = dot4acc_product_t'(a0) * dot4acc_product_t'(b0);
        p1 = dot4acc_product_t'(a1) * dot4acc_product_t'(b1);
        p2 = dot4acc_product_t'(a2) * dot4acc_product_t'(b2);
        p3 = dot4acc_product_t'(a3) * dot4acc_product_t'(b3);

        pair0 = dot4acc_pair_sum_t'(p0) + dot4acc_pair_sum_t'(p1);
        pair1 = dot4acc_pair_sum_t'(p2) + dot4acc_pair_sum_t'(p3);
        dot_sum = dot4acc_sum_t'(pair0) + dot4acc_sum_t'(pair1);

        dot_extended = dot4acc_accumulator_t'(dot_sum);
        accumulator = dot4acc_accumulator_t'(rd_value);
        result = accumulator + dot_extended;
        dot4acc_reference = result;
    endfunction

endpackage
