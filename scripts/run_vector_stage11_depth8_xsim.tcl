set root [file normalize .]
set out [file normalize .stage11_depth8_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim  [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
set sources [list [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] [file join $root rtl vector_extended_lookahead_program_core.sv] [file join $root tb vector_extended_lookahead_program_core_tb.sv]]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib {*}$sources
exec $xelab -debug typical -relax -generic_top LOOKAHEAD_DEPTH=8 xil_defaultlib.vector_extended_lookahead_program_core_tb -s vector_extended_lookahead_depth8
exec $xsim vector_extended_lookahead_depth8 -runall
puts "STAGE11_DEPTH8_XSIM_COMPLETE"
