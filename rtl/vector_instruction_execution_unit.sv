// Standalone Stage 4 instruction-controlled vector execution wrapper.
// No CPU fetch, program counter, scheduler, or memory is included.
module vector_instruction_execution_unit (
    input  logic       clk,
    input  logic       rst,
    input  logic [15:0] instruction,
    input  logic       instruction_enable,

    input  logic       load_enable,
    input  logic [2:0] load_addr,
    input  logic [127:0] load_data,
    input  logic       debug_read_enable,
    input  logic [2:0] debug_read_addr,
    output logic [127:0] debug_read_data,

    output logic [3:0] decoded_alu_op,
    output logic [2:0] decoded_src_a,
    output logic [2:0] decoded_src_b,
    output logic [2:0] decoded_dst,
    output logic       instruction_valid,
    output logic       decoded_execute_enable,
    output logic       execute_enable,
    output logic [127:0] alu_result
);

    vector_instruction_decoder decoder_inst (
        .instruction(instruction),
        .alu_op(decoded_alu_op),
        .src_a(decoded_src_a),
        .src_b(decoded_src_b),
        .dst(decoded_dst),
        .instruction_valid(instruction_valid),
        .execute_enable(decoded_execute_enable)
    );

    assign execute_enable = instruction_enable && instruction_valid;

    vector_execution_unit execution_unit_inst (
        .clk(clk),
        .rst(rst),
        .src_a(decoded_src_a),
        .src_b(decoded_src_b),
        .dst(decoded_dst),
        .alu_op(decoded_alu_op),
        .execute_enable(execute_enable),
        .load_enable(load_enable),
        .load_addr(load_addr),
        .load_data(load_data),
        .debug_read_enable(debug_read_enable),
        .debug_read_addr(debug_read_addr),
        .debug_read_data(debug_read_data),
        .alu_result(alu_result)
    );

endmodule
