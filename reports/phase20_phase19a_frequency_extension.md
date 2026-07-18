# Phase 20 Phase 19A Frequency Extension

## Purpose

Phase 20E extends the proven Phase 19A route: keep the original Phase 13 forward-timing CPU unchanged and try slightly higher MMCM clocks beyond the confirmed 117 MHz / `0102` result.

## Baseline

| Item | Value |
| --- | ---: |
| CPU | Original Phase 13 forward-timing CPU |
| Previous best confirmed result | Phase 19A, approximately 102 MIPS |
| Previous confirmed clock | 117.000 MHz |
| Previous confirmed board display | `0102` |
| New best confirmed result | Phase 20E, approximately 104 MIPS |
| New confirmed clock | 119.000 MHz |
| New confirmed board display | `0104` |

## Files

Created:

- `rtl/fpga_top_phase20_phase19a_frequency_targets.sv`
- `scripts/run_vivado_impl_phase20_phase19a_117p5.tcl`
- `scripts/run_vivado_impl_phase20_phase19a_118p0.tcl`
- `scripts/run_vivado_impl_phase20_phase19a_118p5.tcl`
- `scripts/run_vivado_impl_phase20_phase19a_119p0.tcl`
- `scripts/run_vivado_impl_phase20_phase19a_120p0.tcl`

These scripts use the existing Phase 19A measurement wrapper and the original Phase 13 CPU.

## Clock Targets

| Target clock | CPU_CLOCK_HZ | MMCM DIVCLK | MMCM CLKFBOUT_MULT_F | MMCM CLKOUT0_DIVIDE_F | Expected display if CPI remains near 1.15 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 117.500 MHz | 117,500,000 | 4 | 29.375 | 6.250 | about `0102` |
| 118.000 MHz | 118,000,000 | 4 | 29.500 | 6.250 | about `0102` |
| 118.500 MHz | 118,500,000 | 4 | 29.625 | 6.250 | about `0103` |
| 119.000 MHz | 119,000,000 | 4 | 29.750 | 6.250 | about `0103` |
| 120.000 MHz | 120,000,000 | 4 | 30.000 | 6.250 | about `0104` |

## Timing And Board Results

Selective Vivado runs were completed for 117.5, 118.0, 118.5 and 119.0 MHz. Because implementation results can vary with placement and routing, lower targets are not automatically guaranteed to pass just because a later run passed.

| Target clock | WNS | TNS | WHS | THS | Bitstream | Valid for board test | Board MIPS |
| ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |
| 117.500 MHz | -0.116 ns | -1.106 ns | +0.035 ns | 0.000 ns | skipped | no | invalid |
| 118.000 MHz | -0.463 ns | -25.738 ns | +0.051 ns | 0.000 ns | skipped | no | invalid |
| 118.500 MHz | +0.004 ns | 0.000 ns | +0.035 ns | 0.000 ns | generated | yes | `0103` |
| 119.000 MHz | +0.003 ns | 0.000 ns | +0.086 ns | 0.000 ns | generated | yes | `0104` |
| 120.000 MHz | not run | not run | not run | not run | not generated | no | not tested |

The 118.5 MHz and 119.0 MHz bitstreams were physically tested on the Basys 3. The 119.0 MHz result displayed `0104`, approximately 104 MIPS, and is the best physical FPGA-measured result currently recorded in the project.

## Build Commands

```powershell
vivado -mode batch -source scripts\run_vivado_impl_phase20_phase19a_117p5.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase20_phase19a_118p0.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase20_phase19a_118p5.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase20_phase19a_119p0.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase20_phase19a_120p0.tcl
```

## Board Test Procedure

For any timing-clean generated bitstream:

1. Program the Basys 3.
2. Press and release BTNC reset.
3. Confirm LED0 is on for MMCM lock.
4. Set SW0 = 1 to run.
5. Set SW3:SW1 = `000`.
6. Wait at least two one-second measurement windows.
7. Record the 7-segment display.
8. Do not claim a new MIPS record until the board display is observed.

## Bitstreams Tested

- `reports/phase20_phase19a_frequency_extension_impl/118p5/bitstreams/fpga_top_phase20_phase19a_118p5.bit`
- `reports/phase20_phase19a_frequency_extension_impl/119p0/bitstreams/fpga_top_phase20_phase19a_119p0.bit`

## Decision

Phase 20E replaces Phase 19A as the best physical FPGA-measured project result. The CPU RTL is still the original Phase 13 forward-timing CPU; only the MMCM wrapper clock target changed.
