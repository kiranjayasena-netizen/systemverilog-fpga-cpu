# Phase 3 Build Reproducibility

## Purpose

This report records the information needed to reproduce the Phase 3 Basys 3 synthesis and implementation builds from the repository.

Physical board validation is still pending.

## Tool And Target

| Item | Value |
| --- | --- |
| Vivado version used by the project | Vivado 2026.1 |
| Target board | Digilent Basys 3 |
| Target FPGA part | `xc7a35tcpg236-1` |
| Top module | `fpga_top` |
| Constraints file | `constraints/basys3.xdc` |

## Commands

Run synthesis from the repository root:

```powershell
vivado -mode batch -source scripts/run_vivado_synth.tcl
```

Run implementation from the repository root:

```powershell
vivado -mode batch -source scripts/run_vivado_impl.tcl
```

On the local machine used for the Phase 3C run, Vivado was also available at:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat
```

## Expected Generated Reports

Synthesis produces:

- `reports/utilisation/fpga_top_synth_utilization.rpt`
- `reports/timing/fpga_top_synth_timing_summary.rpt`
- `reports/timing/fpga_top_synth_worst_paths.rpt`
- `reports/power/fpga_top_synth_power.rpt`
- `reports/checkpoints/fpga_top_synth.dcp`

Implementation produces:

- `reports/utilisation/fpga_top_impl_utilization.rpt`
- `reports/timing/fpga_top_impl_timing_summary.rpt`
- `reports/timing/fpga_top_impl_worst_paths.rpt`
- `reports/power/fpga_top_impl_power.rpt`
- `reports/checkpoints/fpga_top_impl.dcp`

## Expected Bitstream Path

The implementation script writes:

```text
reports/bitstreams/fpga_top.bit
```

The bitstream is a generated build artifact. It is ignored by Git and should not be committed.

## Known Phase 3C Timing Result

The documented Phase 3C routed implementation result is:

- Target clock: 10.000 ns, 100 MHz
- Setup timing: not met
- Post-route WNS: -1.551 ns
- Post-route TNS: -5707.315 ns
- Hold timing: met

This timing miss is expected for the current simple single-cycle-style CPU datapath. The slow tick supports LED-visible stepping, but it does not close the internal 100 MHz setup timing path.

## Pending Hardware Validation

The build can be reproduced and a bitstream can be generated before the board arrives, but the following remain pending:

- Programming the Basys 3 board.
- Confirming reset button behaviour on hardware.
- Confirming SW0 enable switch behaviour on hardware.
- Observing and recording the real LED sequence.
- Capturing photos, video and notes as hardware evidence.

