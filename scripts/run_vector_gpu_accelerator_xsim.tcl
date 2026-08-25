set root [file normalize .]
set out [file normalize .vector_gpu_accelerator_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
set sources [list [file join $root rtl vector_register_file.sv] [file join $root rtl vector_alu.sv] [file join $root rtl vector_execution_unit.sv] [file join $root rtl vector_instruction_memory.sv] [file join $root rtl vector_memory_instruction_decoder.sv] [file join $root rtl vector_data_memory.sv] [file join $root rtl vector_load_overlap_program_core.sv] [file join $root rtl vector_gpu_accelerator.sv] [file join $root tb vector_gpu_accelerator_tb.sv]]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib {*}$sources
exec $xelab -debug typical -relax xil_defaultlib.vector_gpu_accelerator_tb -s vector_gpu_accelerator
exec $xsim vector_gpu_accelerator -runall
puts "VECTOR_GPU_ACCELERATOR_XSIM_COMPLETE"
