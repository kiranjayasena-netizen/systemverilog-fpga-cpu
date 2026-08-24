set root [file normalize .]
set out [file normalize .vector_gpu_uart_readback_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib [file join $root rtl uart_rx.sv] [file join $root rtl uart_tx.sv] [file join $root rtl vector_gpu_uart_controller.sv] [file join $root tb vector_gpu_uart_readback_tb.sv]
exec $xelab -debug typical -relax xil_defaultlib.vector_gpu_uart_readback_tb -s uart_readback_sim
exec $xsim uart_readback_sim -runall
puts "VECTOR_GPU_UART_READBACK_XSIM_COMPLETE"
