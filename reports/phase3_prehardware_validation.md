# Phase 3 Pre-Hardware Validation Report

## Purpose

This report summarises what has been completed for Phase 3 before access to the physical Digilent Basys 3 FPGA board. It records the evidence already available from simulation, Vivado synthesis and Vivado implementation, and separates that evidence from work that still requires real hardware.

The report is intentionally limited to pre-hardware validation. It does not claim that the design has been programmed onto a Basys 3 board or observed on physical LEDs.

## Current Phase 3 Status

Phase 3 has reached a pre-hardware implementation baseline for the Basys 3 target:

- Target board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- FPGA clock: Basys 3 100 MHz clock
- CPU stepping: clock-enable pulse from `slow_tick_generator`
- CPU enable condition: `enable_sw && slow_tick`

Vivado synthesis, placement, routing and bitstream generation have completed for `fpga_top`. The routed design does not meet the 100 MHz timing constraint, so the current result should be treated as a board bring-up baseline rather than final timing closure.

## Completed Without The FPGA

The following items have been completed using RTL, simulation and Vivado build tools only:

- `rtl/fpga_top.sv` wraps the existing `cpu_core` for the Basys 3-facing top level.
- `constraints/basys3.xdc` maps the top-level ports to the Basys 3 100 MHz clock, reset button, SW0 enable switch and 16 LEDs.
- The LED debug mapping exposes PC bits, opcode, key control signals, ALU operation and low ALU result bits.
- `programs/fpga_led_demo.mem` provides a small looping instruction program for LED debug bring-up.
- `tb/fpga_top_tb.sv` simulates the wrapper and checks that LED outputs become known and change while the CPU is enabled.
- Vivado synthesis has passed for `xc7a35tcpg236-1`.
- Vivado implementation has passed through optimisation, placement and routing.
- Timing analysis has been recorded at synthesis and implementation stages.
- Resource usage analysis has been recorded.
- Bitstream generation has completed locally for `reports/bitstreams/fpga_top.bit`.

The generated bitstream is a local build artifact and should not be committed.

## Evidence Categories

### Simulation Evidence

Simulation evidence comes from Vivado XSim testbenches. The relevant Phase 3 simulation result is the FPGA wrapper testbench:

- `tb/fpga_top_tb.sv` passed.
- The test confirms that `led[15:0]` is driven to known values.
- The test confirms that LED debug output changes after the CPU is enabled.
- The test confirms the slow-tick wrapper can be simulated using a reduced divider value.

This is functional simulation evidence. It does not prove physical LED behaviour, switch behaviour, button behaviour or board-level electrical behaviour.

### Synthesis And Implementation Evidence

Synthesis and implementation evidence comes from Vivado reports:

- Phase 3B synthesis summary: `reports/phase3b_slow_tick_synthesis_summary.md`
- Phase 3C implementation summary: `reports/phase3c_implementation_summary.md`

The Phase 3C routed implementation completed with:

- Slice LUTs: 2,983 / 20,800, 14.34%
- Slice registers: 8,314 / 41,600, 19.99%
- Block RAM tiles: 0 / 50, 0.00%
- DSPs: 0 / 90, 0.00%
- Post-route WNS: -1.551 ns
- Post-route TNS: -5707.315 ns
- Worst hold slack: 0.075 ns
- Total on-chip power estimate: 0.081 W
- Bitstream generation: passed

The implementation result proves that the current design can be built for the Basys 3 part and that Vivado can generate a bitstream. It does not prove that the design behaves correctly on the physical board.

### Pending Hardware Evidence

The following items cannot be claimed until the physical Basys 3 board is available and tested:

- Physical board programming.
- Real LED behaviour on the Basys 3.
- Reset button behaviour on the board.
- Enable switch behaviour on the board.
- Real hardware bring-up.
- Any statement that the CPU has executed correctly in physical FPGA hardware.

## Pre-Hardware Evidence Summary

| Area | Evidence Available | Status | Limitation |
| --- | --- | --- | --- |
| FPGA wrapper | `rtl/fpga_top.sv` | Complete pre-hardware | Not yet observed on physical pins |
| Basys 3 constraints | `constraints/basys3.xdc` | Complete pre-hardware | Pins should still be checked against the physical board documentation before programming |
| LED debug mapping | `fpga_top` LED assignments and documentation | Complete pre-hardware | LED behaviour not physically observed |
| Demo program | `programs/fpga_led_demo.mem` | Complete pre-hardware | Program has not been observed running on the board |
| Wrapper simulation | `tb/fpga_top_tb.sv` | Passed in XSim | Simulation is not hardware validation |
| Synthesis | Phase 3B synthesis report | Passed | Post-synthesis timing was not closed at 100 MHz |
| Implementation | Phase 3C implementation report | Passed | Post-route setup timing is not met at 100 MHz |
| Timing analysis | Phase 3B and Phase 3C timing summaries | Complete pre-hardware | Timing improvement remains future work |
| Resource usage | Synthesis and implementation reports | Complete pre-hardware | Resource use may change after future design changes |
| Bitstream generation | `reports/bitstreams/fpga_top.bit` generated locally | Passed | Bitstream has not been programmed onto hardware |

## What Cannot Be Claimed Yet

At this stage, the project can claim that the Basys 3 wrapper has passed simulation and that Vivado can synthesize, implement and generate a bitstream for the target part.

It cannot yet claim:

- the Basys 3 has been programmed,
- the LEDs show the expected debug pattern on real hardware,
- the reset button has been validated on the board,
- the enable switch has been validated on the board,
- hardware bring-up is complete, or
- the CPU has been physically validated on FPGA hardware.

## Recommended Next Step

When the Basys 3 board arrives:

1. Recheck `constraints/basys3.xdc` against the Digilent Basys 3 master XDC and board documentation.
2. Open Vivado Hardware Manager and connect to the board.
3. Program the FPGA with the locally generated `reports/bitstreams/fpga_top.bit`.
4. Use SW0 as the CPU enable input.
5. Use the mapped reset button to reset the design.
6. Observe `led[15:0]` for slow debug-state changes.
7. Record the outcome in a hardware bring-up report, including any photos, notes or unexpected behaviour.

The first hardware test should be described as board bring-up, not final timing closure, because the Phase 3C routed design does not meet the 100 MHz setup timing constraint.
