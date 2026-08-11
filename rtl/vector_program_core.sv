// Stage 5 standalone programmable straight-line vector core.
// It wraps the verified Stage 4 instruction-controlled execution unit.
module vector_program_core #(
    parameter int unsigned PROGRAM_DEPTH = 16
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         start,
    input  logic [4:0]                   program_length,
    output logic                         running,
    output logic                         done,
    output logic [((PROGRAM_DEPTH <= 1) ? 1 : $clog2(PROGRAM_DEPTH))-1:0] current_pc,
    output logic [15:0]                  current_instruction,
    output logic                         current_instruction_valid,

    input  logic                         prog_load_enable,
    input  logic [((PROGRAM_DEPTH <= 1) ? 1 : $clog2(PROGRAM_DEPTH))-1:0] prog_load_addr,
    input  logic [15:0]                  prog_load_data,

    input  logic                         load_enable,
    input  logic [2:0]                   load_addr,
    input  logic [127:0]                 load_data,
    input  logic                         debug_read_enable,
    input  logic [2:0]                   debug_read_addr,
    output logic [127:0]                 debug_read_data
);
    logic [15:0] fetched_instruction;
    logic instruction_enable;
    logic stage4_actual_enable;
    logic [127:0] alu_result;
    logic [3:0] stage4_decoded_alu_op;
    logic [2:0] stage4_decoded_src_a, stage4_decoded_src_b, stage4_decoded_dst;
    logic stage4_decoded_valid, stage4_decoded_execute_enable;
    logic [4:0] active_program_length;

    // Program writes are accepted only while idle so the active program is stable.
    vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) instruction_memory_inst (
        .clk(clk),
        .prog_load_enable(prog_load_enable && !running),
        .prog_load_addr(prog_load_addr),
        .prog_load_data(prog_load_data),
        .read_addr(current_pc),
        .read_data(fetched_instruction)
    );

    assign current_instruction = fetched_instruction;
    assign instruction_enable = running && !load_enable;

    assign current_instruction_valid = stage4_decoded_valid;

    vector_instruction_execution_unit execution_unit_inst (
        .clk(clk), .rst(rst), .instruction(fetched_instruction),
        .instruction_enable(instruction_enable),
        .load_enable(load_enable), .load_addr(load_addr), .load_data(load_data),
        .debug_read_enable(debug_read_enable), .debug_read_addr(debug_read_addr),
        .debug_read_data(debug_read_data),
        .decoded_alu_op(stage4_decoded_alu_op), .decoded_src_a(stage4_decoded_src_a),
        .decoded_src_b(stage4_decoded_src_b), .decoded_dst(stage4_decoded_dst),
        .instruction_valid(stage4_decoded_valid), .decoded_execute_enable(stage4_decoded_execute_enable),
        .execute_enable(stage4_actual_enable),
        .alu_result(alu_result)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            current_pc <= '0;
            running <= 1'b0;
            done <= 1'b0;
            active_program_length <= '0;
        end else if (!running) begin
            if (start) begin
                current_pc <= '0;
                if ((program_length == 0) || (program_length > PROGRAM_DEPTH)) begin
                    running <= 1'b0;
                    done <= 1'b1;
                end else begin
                    active_program_length <= program_length;
                    running <= 1'b1;
                    done <= 1'b0;
                end
            end
        end else if (active_program_length == 0) begin
            running <= 1'b0;
            done <= 1'b1;
        end else if (current_pc == active_program_length - 1'b1) begin
            running <= 1'b0;
            done <= 1'b1;
        end else begin
            current_pc <= current_pc + 1'b1;
        end
    end
endmodule
