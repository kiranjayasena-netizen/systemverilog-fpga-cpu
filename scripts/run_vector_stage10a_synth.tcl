set PART xc7a35tcpg236-1
create_project -in_memory -part $PART
set OUT_DIR reports/vector_stage10a
file mkdir $OUT_DIR
foreach f {vector_register_file vector_alu vector_execution_unit vector_instruction_memory vector_data_memory vector_memory_instruction_decoder vector_dual_prefetch_program_core vector_dual_prefetch_program_core_synth_top} {add_files -norecurse [file normalize "rtl/${f}.sv"]}
update_compile_order -fileset sources_1
synth_design -top vector_dual_prefetch_program_core_synth_top -part $PART
report_utilization -hierarchical -file $OUT_DIR/stage10a_v3_synth_utilization.rpt
report_utilization -hierarchical -cells [get_cells core] -file $OUT_DIR/stage10a_v3_synth_hierarchy.rpt
report_ram_utilization -file $OUT_DIR/stage10a_v3_synth_memory_mapping.rpt
puts "STAGE10A_SYNTHESIS_COMPLETE"
