set PART xc7a35tcpg236-1
set OUT_DIR reports/vector_stage5a/80mhz
file mkdir $OUT_DIR
foreach f {vector_register_file vector_alu vector_execution_unit vector_instruction_decoder vector_instruction_execution_unit vector_instruction_memory vector_program_core vector_program_core_synth_top} {read_verilog -sv rtl/$f.sv}
read_xdc constraints/vector_program_core_stage5a_80mhz.xdc
synth_design -top vector_program_core_synth_top -part $PART
opt_design
place_design
route_design
report_timing_summary -file $OUT_DIR/timing_summary.rpt
report_utilization -hierarchical -file $OUT_DIR/utilization.rpt
report_timing -max_paths 5 -path_type full -file $OUT_DIR/worst_paths.rpt
puts "STAGE5A_80MHZ_COMPLETE"
