set root [file normalize .]
set out [file normalize .uart_rx_xsim]
file delete -force $out
file mkdir $out
set xvlog [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xvlog.exe]
set xelab [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xelab.exe]
set xsim [file join $::env(XILINX_VIVADO) bin unwrapped win64.o xsim.exe]
cd $out
exec $xvlog -sv -relax -work xil_defaultlib [file join $root rtl uart_rx.sv] [file join $root tb uart_rx_tb.sv]
exec $xelab -debug typical -relax xil_defaultlib.uart_rx_tb -s uart_rx_sim
exec $xsim uart_rx_sim -runall
puts "UART_RX_XSIM_COMPLETE"
