`timescale 1ns/1ps
// Stage 18 reuses the completed Stage 14 cycle-accounting monitor without
// changing the selected core or benchmark workloads.
module vector_stage18_final_bottleneck_analysis_tb;
  vector_stage14_bottleneck_analysis_tb analysis();
endmodule
