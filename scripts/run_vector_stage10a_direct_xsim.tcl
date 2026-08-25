set root [file normalize .]
set out [file normalize .stage10a_direct_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim  [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
set sources [list [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] [file join $root rtl vector_dual_prefetch_program_core.sv] [file join $root tb vector_dual_prefetch_program_core_tb.sv]]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib {*}$sources
exec $xelab -debug typical -relax xil_defaultlib.vector_dual_prefetch_program_core_tb -s vector_stage10a_direct
exec $xsim vector_stage10a_direct -runall
puts "STAGE10A_DIRECT_XSIM_COMPLETE"
