// Stage 9 core: Stage 7-compatible straight-line vector core with one-entry
// sequential VLOAD prefetch. The ISA and baseline core are unchanged.
module vector_prefetch_program_core #(
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
    output logic [2:0] state_debug,
    output logic [31:0] prefetch_request_count,
    output logic [31:0] prefetch_hit_count,
    output logic [31:0] prefetch_miss_count,
    output logic [31:0] overlap_alu_count,
    output logic [31:0] overlap_store_count
);
    localparam int PCW=(PROGRAM_DEPTH<=1)?1:$clog2(PROGRAM_DEPTH);
    typedef enum logic [1:0] {S_EXEC,S_LOAD_WB} state_t;
    state_t state;
    logic [15:0] instruction, next_instruction;
    logic [3:0] alu_op, next_alu_op; logic [2:0] src_a,src_b,dst,next_dst;
    logic [4:0] mem_addr,next_mem_addr;
    logic valid,is_alu,is_vload,is_vstore,next_valid,next_is_vload;
    logic [4:0] active_length; logic [2:0] load_dst;
    logic [127:0] mem_read_data, alu_result;
    logic mem_read_enable, mem_write_enable, core_reg_write, core_load_write;
    logic [4:0] mem_read_addr, mem_write_addr;
    logic [127:0] mem_write_data;
    logic prefetch_pending, prefetch_hit, prefetch_issue;
    logic [4:0] prefetch_addr;
    logic [PCW-1:0] next_pc;

    vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) pim(
      .clk(clk), .prog_load_enable(prog_load_enable&&!running), .prog_load_addr(prog_load_addr),
      .prog_load_data(prog_load_data), .read_addr(current_pc), .read_data(instruction));
    vector_instruction_memory #(.DEPTH(PROGRAM_DEPTH)) next_pim(
      .clk(clk), .prog_load_enable(prog_load_enable&&!running), .prog_load_addr(prog_load_addr), .prog_load_data(prog_load_data),
      .read_addr(next_pc), .read_data(next_instruction));
    vector_memory_instruction_decoder dec(.instruction(instruction), .alu_op(alu_op), .src_a(src_a), .src_b(src_b), .dst(dst), .mem_addr(mem_addr), .instruction_valid(valid), .is_alu(is_alu), .is_vload(is_vload), .is_vstore(is_vstore));
    vector_memory_instruction_decoder next_dec(.instruction(next_instruction), .alu_op(next_alu_op), .src_a(), .src_b(), .dst(next_dst), .mem_addr(next_mem_addr), .instruction_valid(next_valid), .is_alu(), .is_vload(next_is_vload), .is_vstore());
    assign current_instruction=instruction;
    assign current_instruction_valid=valid;
    assign state_debug={2'b00,state};
    assign next_pc = current_pc + 1'b1;
    assign prefetch_hit = running && state==S_EXEC && is_vload && prefetch_pending && (prefetch_addr==mem_addr);
    // One read request is issued only for the next sequential VLOAD. A store
    // to that same address is excluded, preventing stale prefetched data.
    assign prefetch_issue = running && state==S_EXEC && (is_alu || is_vstore) &&
                            (current_pc + 1'b1 < active_length) && next_valid && next_is_vload &&
                            !prefetch_pending && !(is_vstore && (mem_addr==next_mem_addr));
    assign mem_read_enable = (running && state==S_EXEC && is_vload && !prefetch_hit) || prefetch_issue || (!running && data_debug_read_enable);
    assign mem_read_addr = (running && state==S_EXEC && is_vload && !prefetch_hit) ? mem_addr :
                           (prefetch_issue ? next_mem_addr : data_debug_read_addr);
    assign mem_write_enable = (running && state==S_EXEC && is_vstore) || (!running && data_load_enable);
    assign mem_write_addr = (running && state==S_EXEC && is_vstore) ? mem_addr : data_load_addr;
    assign mem_write_data = (running && state==S_EXEC && is_vstore) ? debug_read_data : data_load_data;
    vector_data_memory #(.DEPTH(DATA_DEPTH)) data_mem(.clk(clk),.read_enable(mem_read_enable),.read_addr(mem_read_addr),.read_data(mem_read_data),.write_enable(mem_write_enable),.write_addr(mem_write_addr),.write_data(mem_write_data));
    assign data_debug_read_data=mem_read_data;
    assign core_reg_write = running && state==S_EXEC && is_alu;
    assign core_load_write = running && state==S_EXEC && prefetch_hit;
    vector_execution_unit eu(.clk(clk),.rst(rst),.src_a((debug_read_enable&&!running)?debug_read_addr:src_a),.src_b(src_b),.dst((state==S_LOAD_WB)?load_dst:((prefetch_hit)?dst:dst)),.alu_op(alu_op),.execute_enable(core_reg_write),.load_enable((!running&&vector_load_enable)|| (running&&(state==S_LOAD_WB || core_load_write))),.load_addr((!running&&vector_load_enable)?vector_load_addr:((state==S_LOAD_WB)?load_dst:dst)),.load_data((!running&&vector_load_enable)?vector_load_data:mem_read_data),.debug_read_enable(debug_read_enable&&!running),.debug_read_addr(debug_read_addr),.debug_read_data(debug_read_data),.alu_result(alu_result));

    always_ff @(posedge clk) begin
      if (rst) begin
        current_pc<='0; running<=0; done<=0; active_length<='0; load_dst<='0; state<=S_EXEC;
        prefetch_pending<=0; prefetch_addr<='0;
        prefetch_request_count<=0; prefetch_hit_count<=0; prefetch_miss_count<=0; overlap_alu_count<=0; overlap_store_count<=0;
      end else begin
        if (!running && (data_load_enable || data_debug_read_enable)) prefetch_pending<=0;
        if (prefetch_issue) begin prefetch_pending<=1; prefetch_addr<=next_mem_addr; prefetch_request_count<=prefetch_request_count+1'b1; if(is_alu) overlap_alu_count<=overlap_alu_count+1'b1; if(is_vstore) overlap_store_count<=overlap_store_count+1'b1; end
        if (prefetch_hit) begin prefetch_pending<=0; prefetch_hit_count<=prefetch_hit_count+1'b1; end
        if (rst) begin end
        else if (!running) begin
          if (start) begin
            current_pc<='0; prefetch_pending<=0; prefetch_request_count<=0; prefetch_hit_count<=0; prefetch_miss_count<=0; overlap_alu_count<=0; overlap_store_count<=0;
            if (program_length==0 || program_length>PROGRAM_DEPTH) begin running<=0; done<=1; end else begin active_length<=program_length; running<=1; done<=0; state<=S_EXEC; end
          end
        end else if (state==S_LOAD_WB) begin
          if (current_pc==active_length-1) begin running<=0; done<=1; end else begin current_pc<=current_pc+1'b1; state<=S_EXEC; end
        end else if (is_vload) begin
          if (prefetch_hit) begin
            if (current_pc==active_length-1) begin running<=0; done<=1; end else current_pc<=current_pc+1'b1;
          end else begin load_dst<=dst; state<=S_LOAD_WB; prefetch_miss_count<=prefetch_miss_count+1'b1; end
        end else if (current_pc==active_length-1) begin running<=0; done<=1;
        end else current_pc<=current_pc+1'b1;
      end
    end
endmodule
