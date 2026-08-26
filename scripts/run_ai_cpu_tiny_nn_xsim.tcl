set root [file normalize .]
set out [file normalize .ai_cpu_tiny_nn_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib \
  [file join $root rtl cpu_defs_pkg.sv] \
  [file join $root rtl dot4acc_pipeline.sv] \
  [file join $root rtl bram_instr_mem_validation.sv] \
  [file join $root rtl bram_data_mem_validation.sv] \
  [file join $root rtl cpu_core_pipeline_timingopt_validation.sv] \
  [file join $root rtl cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation.sv] \
  [file join $root rtl ai_cpu_validation_wrapper.sv] \
  [file join $root tb ai_cpu_tiny_nn_e2e_tb.sv]
exec $xelab -debug typical -relax xil_defaultlib.ai_cpu_tiny_nn_e2e_tb -s tiny_nn_sim
exec $xsim tiny_nn_sim -runall
puts "AI_TINY_NN_XSIM_COMPLETE"
