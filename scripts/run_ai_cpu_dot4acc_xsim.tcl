set root [file normalize .]
set out [file normalize .ai_cpu_dot4acc_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib \
  [file join $root rtl cpu_defs_pkg.sv] \
  [file join $root tb dot4acc_reference_pkg.sv] \
  [file join $root rtl bram_instr_mem.sv] \
  [file join $root rtl bram_data_mem.sv] \
  [file join $root rtl dot4acc_pipeline.sv] \
  [file join $root rtl cpu_core_pipeline_mac8_timingopt.sv] \
  [file join $root rtl cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv] \
  [file join $root tb tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv]
exec $xelab -debug typical -relax xil_defaultlib.tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 -s ai_cpu_dot4acc_sim
exec $xsim ai_cpu_dot4acc_sim -runall
puts "AI_CPU_DOT4ACC_XSIM_COMPLETE"
