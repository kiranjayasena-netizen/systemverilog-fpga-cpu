# Phase 3 Vivado Script Review

## Purpose

This report reviews the Phase 3 Vivado synthesis and implementation scripts before physical Basys 3 hardware testing. The goal is to confirm that the scripted FPGA flow is complete enough for pre-hardware synthesis, implementation, timing analysis and bitstream generation.

This review does not change RTL behaviour.

## Scripts Reviewed

| File | Purpose | Review result |
| --- | --- | --- |
| `scripts/run_vivado_synth.tcl` | Runs the Basys 3 synthesis flow for `fpga_top` | Complete for pre-hardware synthesis |
| `scripts/run_vivado_impl.tcl` | Runs synthesis, optimisation, placement, routing and bitstream generation | Complete for pre-hardware implementation |
| `constraints/basys3.xdc` | Provides Basys 3 clock, reset, enable switch and LED constraints | Suitable for the current top-level ports |

## Synthesis Script

`scripts/run_vivado_synth.tcl` is configured for:

- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Constraints file: `constraints/basys3.xdc`

The script reads all current RTL files in a valid order, with `rtl/cpu_defs_pkg.sv` loaded before modules that import the package. It includes the CPU datapath modules, `slow_tick_generator`, and the FPGA top-level wrapper.

The script produces:

- Synthesis utilisation report: `reports/utilisation/fpga_top_synth_utilization.rpt`
- Synthesis timing summary: `reports/timing/fpga_top_synth_timing_summary.rpt`
- Detailed worst-path timing report: `reports/timing/fpga_top_synth_worst_paths.rpt`
- Synthesis power report: `reports/power/fpga_top_synth_power.rpt`
- Synthesis checkpoint: `reports/checkpoints/fpga_top_synth.dcp`

The checkpoint has a `.dcp` extension and is ignored by the repository `.gitignore`.

## Implementation Script

`scripts/run_vivado_impl.tcl` is configured for:

- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Constraints file: `constraints/basys3.xdc`

The script runs:

- `synth_design`
- `opt_design`
- `place_design`
- `route_design`

The script produces:

- Implementation utilisation report: `reports/utilisation/fpga_top_impl_utilization.rpt`
- Implementation timing summary: `reports/timing/fpga_top_impl_timing_summary.rpt`
- Detailed implementation worst-path timing report: `reports/timing/fpga_top_impl_worst_paths.rpt`
- Implementation power report: `reports/power/fpga_top_impl_power.rpt`
- Implementation checkpoint: `reports/checkpoints/fpga_top_impl.dcp`
- Bitstream: `reports/bitstreams/fpga_top.bit`

The checkpoint and bitstream use ignored file extensions, so they should remain local generated outputs unless explicitly selected for archival outside Git.

## Pre-Hardware Completeness

The scripts are sufficient for the current Phase 3 pre-hardware work:

- RTL compilation for the FPGA top-level wrapper.
- Basys 3 part selection.
- Basys 3 constraints loading.
- Synthesis, implementation, routing and bitstream generation.
- Resource usage reporting.
- Timing summary and detailed worst-path timing analysis.
- Power reporting.

No obvious missing script step was found during this review.

## What Still Requires Physical Hardware

The scripts cannot prove:

- The Basys 3 board is detected by Vivado Hardware Manager.
- The generated bitstream programs successfully onto the physical board.
- The reset button behaves correctly on the real board.
- The enable switch behaves correctly on the real board.
- The LED sequence matches the expected pattern on physical hardware.
- The board-level bring-up evidence has been captured.

These items should be checked using `docs/basys3_bringup_checklist.md` when the board is available.

## Recommended Future Improvements

- Add a small Tcl wrapper that records the Vivado version and date into a generated build summary.
- Add optional command-line parameters for FPGA part, top module and XDC file if the project later supports more boards.
- Add CI-friendly syntax checks if a Vivado-capable runner becomes available.
- Keep raw Vivado output files out of Git, and continue recording only selected summary reports in Markdown.

