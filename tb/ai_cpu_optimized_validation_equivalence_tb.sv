`timescale 1ns/1ps
module ai_cpu_optimized_validation_equivalence_tb;
  logic clk=0,rst=1,enable=0; always #5 clk=~clk;
  logic [31:0] a_cycles,b_cycles,a_pc,b_pc,a_wdata,b_wdata,a_maddr,b_maddr,a_mdata,b_mdata;
  logic a_retire,b_retire,a_store,b_store; logic [3:0] a_op,b_op; logic [4:0] a_rd,b_rd;
  cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(.IMEM_INIT_FILE("programs/dot4acc_stage_d.mem")) canonical(
    .clk(clk),.rst(rst),.enable(enable),.total_cycles(a_cycles),.fetch_pc(a_pc),
    .retire_valid(a_retire),.retire_opcode(a_op),.retire_rd(a_rd),.retire_write_data(a_wdata),
    .retire_mem_write(a_store),.retire_mem_addr(a_maddr),.retire_mem_data(a_mdata));
  cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation #(.IMEM_INIT_FILE("programs/dot4acc_stage_d.mem")) validation(
    .clk(clk),.rst(rst),.enable(enable),.total_cycles(b_cycles),.fetch_pc(b_pc),
    .retire_valid(b_retire),.retire_opcode(b_op),.retire_rd(b_rd),.retire_write_data(b_wdata),
    .retire_mem_write(b_store),.retire_mem_addr(b_maddr),.retire_mem_data(b_mdata),
    .validation_load_mode(1'b0),.validation_prog_we(1'b0),.validation_prog_addr(8'd0),.validation_prog_data(32'd0),
    .validation_data_we(1'b0),.validation_data_addr(8'd0),.validation_data_wdata(32'd0),.validation_data_re(1'b0),
    .validation_data_raddr(8'd0),.validation_data_rdata(),.validation_done());
  integer i;
  initial begin
    #1;
    for(i=0;i<256;i=i+1) begin
      canonical.instr_mem_inst.mem[i] = 32'h0;
      validation.instr_mem_inst.mem[i] = 32'h0;
      canonical.data_mem_inst.mem[i] = 32'h0;
      validation.data_mem_inst.mem[i] = 32'h0;
    end
    $readmemh("C:/FPGA/systemverilog-fpga-cpu/programs/dot4acc_stage_d.mem", canonical.instr_mem_inst.mem);
    $readmemh("C:/FPGA/systemverilog-fpga-cpu/programs/dot4acc_stage_d.mem", validation.instr_mem_inst.mem);
    repeat(4) @(posedge clk); rst<=0; enable<=1;
    for(i=0;i<1000;i=i+1) begin
      @(posedge clk); #1;
      if ({a_retire,a_store,a_op,a_rd,a_wdata,a_maddr,a_mdata,a_cycles} !==
          {b_retire,b_store,b_op,b_rd,b_wdata,b_maddr,b_mdata,b_cycles})
        $fatal(1,"OPTIMIZED_EQ_MISMATCH cycle=%0d",i);
      if (a_store && b_store) begin
        $display("DOT64_CANONICAL_CYCLES=%0d DOT64_VALIDATION_CYCLES=%0d", a_cycles, b_cycles);
        $display("AI_CPU_DOT64_CYCLE_EQUIVALENCE_PASS");
        $display("AI_CPU_OPTIMIZED_EQUIVALENCE_PASS"); $finish;
      end
    end
    $fatal(1,"DOT64 completion store not observed");
  end
endmodule
