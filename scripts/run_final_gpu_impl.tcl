set root [file normalize .]
set out [file normalize reports/final_gpu]
file mkdir $out
create_project final_gpu_impl .final_gpu_impl -part xc7a35tcpg236-1 -force
add_files -norecurse [list \
 [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] \
 [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] \
 [file join $root rtl vector_load_overlap_program_core.sv] [file join $root rtl vector_gpu_accelerator.sv] [file join $root rtl uart_rx.sv] [file join $root rtl uart_tx.sv] \
 [file join $root rtl vector_gpu_uart_controller.sv] [file join $root rtl basys3_vector_gpu_top.sv]]
add_files -fileset constrs_1 -norecurse [file join $root constraints basys3_vector_gpu.xdc]
set_property top basys3_vector_gpu_top [get_filesets sources_1]
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_utilization -file [file join $out final_gpu_postroute_utilization.rpt]
report_timing_summary -file [file join $out final_gpu_timing_summary.rpt]
report_timing -max_paths 10 -file [file join $out final_gpu_worst_paths.rpt]
close_project
puts "FINAL_GPU_IMPL_COMPLETE"
