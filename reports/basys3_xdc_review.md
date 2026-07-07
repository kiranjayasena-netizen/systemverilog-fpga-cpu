# Basys 3 XDC Review

## Purpose

This report reviews `constraints/basys3.xdc` against the current `fpga_top` ports and the expected Basys 3 usage for Phase 3 pre-hardware implementation.

No physical board observations are included.

## Top-Level Ports Checked

The current FPGA top-level wrapper uses these board-facing ports:

| Port | Direction | Intended board connection |
| --- | --- | --- |
| `clk` | input | Basys 3 100 MHz board clock |
| `rst_btn` | input | One pushbutton reset input |
| `enable_sw` | input | SW0 CPU enable switch |
| `led[15:0]` | output | LD0 through LD15 debug LEDs |

The XDC only constrains these current top-level ports.

## Clock Constraint Check

`clk` is mapped to package pin `W5`, matching the standard Basys 3 100 MHz clock location used by the Digilent master XDC style. The file also creates a 10.000 ns clock constraint:

```tcl
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]
```

This is the correct timing target for a 100 MHz input clock.

## Reset Button Mapping Check

`rst_btn` is mapped to package pin `U18`, documented in this project as the centre pushbutton, BTNC. The signal is used as an active-high reset input by `fpga_top`.

## SW0 Enable Switch Mapping Check

`enable_sw` is mapped to package pin `V17`, documented as SW0. In the wrapper, this switch is combined with the slow tick pulse so that the CPU advances only when:

```text
enable_sw && slow_tick
```

## LD0-LD15 LED Mapping Check

The XDC maps `led[0]` through `led[15]` to the sixteen Basys 3 LED pins. This matches the current wrapper output width and the LED debug mapping documented in `docs/fpga_led_expected_sequence.md`.

## I/O Standard Check

All constrained ports use:

```tcl
IOSTANDARD LVCMOS33
```

This is appropriate for the Basys 3 board-level digital I/O used by the clock, switch, pushbutton and LEDs.

## Required Final Confirmation

Before programming physical hardware, the pin assignments should be checked against the official Digilent Basys 3 master XDC or schematic. This review confirms consistency with the current repository files, but it does not replace the final hardware-facing pinout check.

## Conclusion

The current `constraints/basys3.xdc` is suitable for Phase 3 pre-hardware synthesis and implementation. It constrains the expected `fpga_top` ports, uses the Basys 3 FPGA part flow, defines the 100 MHz clock constraint, and avoids unused pins.

Physical validation remains pending until the Basys 3 board is available.

