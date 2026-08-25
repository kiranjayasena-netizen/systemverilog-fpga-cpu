// Stage 6 lightweight physical-inference wrapper; no architectural behavior.
module vector_data_memory_synth_top (
    input logic clk,
    input logic read_enable,
    input logic [4:0] read_addr,
    input logic write_enable,
    input logic [4:0] write_addr,
    output logic read_parity
);
    logic [127:0] read_data;
    localparam logic [127:0] SYNTH_WRITE_DATA = 128'h44444444_33333333_22222222_11111111;
    vector_data_memory mem_inst(.clk(clk),.read_enable(read_enable),.read_addr(read_addr),.read_data(read_data),.write_enable(write_enable),.write_addr(write_addr),.write_data(SYNTH_WRITE_DATA));
    assign read_parity = ^read_data;
endmodule
