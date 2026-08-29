set repo [file normalize [file join [file dirname [file normalize [info script]]] ".."]]
set out [expr {[info exists ::env(STAGE31_BUILD_ROOT)] ? [file normalize $::env(STAGE31_BUILD_ROOT)] : [file join $repo ".ai_cpu_stage31_optimized"]}]
file mkdir $out
set part xc7a35tcpg236-1
read_verilog -sv [list \
  [file join $repo rtl cpu_defs_pkg.sv] [file join $repo rtl dot4acc_pipeline.sv] [file join $repo rtl bram_instr_mem_validation.sv] [file join $repo rtl bram_data_mem_validation.sv] \
  [file join $repo rtl cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation.sv] [file join $repo rtl ai_cpu_validation_wrapper.sv] \
  [file join $repo rtl uart_rx.sv] [file join $repo rtl uart_tx.sv] [file join $repo rtl ai_cpu_uart_controller.sv] \
  [file join $repo rtl basys3_ai_cpu_validation_top.sv]]
read_xdc [file join $repo constraints basys3_ai_cpu_validation.xdc]
synth_design -top basys3_ai_cpu_stage31_optimized_top -part $part
write_checkpoint -force [file join $out optimized_post_synth.dcp]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file [file join $out timing.rpt]
report_utilization -file [file join $out utilization.rpt]
write_checkpoint -force [file join $out optimized_post_route.dcp]
write_bitstream -force [file join $out ai_cpu_stage31_optimized.bit]
puts "AI_CPU_STAGE31_OPTIMIZED_DIRECT_COMPLETE"
