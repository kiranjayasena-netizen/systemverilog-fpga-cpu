set root [file normalize .]
set out [file normalize .ai_cpu_uart_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib \
 [file join $root rtl uart_rx.sv] [file join $root rtl uart_tx.sv] \
 [file join $root rtl ai_cpu_uart_controller.sv] \
 [file join $root tb ai_cpu_uart_controller_tb.sv]
exec $xelab -debug typical -relax xil_defaultlib.ai_cpu_uart_controller_tb -s ai_uart_sim
exec $xsim ai_uart_sim -runall
puts "AI_CPU_UART_XSIM_COMPLETE"
