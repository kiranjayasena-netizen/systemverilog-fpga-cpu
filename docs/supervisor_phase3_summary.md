# Supervisor Phase 3 Summary

## Purpose Of Phase 3

Phase 3 moved the simulated SystemVerilog CPU project into an FPGA implementation flow for the Digilent Basys 3 board. The aim was to prepare the design for first hardware bring-up without changing the CPU instruction encoding or core behaviour.

The work focused on creating a board-facing wrapper, adding a simple LED debug interface, preparing Basys 3 constraints, running Vivado synthesis and implementation, and documenting the difference between pre-hardware evidence and physical board evidence.

## Completed Without The Board

The project now has a top-level FPGA wrapper, `rtl/fpga_top.sv`, which instantiates the existing CPU core and exposes only the Basys 3 clock, reset button, enable switch and sixteen LEDs. The wrapper maps useful CPU debug signals to the LEDs, including the low PC word index, opcode, selected control signals and low ALU result bits.

A small demo program, `programs/fpga_led_demo.mem`, is loaded into instruction memory for board bring-up. The expected LED behaviour is documented in `docs/fpga_led_expected_sequence.md`, so the first physical test has a clear reference sequence.

The project also includes `rtl/slow_tick_generator.sv`. This module generates a one-cycle clock-enable pulse at a human-visible rate, allowing the CPU to step slowly on LEDs while still using the real 100 MHz Basys 3 clock. This avoids creating a divided clock.

The Basys 3 constraints file, `constraints/basys3.xdc`, maps only the ports currently used by the design: clock, reset button, SW0 enable switch and LD0 through LD15. The constraints are suitable for pre-hardware implementation, with final confirmation against the official Digilent master XDC or schematic still required before board programming.

## Evidence From Simulation, Synthesis And Implementation

Simulation evidence comes from the Vivado XSim regression flow and the FPGA wrapper testbench. The wrapper simulation checks that the LED debug outputs become known and change as the CPU executes the demo program.

Synthesis evidence comes from the Vivado synthesis script and recorded Phase 3 summaries. The synthesis flow targets the Basys 3 FPGA part `xc7a35tcpg236-1`, reads the full RTL design, applies `constraints/basys3.xdc`, and generates utilisation, timing and power reports.

Implementation evidence comes from the Phase 3C routed implementation summary. Vivado completed synthesis, optimisation, placement, routing and bitstream generation for top module `fpga_top`. The generated bitstream path is `reports/bitstreams/fpga_top.bit`, but the bitstream is a local generated artifact and should not be committed to Git.

The Phase 3C resource usage was approximately 2,983 LUTs and 8,314 flip-flops on the Artix-7 device, with no BRAM or DSP usage reported. This provides an implementation baseline for later comparison.

## What Cannot Be Claimed Yet

The design has not yet been programmed onto a physical Basys 3 board. Therefore, the project cannot yet claim real hardware validation, real LED behaviour, reset button validation, enable switch validation, or board-level bring-up success.

Those claims require a physical board session using `docs/basys3_bringup_checklist.md` and recording results in `reports/phase3d_hardware_bringup_template.md`.

## Timing Result And Engineering Value

The Phase 3C routed implementation does not meet the 100 MHz setup timing target. The documented post-route WNS is -1.551 ns and TNS is -5707.315 ns, while hold timing is met.

This is useful engineering evidence rather than a failure of the project. The current CPU is intentionally simple and close to a single-cycle-style datapath. The worst timing path is consistent with a long path from program counter through instruction fetch, decode, control, execute and writeback logic into the register file. This result demonstrates why real CPU implementations often need multi-cycle control, registered memory outputs or pipelining to close timing at higher clock frequencies.

The slow tick helps make execution visible on LEDs, but it does not close the internal 100 MHz timing path because the design still uses the Basys 3 100 MHz clock for its registers.

## Direction For Final-Year Work

Phase 3 provides a strong base for the next stage of the project. The immediate next step is hardware bring-up when the Basys 3 arrives: program the board, test reset and enable behaviour, compare the observed LEDs with the expected sequence, and capture photos, video and notes.

After bring-up, the timing result can become the starting point for a timing closure investigation. Possible final-year directions include converting the CPU to a multi-cycle design, registering instruction or data memory outputs, introducing a simple pipeline, and comparing performance, timing and resource usage before and after those changes.

This creates a clear path from a working educational CPU core to a more realistic FPGA processor design study.

