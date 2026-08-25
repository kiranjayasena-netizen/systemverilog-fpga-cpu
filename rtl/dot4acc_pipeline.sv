module dot4acc_pipeline (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    input  logic        input_valid,
    input  logic [31:0] accumulator,
    input  logic [31:0] packed_a,
    input  logic [31:0] packed_b,

    output logic        output_valid,
    output logic [31:0] result
);

    typedef logic signed [7:0]  lane_t;
    typedef logic signed [15:0] product_t;
    typedef logic signed [16:0] pair_sum_t;
    typedef logic signed [17:0] dot_sum_t;
    typedef logic signed [31:0] accumulator_t;

    lane_t lane_a0;
    lane_t lane_a1;
    lane_t lane_a2;
    lane_t lane_a3;
    lane_t lane_b0;
    lane_t lane_b1;
    lane_t lane_b2;
    lane_t lane_b3;

    // Match the repository's established MAC8 inference convention while
    // keeping the arithmetic portable and free of vendor primitive instances.
    (* use_dsp = "yes" *) product_t product0_next;
    (* use_dsp = "yes" *) product_t product1_next;
    (* use_dsp = "yes" *) product_t product2_next;
    (* use_dsp = "yes" *) product_t product3_next;
    pair_sum_t pair0_next;
    pair_sum_t pair1_next;
    // Keep the reduction tree in fabric; only the four lane multipliers are
    // intended to consume DSP48E1 resources in this isolated pipeline.
    (* use_dsp = "no" *) dot_sum_t dot_sum_next;
    accumulator_t dot_extended_next;
    accumulator_t accumulator_next;
    // Keep the final 32-bit accumulator add in fabric so the isolated DOT unit
    // consumes the four planned multiplier DSPs rather than a fifth DSP.
    (* use_dsp = "no" *) accumulator_t result_next;

    logic stage1_valid_reg;
    logic stage2_valid_reg;
    product_t product0_reg;
    product_t product1_reg;
    product_t product2_reg;
    product_t product3_reg;
    pair_sum_t pair0_reg;
    pair_sum_t pair1_reg;
    accumulator_t stage1_accumulator_reg;
    accumulator_t stage2_accumulator_reg;

    // Latency contract: an accepted input uses the acceptance edge for stage 1,
    // the next advancing edge for stage 2, and the following advancing edge for
    // stage 3. Thus output_valid is asserted on the third enabled rising edge
    // counting the acceptance edge. enable == 0 freezes all three stages, and
    // an enabled clock with input_valid == 0 inserts a stage-1 bubble. II is one.
    always_comb begin
        lane_a0 = lane_t'(packed_a[7:0]);
        lane_a1 = lane_t'(packed_a[15:8]);
        lane_a2 = lane_t'(packed_a[23:16]);
        lane_a3 = lane_t'(packed_a[31:24]);
        lane_b0 = lane_t'(packed_b[7:0]);
        lane_b1 = lane_t'(packed_b[15:8]);
        lane_b2 = lane_t'(packed_b[23:16]);
        lane_b3 = lane_t'(packed_b[31:24]);

        product0_next = product_t'(lane_a0) * product_t'(lane_b0);
        product1_next = product_t'(lane_a1) * product_t'(lane_b1);
        product2_next = product_t'(lane_a2) * product_t'(lane_b2);
        product3_next = product_t'(lane_a3) * product_t'(lane_b3);

        pair0_next = pair_sum_t'(product0_reg) + pair_sum_t'(product1_reg);
        pair1_next = pair_sum_t'(product2_reg) + pair_sum_t'(product3_reg);
        dot_sum_next = dot_sum_t'(pair0_reg) + dot_sum_t'(pair1_reg);

        dot_extended_next = accumulator_t'(
            {{14{dot_sum_next[17]}}, dot_sum_next}
        );
        accumulator_next = accumulator_t'(stage2_accumulator_reg);
        result_next = accumulator_next + dot_extended_next;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            stage1_valid_reg       <= 1'b0;
            stage2_valid_reg       <= 1'b0;
            output_valid           <= 1'b0;
            product0_reg           <= product_t'(16'sd0);
            product1_reg           <= product_t'(16'sd0);
            product2_reg           <= product_t'(16'sd0);
            product3_reg           <= product_t'(16'sd0);
            pair0_reg              <= pair_sum_t'(17'sd0);
            pair1_reg              <= pair_sum_t'(17'sd0);
            stage1_accumulator_reg <= accumulator_t'(32'sd0);
            stage2_accumulator_reg <= accumulator_t'(32'sd0);
            result                 <= 32'd0;
        end else if (enable) begin
            stage1_valid_reg <= input_valid;
            product0_reg <= product0_next;
            product1_reg <= product1_next;
            product2_reg <= product2_next;
            product3_reg <= product3_next;
            stage1_accumulator_reg <= accumulator_t'(accumulator);

            stage2_valid_reg <= stage1_valid_reg;
            pair0_reg <= pair0_next;
            pair1_reg <= pair1_next;
            stage2_accumulator_reg <= stage1_accumulator_reg;

            output_valid <= stage2_valid_reg;
            result <= result_next;
        end
    end

endmodule
