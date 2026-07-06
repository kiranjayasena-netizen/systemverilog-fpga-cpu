# Phase 3A Synthesis Summary

## Target Board

Digilent Basys 3.

## FPGA Part

`xc7a35tcpg236-1`

## Top Module

`fpga_top`

## Vivado Version

Vivado v2026.1, run on July 6, 2026.

## Synthesis Status

Passed.

Command run:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_synth.tcl
```

Vivado completed `synth_design`, generated utilisation, timing and power reports, and wrote the synthesis checkpoint. The run ended with 0 errors and 0 critical warnings.

## Main Warnings

- `addr[1:0]` on instruction and data memory is reported as unconnected or having no load. This is expected because both memories are word-addressed using `addr[31:2]`.
- Some XDC implementation-specific constraints are ignored during synthesis and kept for implementation. This is expected for package pin constraints.
- Vivado reports that the synthesized `data_memory` cell view has many primitives and is not ideal for floorplanning. This is not a functional error, but it is a useful note for later memory optimisation.

## LUT Usage

2,819 / 20,800 Slice LUTs, 13.55%.

## FF Usage

8,286 / 41,600 slice registers, 19.92%.

## BRAM Usage

0 / 50 Block RAM tiles, 0.00%.

## DSP Usage

0 / 90 DSPs, 0.00%.

## Timing Summary

- Target clock: 10.000 ns, 100 MHz, `sys_clk_pin`.
- Worst negative slack: -2.017 ns.
- Total negative slack: -16592.328 ns.
- Setup failing endpoints: 8,256.
- Hold timing: met, worst hold slack 0.070 ns.
- Result: timing is not met at the post-synthesis timing estimate.

The worst reported setup path is from the program counter to data memory write-enable logic. This is consistent with the current simple single-cycle-style datapath and should be reviewed before final hardware timing closure.

## Notes

- The target clock is the Basys 3 100 MHz clock.
- The Basys 3 constraints should be checked against the board documentation before programming hardware.
- Estimated total on-chip power is 0.103 W: 0.031 W dynamic and 0.072 W device static.
- Power confidence is medium because the design is synthesized only, not placed/routed, and no simulation activity file was provided.
- Generated Vivado checkpoints, databases and bitstreams should not be committed.

## Next Steps

- Investigate the 100 MHz timing miss before treating Phase 3A timing as closed.
- Consider whether the data memory implementation should infer BRAM or whether the CPU needs a slower/multi-cycle memory path later.
- Run implementation only after deciding whether to accept this first synthesis result as a baseline.
- Program and physically test LEDs only after the Basys 3 board arrives and constraints have been checked.
