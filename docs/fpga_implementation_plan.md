# FPGA Implementation Plan

## Goal

Phase 3A prepares the simulated CPU core for a first FPGA build. The goal is not to add new CPU instructions or change behaviour. The goal is to wrap the existing CPU core in a board-facing top level, define the expected constraint structure, and provide simple Vivado scripts for synthesis and implementation.

## FPGA Top-Level Wrapper

File: `rtl/fpga_top.sv`

The FPGA wrapper instantiates the existing `cpu_core` and exposes only simple board-level ports:

- `clk`: board clock input.
- `rst_btn`: active-high reset button.
- `enable_sw`: switch used as the CPU enable.
- `led[15:0]`: debug LED outputs.

The wrapper loads `programs/fpga_led_demo.mem` through the CPU instruction memory init-file parameter. The CPU core itself is not modified.

## LED Debug Mapping

The 16 LEDs are mapped to debug signals that are useful during first hardware bring-up:

| LED bits | Signal | Purpose |
| --- | --- | --- |
| `led[3:0]` | `pc[5:2]` | Shows low instruction-word address bits |
| `led[7:4]` | `opcode` | Shows the current instruction opcode |
| `led[8]` | `valid_instr` | High for recognised instructions |
| `led[9]` | `reg_write` | High when the CPU writes a register |
| `led[10]` | `use_imm` | High when the ALU uses the immediate operand |
| `led[13:11]` | `alu_op` | Shows the selected ALU operation |
| `led[15:14]` | `alu_result[1:0]` | Shows two low ALU result bits |

This mapping is intentionally simple. It gives visible activity without adding a UART, display controller or debug bus.

## FPGA LED Demo Program

File: `programs/fpga_led_demo.mem`

The demo program is a short loop designed to make PC and opcode changes visible when `enable_sw` is pulsed or switched on:

```text
60800001  ADDI x1, x0, 1
61000002  ADDI x2, x0, 2
11844000  ADD  x3, x1, x2
52044000  XOR  x4, x1, x2
90044002  BEQ  x1, x2, +2    ; not taken
62800007  ADDI x5, x0, 7
A0001FFA  JUMP -6            ; loop back to the first instruction
00000000  NOP                ; spare word
```

The branch is intentionally not taken because `x1` and `x2` contain different values. The JUMP loops back to the start so the demo keeps cycling.

The expected LED sequence for this program is documented in [FPGA LED expected sequence](fpga_led_expected_sequence.md).

## Constraints

The target board for Phase 3A is the Digilent Basys 3, using FPGA part `xc7a35tcpg236-1`. The board-specific constraints live in `constraints/basys3.xdc` and cover only the current top-level ports:

- `clk`: 100 MHz Basys 3 board clock.
- `rst_btn`: centre pushbutton reset.
- `enable_sw`: SW0 CPU enable switch.
- `led[15:0]`: LD0 through LD15 debug outputs.

Use the board schematic or vendor-provided master constraint file when changing this file. Do not invent pin locations or add unused pins.

See `constraints/README.md` for a placeholder template covering:

- clock input
- reset button
- enable switch
- 16 LEDs

## Running Synthesis

Run from the repository root:

```powershell
vivado -mode batch -source scripts/run_vivado_synth.tcl
```

The script writes reports into:

- `reports/utilisation/`
- `reports/timing/`
- `reports/power/`

It also writes a synthesis checkpoint under `reports/checkpoints/`. Generated checkpoints are ignored by Git.

Use `reports/phase3a_synthesis_summary.md` to record the selected synthesis results that are worth keeping for project documentation.

## Running Implementation

Only run implementation after the board-specific constraints are correct:

```powershell
vivado -mode batch -source scripts/run_vivado_impl.tcl
```

The implementation script runs synthesis, optimisation, placement and routing. It writes implementation reports and a bitstream. The bitstream should only be used on hardware after checking the XDC against the actual board.

## Work Completed Without Physical FPGA

The repository can now complete most Phase 3A preparation before the Basys 3 board arrives:

- The FPGA wrapper exists and instantiates the already-tested `cpu_core`.
- The wrapper has a self-checking simulation in `tb/fpga_top_tb.sv`.
- The Basys 3 FPGA part is set to `xc7a35tcpg236-1` in the synthesis and implementation scripts.
- `constraints/basys3.xdc` maps only the required clock, reset button, enable switch and LEDs.
- Vivado synthesis and implementation can be run before hardware arrives to check RTL compile, constraints parsing, resource usage and timing.
- `reports/phase3a_synthesis_summary.md` provides a place to record selected text results.

Physical LED behaviour still must wait until the Basys 3 board arrives. Before using the bitstream on hardware, check the XDC against the Basys 3 schematic and the Digilent master XDC.

## Phase 3B Board Bring-Up Preparation

Phase 3B adds a slow CPU clock-enable path for board observation without changing `cpu_core` behaviour. The FPGA still uses the real 100 MHz Basys 3 clock. A `slow_tick_generator` creates a single-cycle enable pulse at a human-visible rate, and `fpga_top` advances the CPU only when both `enable_sw` and the slow tick are high.

This keeps the design synchronous to one clock while allowing the LED debug mapping to change slowly enough to observe on hardware. The divider is parameterised so testbenches can use a small value for fast simulation while the FPGA default remains suitable for visible LED stepping.

The Phase 3B slow-tick wrapper synthesis result is recorded in `reports/phase3b_slow_tick_synthesis_summary.md`.

The Phase 3C routed implementation and bitstream-generation result is recorded in `reports/phase3c_implementation_summary.md`.

## Acceptance Criteria

Phase 3A is complete when:

- `rtl/fpga_top.sv` instantiates `cpu_core` without modifying CPU behaviour.
- `programs/fpga_led_demo.mem` exists and is documented.
- Basys 3 constraints exist for the clock, reset button, enable switch and LEDs.
- Vivado synthesis can be launched for `xc7a35tcpg236-1`.
- Utilisation, timing and power report paths are defined.
- Implementation and bitstream generation are scripted, with clear warnings about requiring correct constraints.
- No generated Vivado output folders or large binary files are committed.
