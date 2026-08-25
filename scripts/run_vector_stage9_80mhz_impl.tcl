set PART xc7a35tcpg236-1
set OUT_DIR reports/vector_stage9
file mkdir $OUT_DIR
foreach f {vector_register_file vector_alu vector_execution_unit vector_instruction_memory vector_data_memory vector_memory_instruction_decoder vector_prefetch_program_core vector_prefetch_program_core_synth_top} {read_verilog -sv rtl/$f.sv}
read_xdc constraints/vector_prefetch_program_core_stage9_80mhz.xdc
synth_design -top vector_prefetch_program_core_synth_top -part $PART
opt_design
place_design
route_design
report_utilization -hierarchical -file $OUT_DIR/stage9_80mhz_utilization.rpt
report_ram_utilization -file $OUT_DIR/stage9_80mhz_ram_utilization.rpt
report_timing_summary -file $OUT_DIR/stage9_80mhz_timing_summary.rpt
report_timing -max_paths 20 -sort_by group -file $OUT_DIR/stage9_80mhz_worst_paths.rpt
report_clock_utilization -file $OUT_DIR/stage9_80mhz_clock_utilization.rpt
puts "STAGE9_80MHZ_IMPLEMENTATION_COMPLETE"
