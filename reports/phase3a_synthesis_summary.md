# Phase 3A Synthesis Summary

## Target Board

Digilent Basys 3.

## FPGA Part

`xc7a35tcpg236-1`

## Top Module

`fpga_top`

## Vivado Version

TODO: Record the Vivado version used for the synthesis run.

## Synthesis Status

TODO: Not run yet. Record whether `scripts/run_vivado_synth.tcl` completed successfully.

## Main Warnings

TODO: Record the important synthesis warnings and whether each one is acceptable.

## LUT Usage

TODO: Record LUT usage from `reports/utilisation/fpga_top_synth_utilization.rpt`.

## FF Usage

TODO: Record flip-flop usage from `reports/utilisation/fpga_top_synth_utilization.rpt`.

## BRAM Usage

TODO: Record block RAM usage from `reports/utilisation/fpga_top_synth_utilization.rpt`.

## DSP Usage

TODO: Record DSP usage from `reports/utilisation/fpga_top_synth_utilization.rpt`.

## Timing Summary

TODO: Record the target clock period, worst negative slack and whether timing is met.

## Notes

- The target clock is the Basys 3 100 MHz clock.
- The Basys 3 constraints should be checked against the board documentation before programming hardware.
- Generated Vivado checkpoints, databases and bitstreams should not be committed.

## Next Steps

- Run `vivado -mode batch -source scripts/run_vivado_synth.tcl`.
- Review utilisation, timing and power reports.
- Run implementation once synthesis is clean.
- Program and physically test LEDs only after the Basys 3 board arrives and constraints have been checked.
