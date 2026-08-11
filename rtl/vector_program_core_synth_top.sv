// Stage 5A physical-characterisation wrapper.
// This is not a functional architecture change; it only limits synthetic
// top-level IO while preserving the complete vector_program_core datapath.
module vector_program_core_synth_top (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [4:0]  program_length,
    input  logic        prog_load_enable,
    input  logic [3:0]  prog_load_addr,
    input  logic [15:0] prog_load_data,
    input  logic        load_enable,
    input  logic [2:0]  load_addr,
    input  logic        debug_read_enable,
    input  logic [2:0]  debug_read_addr,
    output logic        running,
    output logic        done,
    output logic [3:0]  current_pc,
    output logic        current_instruction_parity,
    output logic        current_instruction_valid,
    output logic        debug_read_data_parity
);
    logic [127:0] debug_read_data;
    // A deterministic synthetic load value keeps the load path observable
    // without adding a 128-bit package IO bus to the implementation top.
    localparam logic [127:0] SYNTH_LOAD_DATA =
        128'h44444444_33333333_22222222_11111111;

    vector_program_core core_inst (
        .clk(clk), .rst(rst), .start(start), .program_length(program_length),
        .running(running), .done(done), .current_pc(current_pc),
        .current_instruction(current_instruction),
        .current_instruction_valid(current_instruction_valid),
        .prog_load_enable(prog_load_enable), .prog_load_addr(prog_load_addr),
        .prog_load_data(prog_load_data), .load_enable(load_enable),
        .load_addr(load_addr), .load_data(SYNTH_LOAD_DATA),
        .debug_read_enable(debug_read_enable), .debug_read_addr(debug_read_addr),
        .debug_read_data(debug_read_data)
    );

    assign current_instruction_parity = ^current_instruction;
    assign debug_read_data_parity = ^debug_read_data;
endmodule
