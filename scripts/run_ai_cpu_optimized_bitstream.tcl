set part xc7a35tcpg236-1
set root [file normalize .]
set out_dir [file normalize "./.ai_cpu_optimized"]
create_project -force ai_cpu_optimized $out_dir -part $part
set src [list \
  [file join $root rtl cpu_defs_pkg.sv] [file join $root rtl dot4acc_pipeline.sv] [file join $root rtl bram_instr_mem_validation.sv] [file join $root rtl bram_data_mem_validation.sv] \
  [file join $root rtl cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation.sv] [file join $root rtl ai_cpu_validation_wrapper.sv] \
  [file join $root rtl uart_rx.sv] [file join $root rtl uart_tx.sv] [file join $root rtl ai_cpu_uart_controller.sv] \
  [file join $root rtl basys3_ai_cpu_validation_top.sv]]
add_files -norecurse $src
add_files -fileset constrs_1 -norecurse [file join $root constraints basys3_ai_cpu_validation.xdc]
set_property top basys3_ai_cpu_optimized_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} { error "optimized synthesis failed" }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} { error "optimized implementation failed" }
file copy -force [file join $out_dir ai_cpu_optimized.runs impl_1 basys3_ai_cpu_optimized_top.bit] [file join $out_dir ai_cpu_optimized.bit]
open_run impl_1
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing.rpt]
puts "AI_CPU_OPTIMIZED_BITSTREAM_COMPLETE"
