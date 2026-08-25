// Standalone Stage 4 decoder for the compact 16-bit vector instruction.
//
// [15:12] opcode, [11:9] dst, [8:6] src_a, [5:3] src_b, [2:0] reserved.
module vector_instruction_decoder (
    input  logic [15:0] instruction,
    output logic [3:0]  alu_op,
    output logic [2:0]  src_a,
    output logic [2:0]  src_b,
    output logic [2:0]  dst,
    output logic        instruction_valid,
    output logic        execute_enable
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

    always_comb begin
        alu_op = VADD;
        src_a = 3'h0;
        src_b = 3'h0;
        dst = 3'h0;
        instruction_valid = 1'b0;
        execute_enable = 1'b0;

        case (instruction[15:12])
            VADD, VSUB, VAND, VOR, VXOR,
            VCMPEQ, VCMPLT, VSLL, VSRL, VSRA: begin
                alu_op = instruction[15:12];
                dst = instruction[11:9];
                src_a = instruction[8:6];
                src_b = instruction[5:3];
                instruction_valid = 1'b1;
                execute_enable = 1'b1;
            end
            default: begin
                // Invalid opcodes retain deterministic zero controls.  The
                // reserved low bits are intentionally ignored for valid ops.
                alu_op = VADD;
                src_a = 3'h0;
                src_b = 3'h0;
                dst = 3'h0;
                instruction_valid = 1'b0;
                execute_enable = 1'b0;
            end
        endcase
    end

endmodule
