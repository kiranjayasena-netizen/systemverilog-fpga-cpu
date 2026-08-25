set root [file normalize .]
set out [file normalize .stage12_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim  [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
set sources [list [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] [file join $root rtl vector_two_outstanding_prefetch_program_core.sv] [file join $root tb vector_two_outstanding_prefetch_program_core_tb.sv]]
cd $out
if {[catch {exec $xvlog -sv -relax -work xil_defaultlib {*}$sources} msg]} { puts $msg; exit 1 }
if {[catch {exec $xelab -debug typical -relax -generic_top LOOKAHEAD_DEPTH=6 xil_defaultlib.vector_two_outstanding_prefetch_program_core_tb -s vector_stage12} msg]} { puts $msg; exit 1 }
if {[catch {exec $xsim vector_stage12 -runall} msg]} { puts $msg; exit 1 }
puts "STAGE12_XSIM_COMPLETE"
