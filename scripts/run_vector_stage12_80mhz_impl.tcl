set root [file normalize .]
set out [file normalize reports/vector_stage12]
file mkdir $out
create_project stage12_impl .stage12_impl -part xc7a35tcpg236-1 -force
add_files -norecurse [list [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] [file join $root rtl vector_two_outstanding_prefetch_program_core.sv] [file join $root rtl vector_two_outstanding_prefetch_program_core_synth_top.sv]]
add_files -fileset constrs_1 -norecurse [file join $root constraints vector_two_outstanding_prefetch_stage12_80mhz.xdc]
set_property top vector_two_outstanding_prefetch_program_core_synth_top [get_filesets sources_1]
set_property generic {LOOKAHEAD_DEPTH=6} [get_filesets sources_1]
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_utilization -file [file join $out stage12_postroute_utilization.rpt]
report_timing_summary -file [file join $out stage12_80mhz_timing_summary.rpt]
report_timing -max_paths 10 -file [file join $out stage12_worst_paths.rpt]
close_project
puts "STAGE12_IMPL_COMPLETE"
