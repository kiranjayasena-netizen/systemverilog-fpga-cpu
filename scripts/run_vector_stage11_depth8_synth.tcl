set root [file normalize .]
set out [file normalize reports/vector_stage11/depth8]
file mkdir $out
create_project stage11_depth8_synth .stage11_depth8_synth -part xc7a35tcpg236-1 -force
add_files -norecurse [list [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] [file join $root rtl vector_extended_lookahead_program_core.sv] [file join $root rtl vector_extended_lookahead_program_core_synth_top.sv]]
set_property top vector_extended_lookahead_program_core_synth_top [get_filesets sources_1]
set_property generic {LOOKAHEAD_DEPTH=8} [get_filesets sources_1]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
report_utilization -file [file join $out stage11_depth8_synth_utilization.rpt]
close_project
puts "STAGE11_DEPTH8_SYNTH_COMPLETE"
