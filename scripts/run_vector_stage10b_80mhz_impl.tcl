set PART xc7a35tcpg236-1
create_project -in_memory -part $PART
set OUT_DIR reports/vector_stage10b
file mkdir $OUT_DIR
foreach f {vector_register_file vector_alu vector_execution_unit vector_instruction_memory vector_data_memory vector_memory_instruction_decoder vector_alu_prefetch_program_core vector_alu_prefetch_program_core_synth_top} {add_files -norecurse [file normalize "rtl/${f}.sv"]}
update_compile_order -fileset sources_1
read_xdc constraints/vector_alu_prefetch_program_core_stage10b_80mhz.xdc
synth_design -top vector_alu_prefetch_program_core_synth_top -part $PART
opt_design
place_design
route_design
report_utilization -hierarchical -file $OUT_DIR/stage10b_postroute_utilization.rpt
report_ram_utilization -file $OUT_DIR/stage10b_postroute_memory_mapping.rpt
report_timing_summary -file $OUT_DIR/stage10b_80mhz_timing_summary.rpt
report_timing -max_paths 20 -sort_by group -file $OUT_DIR/stage10b_worst_paths.rpt
puts "STAGE10B_80MHZ_IMPLEMENTATION_COMPLETE"
