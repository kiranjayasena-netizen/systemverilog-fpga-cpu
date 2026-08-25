// Stage 7 programmable vector core with synchronous whole-vector VLOAD/VSTORE.
module vector_memory_program_core #(
    parameter int unsigned PROGRAM_DEPTH=16,
    parameter int unsigned DATA_DEPTH=32
) (
    input logic clk, rst, start,
    input logic [4:0] program_length,
    output logic running, done,
    output logic [((PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH))-1:0] current_pc,
    output logic [15:0] current_instruction,
    output logic current_instruction_valid,
    input logic prog_load_enable,
    input logic [((PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH))-1:0] prog_load_addr,
    input logic [15:0] prog_load_data,
    input logic data_load_enable,
    input logic [((DATA_DEPTH<=1)?1:$clog2(DATA_DEPTH))-1:0] data_load_addr,
    input logic [127:0] data_load_data,
    input logic data_debug_read_enable,
    input logic [((DATA_DEPTH<=1)?1:$clog2(DATA_DEPTH))-1:0] data_debug_read_addr,
    output logic [127:0] data_debug_read_data,
    input logic vector_load_enable,
    input logic [2:0] vector_load_addr,
    input logic [127:0] vector_load_data,
    input logic debug_read_enable,
    input logic [2:0] debug_read_addr,
    output logic [127:0] debug_read_data,
    output logic [2:0] state_debug
);
    localparam int PCW=(PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH);
    typedef enum logic [2:0] {S_EXEC,S_LOAD_WB} state_t;
    state_t state;
    logic [15:0] instruction;
    logic [3:0] alu_op; logic [2:0] src_a,src_b,dst; logic [4:0] mem_addr;
    logic valid,is_alu,is_vload,is_vstore;
    logic [4:0] active_length; logic [2:0] load_dst;
    logic [127:0] mem_read_data, alu_result;
    logic mem_read_enable, mem_write_enable, core_reg_write;
    logic [4:0] mem_read_addr, mem_write_addr;
    logic [127:0] mem_write_data;

    vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) pim(.clk(clk),.prog_load_enable(prog_load_enable&&!running),.prog_load_addr(prog_load_addr),.prog_load_data(prog_load_data),.read_addr(current_pc),.read_data(instruction));
    vector_memory_instruction_decoder dec(.instruction(instruction),.alu_op(alu_op),.src_a(src_a),.src_b(src_b),.dst(dst),.mem_addr(mem_addr),.instruction_valid(valid),.is_alu(is_alu),.is_vload(is_vload),.is_vstore(is_vstore));
    assign current_instruction=instruction; assign current_instruction_valid=valid; assign state_debug={1'b0,state};

    assign mem_read_enable = (running && state==S_EXEC && is_vload) || (!running && data_debug_read_enable);
    assign mem_read_addr = (running && state==S_EXEC && is_vload) ? mem_addr : data_debug_read_addr;
    assign mem_write_enable = (running && state==S_EXEC && is_vstore) || (!running && data_load_enable);
    assign mem_write_addr = (running && state==S_EXEC && is_vstore) ? mem_addr : data_load_addr;
    assign mem_write_data = (running && state==S_EXEC && is_vstore) ? debug_read_data : data_load_data;
    vector_data_memory #(.DEPTH(DATA_DEPTH)) data_mem(.clk(clk),.read_enable(mem_read_enable),.read_addr(mem_read_addr),.read_data(mem_read_data),.write_enable(mem_write_enable),.write_addr(mem_write_addr),.write_data(mem_write_data));
    assign data_debug_read_data=mem_read_data;

    assign core_reg_write = running && state==S_EXEC && is_alu;
    vector_execution_unit eu(.clk(clk),.rst(rst),.src_a((debug_read_enable&&!running)?debug_read_addr:src_a),.src_b(src_b),.dst((state==S_LOAD_WB)?load_dst:dst),.alu_op(alu_op),.execute_enable(core_reg_write),.load_enable((!running&&vector_load_enable)|| (running&&state==S_LOAD_WB)),.load_addr((!running&&vector_load_enable)?vector_load_addr:load_dst),.load_data((!running&&vector_load_enable)?vector_load_data:mem_read_data),.debug_read_enable(debug_read_enable&&!running),.debug_read_addr(debug_read_addr),.debug_read_data(debug_read_data),.alu_result(alu_result));

    always_ff @(posedge clk) begin
        if(rst) begin current_pc<='0; running<=0; done<=0; active_length<='0; load_dst<='0; state<=S_EXEC; end
        else if(!running) begin
            if(start) begin current_pc<='0; if(program_length==0 || program_length>PROGRAM_DEPTH) begin running<=0; done<=1; end else begin active_length<=program_length; running<=1; done<=0; state<=S_EXEC; end end
        end else if(state==S_LOAD_WB) begin
            if(current_pc==active_length-1) begin running<=0; done<=1; end else begin current_pc<=current_pc+1'b1; state<=S_EXEC; end
        end else if(is_vload) begin load_dst<=dst; state<=S_LOAD_WB;
        end else if(current_pc==active_length-1) begin running<=0; done<=1;
        end else current_pc<=current_pc+1'b1;
    end
endmodule
