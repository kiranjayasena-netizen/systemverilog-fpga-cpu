// Standalone Stage 3 vector execution unit.
//
// This wrapper integrates the verified vector register file and vector ALU.
// It is intentionally not connected to the frozen CPU, an instruction
// decoder, memory, or a scheduler.
module vector_execution_unit (
    input  logic       clk,
    input  logic       rst,

    input  logic [2:0] src_a,
    input  logic [2:0] src_b,
    input  logic [2:0] dst,
    input  logic [3:0] alu_op,
    input  logic       execute_enable,

    // Standalone verification/control load path.  It has priority over
    // execute_enable on an enabled clock edge.
    input  logic       load_enable,
    input  logic [2:0] load_addr,
    input  logic [127:0] load_data,

    // Debug read mode uses the otherwise-unused source-A read port.  Keep it
    // low during normal execution so source-A selection is unaffected.
    input  logic       debug_read_enable,
    input  logic [2:0] debug_read_addr,
    output logic [127:0] debug_read_data,

    // Combinational result preview before the synchronous writeback edge.
    output logic [127:0] alu_result
);

    logic [2:0] rf_read_addr_a;
    logic [127:0] rf_vector_a;
    logic [127:0] rf_vector_b;
    logic [127:0] rf_write_data;
    logic [2:0] rf_write_addr;
    logic rf_write_enable;

    assign rf_read_addr_a = debug_read_enable ? debug_read_addr : src_a;
    assign debug_read_data = rf_vector_a;

    // One write port, with the required priority:
    // reset (inside the register file) > load > execute > hold.
    assign rf_write_enable = load_enable || execute_enable;
    assign rf_write_addr = load_enable ? load_addr : dst;
    assign rf_write_data = load_enable ? load_data : alu_result;

    vector_register_file vector_register_file_inst (
        .clk(clk),
        .rst(rst),
        .we(rf_write_enable),
        .waddr(rf_write_addr),
        .wdata(rf_write_data),
        .raddr_a(rf_read_addr_a),
        .raddr_b(src_b),
        .rdata_a(rf_vector_a),
        .rdata_b(rf_vector_b)
    );

    vector_alu vector_alu_inst (
        .vector_a(rf_vector_a),
        .vector_b(rf_vector_b),
        .alu_op(alu_op),
        .vector_result(alu_result)
    );

endmodule
