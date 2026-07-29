# Basys 3 Constraints

[`basys3.xdc`](basys3.xdc) contains the project constraints for the Digilent
Basys 3 and the Artix-7 `xc7a35tcpg236-1` device.

The file constrains the 100 MHz board clock and the switches, buttons, LEDs
and seven-segment display used by the FPGA wrappers. Individual implementation
scripts may add generated-clock constraints for their MMCM configuration.

Before implementation:

1. Confirm that the selected top-level module uses the port names expected by
   `basys3.xdc`.
2. Confirm that the Vivado project targets `xc7a35tcpg236-1`.
3. Run `report_clocks` and `report_timing_summary` after implementation.
4. Check setup and hold timing and confirm that no important paths are
   unconstrained.
5. Generate and use a bitstream only after these checks pass.

Do not use this file with another board or FPGA package. Obtain that board's
official master XDC and verify every pin, I/O standard and clock source first.
