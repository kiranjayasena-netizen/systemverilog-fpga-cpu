# Constraints

The FPGA constraint file is board-specific. Do not copy pin locations from another board unless the package, board schematic and clock source match your hardware.

Create a real `.xdc` file only after choosing the target FPGA board. The placeholder names below show the signals that need constraints, but they are not real pin locations.

```tcl
## Clock input
set_property PACKAGE_PIN <CLOCK_PIN> [get_ports clk]
set_property IOSTANDARD <IO_STANDARD> [get_ports clk]
create_clock -period <CLOCK_PERIOD_NS> -name sys_clk [get_ports clk]

## Reset button
set_property PACKAGE_PIN <RESET_BUTTON_PIN> [get_ports rst_btn]
set_property IOSTANDARD <IO_STANDARD> [get_ports rst_btn]

## CPU enable switch
set_property PACKAGE_PIN <ENABLE_SWITCH_PIN> [get_ports enable_sw]
set_property IOSTANDARD <IO_STANDARD> [get_ports enable_sw]

## LEDs
set_property PACKAGE_PIN <LED0_PIN>  [get_ports {led[0]}]
set_property PACKAGE_PIN <LED1_PIN>  [get_ports {led[1]}]
set_property PACKAGE_PIN <LED2_PIN>  [get_ports {led[2]}]
set_property PACKAGE_PIN <LED3_PIN>  [get_ports {led[3]}]
set_property PACKAGE_PIN <LED4_PIN>  [get_ports {led[4]}]
set_property PACKAGE_PIN <LED5_PIN>  [get_ports {led[5]}]
set_property PACKAGE_PIN <LED6_PIN>  [get_ports {led[6]}]
set_property PACKAGE_PIN <LED7_PIN>  [get_ports {led[7]}]
set_property PACKAGE_PIN <LED8_PIN>  [get_ports {led[8]}]
set_property PACKAGE_PIN <LED9_PIN>  [get_ports {led[9]}]
set_property PACKAGE_PIN <LED10_PIN> [get_ports {led[10]}]
set_property PACKAGE_PIN <LED11_PIN> [get_ports {led[11]}]
set_property PACKAGE_PIN <LED12_PIN> [get_ports {led[12]}]
set_property PACKAGE_PIN <LED13_PIN> [get_ports {led[13]}]
set_property PACKAGE_PIN <LED14_PIN> [get_ports {led[14]}]
set_property PACKAGE_PIN <LED15_PIN> [get_ports {led[15]}]
set_property IOSTANDARD <IO_STANDARD> [get_ports {led[*]}]
```

Recommended process:

1. Pick the FPGA board.
2. Read the board schematic and vendor master XDC.
3. Fill in the clock, reset, switch and LED pins.
4. Run synthesis and implementation.
5. Only generate or use a bitstream after the constraints match the actual board.
