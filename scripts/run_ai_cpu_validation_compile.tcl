set root [file normalize .]
set opt [expr {[info exists ::env(AI_CPU_OPT)] && $::env(AI_CPU_OPT) eq "1"}]
if {$opt} {
  set top basys3_ai_cpu_optimized_top
  set core cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation.sv
  set extra [list [file join $root rtl dot4acc_pipeline.sv]]
} else {
  set top basys3_ai_cpu_baseline_top
  set core cpu_core_pipeline_timingopt_validation.sv
  set extra [list]
}
set files [concat [list [file join $root rtl cpu_defs_pkg.sv] [file join $root rtl bram_instr_mem_validation.sv] [file join $root rtl bram_data_mem_validation.sv] [file join $root rtl $core] [file join $root rtl ai_cpu_validation_wrapper.sv] [file join $root rtl uart_rx.sv] [file join $root rtl uart_tx.sv] [file join $root rtl ai_cpu_uart_controller.sv] [file join $root rtl basys3_ai_cpu_validation_top.sv]] $extra]
read_verilog -sv $files
read_xdc [file join $root constraints basys3_ai_cpu_validation.xdc]
synth_design -top $top -part xc7a35tcpg236-1
puts "AI_CPU_VALIDATION_COMPILE_COMPLETE $top"
