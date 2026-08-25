set root [file normalize .]; set out [file normalize .ai_cpu_baseline_eq_xsim]
file delete -force $out; file mkdir $out; set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]; set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]; set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]; cd $out
exec $xvlog -sv -relax -work xil_defaultlib [file join $root rtl cpu_defs_pkg.sv] [file join $root rtl bram_instr_mem.sv] [file join $root rtl bram_data_mem.sv] [file join $root rtl bram_instr_mem_validation.sv] [file join $root rtl bram_data_mem_validation.sv] [file join $root rtl cpu_core_pipeline_timingopt.sv] [file join $root rtl cpu_core_pipeline_timingopt_validation.sv] [file join $root tb ai_cpu_baseline_validation_equivalence_tb.sv]
exec $xelab -debug typical -relax xil_defaultlib.ai_cpu_baseline_validation_equivalence_tb -s baseline_eq
exec $xsim baseline_eq -runall
puts "AI_CPU_BASELINE_EQUIVALENCE_XSIM_COMPLETE"
