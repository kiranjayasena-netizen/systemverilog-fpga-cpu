`timescale 1ns/1ps
module ai_cpu_baseline_validation_equivalence_tb;
  logic clk=0,rst=1,enable=0; always #5 clk=~clk;
  logic [31:0] c_cycles,v_cycles,c_pc,v_pc,c_wdata,v_wdata,c_maddr,v_maddr,c_mdata,v_mdata;
  logic c_retire,v_retire,c_store,v_store;
  logic [3:0] c_op,v_op; logic [4:0] c_rd,v_rd;
  logic [31:0] nop=32'b0;
  cpu_core_pipeline_timingopt #(.IMEM_INIT_FILE("programs/final_benchmark.mem")) canonical(
    .clk(clk),.rst(rst),.enable(enable),.total_cycles(c_cycles),.fetch_pc(c_pc),
    .retire_valid(c_retire),.retire_opcode(c_op),.retire_rd(c_rd),.retire_write_data(c_wdata),
    .retire_mem_write(c_store),.retire_mem_addr(c_maddr),.retire_mem_data(c_mdata));
  cpu_core_pipeline_timingopt_validation #(.IMEM_INIT_FILE("programs/final_benchmark.mem")) validation(
    .clk(clk),.rst(rst),.enable(enable),.total_cycles(v_cycles),.fetch_pc(v_pc),
    .retire_valid(v_retire),.retire_opcode(v_op),.retire_rd(v_rd),.retire_write_data(v_wdata),
    .retire_mem_write(v_store),.retire_mem_addr(v_maddr),.retire_mem_data(v_mdata),
    .validation_load_mode(1'b0),.validation_prog_we(1'b0),.validation_prog_addr(8'd0),.validation_prog_data(32'd0),
    .validation_data_we(1'b0),.validation_data_addr(8'd0),.validation_data_wdata(32'd0),.validation_data_re(1'b0),
    .validation_data_raddr(8'd0),.validation_data_rdata(),.validation_done());
  integer i;
  initial begin
    #1;
    for(i=0;i<256;i=i+1) begin
      canonical.instr_mem_inst.mem[i] = 32'h0;
      validation.instr_mem_inst.mem[i] = 32'h0;
    end
    $readmemh("C:/FPGA/systemverilog-fpga-cpu/programs/final_benchmark.mem", canonical.instr_mem_inst.mem);
    $readmemh("C:/FPGA/systemverilog-fpga-cpu/programs/final_benchmark.mem", validation.instr_mem_inst.mem);
    repeat(4) @(posedge clk); rst<=0; enable<=1;
    for(i=0;i<300;i=i+1) begin
      @(posedge clk); #1;
      if ({c_retire,c_store,c_op,c_rd,c_wdata,c_maddr,c_mdata,c_cycles} !==
          {v_retire,v_store,v_op,v_rd,v_wdata,v_maddr,v_mdata,v_cycles})
        $fatal(1,"BASELINE_EQ_MISMATCH cycle=%0d",i);
    end
    $display("AI_CPU_BASELINE_EQUIVALENCE_PASS"); $finish;
  end
endmodule
