# Phase 19A Phase 17E Frequency Sweep

## Purpose

Phase 19A pushes the existing Phase 17E five-stage Phase 13 hardware result beyond the confirmed 115.000 MHz / `0100` MIPS board result.

This phase keeps the original Phase 13 forward-timing CPU RTL unchanged and creates separate MMCM wrapper targets for small clock increases.

## Baseline

| Item | Value |
| --- | ---: |
| CPU | Original Phase 13 forward-timing five-stage pipeline |
| Existing physical result | Phase 17E, `0100` MIPS |
| Existing CPU clock | 115.000 MHz |
| Board-implied CPI | approximately 1.15 |
| Benchmark/program | FPGA demo workload used by Phase 17E |

## Files

Created wrapper files:

- `rtl/fpga_top_phase19a_forwardtiming_mmcm_mips.sv`
- `rtl/fpga_top_phase19a_forwardtiming_mmcm_targets.sv`

Created Vivado scripts:

- `scripts/run_vivado_impl_phase19a_forwardtiming_mmcm_115p5.tcl`
- `scripts/run_vivado_impl_phase19a_forwardtiming_mmcm_116p0.tcl`
- `scripts/run_vivado_impl_phase19a_forwardtiming_mmcm_116p5.tcl`
- `scripts/run_vivado_impl_phase19a_forwardtiming_mmcm_117p0.tcl`

Common implementation helper:

- `scripts/run_vivado_impl_phase19_mmcm_common.tcl`

## Clocking

The Phase 19A wrappers use an RTL-instantiated MMCM driven from the Basys 3 100 MHz input clock. The CPU MIPS counter uses a one-second measurement window whose `CPU_CLOCK_HZ` parameter matches the target generated clock.

| Target clock | CPU_CLOCK_HZ | MMCM DIVCLK | MMCM CLKFBOUT_MULT_F | MMCM CLKOUT0_DIVIDE_F |
| ---: | ---: | ---: | ---: | ---: |
| 115.500 MHz | 115,500,000 | 4 | 28.875 | 6.250 |
| 116.000 MHz | 116,000,000 | 4 | 29.000 | 6.250 |
| 116.500 MHz | 116,500,000 | 4 | 29.125 | 6.250 |
| 117.000 MHz | 117,000,000 | 4 | 29.250 | 6.250 |

## Timing Sweep Result

All four Phase 19A targets routed with clean setup and hold timing and generated bitstreams.

| Target clock | Period | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Bitstream | Board MIPS |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | ---: |
| 115.500 MHz | 8.658 ns | +0.015 ns | 0.000 ns | +0.034 ns | 0.000 ns | 1,831 | 2,073 | 1 tile / 2 RAMB18 | 0 | generated | not recorded |
| 116.000 MHz | 8.621 ns | +0.062 ns | 0.000 ns | +0.035 ns | 0.000 ns | 1,824 | 2,070 | 1 tile / 2 RAMB18 | 0 | generated | not recorded |
| 116.500 MHz | 8.584 ns | +0.013 ns | 0.000 ns | +0.094 ns | 0.000 ns | 1,847 | 2,073 | 1 tile / 2 RAMB18 | 0 | generated | not recorded |
| 117.000 MHz | 8.547 ns | +0.016 ns | 0.000 ns | +0.114 ns | 0.000 ns | 1,826 | 2,072 | 1 tile / 2 RAMB18 | 0 | generated | `0102` |

Expected display is based on the Phase 17B/17E board CPI of approximately 1.15:

```text
expected MIPS = generated clock MHz / 1.15
```

The 117.000 MHz bitstream has now been physically tested and displayed `0102`. The other Phase 19A bitstreams remain timing-clean candidates unless separately tested.

## Confirmed Board Observation

| Item | Value |
| --- | ---: |
| Tested bitstream | `reports/phase19a_frequency_sweep_impl/117p0/bitstreams/fpga_top_phase19a_forwardtiming_mmcm_117p0.bit` |
| CPU clock | 117.000 MHz |
| Display mode | SW3:SW1 = `000` |
| Observed 7-seg value | `0102` |
| Interpretation | approximately 102 MIPS |

This is the best physical FPGA-measured result currently recorded in the project. The 7-segment display reports integer MIPS, so the result should be stated as approximately 102 MIPS.

## Bitstreams Valid For Board Testing

- `reports/phase19a_frequency_sweep_impl/115p5/bitstreams/fpga_top_phase19a_forwardtiming_mmcm_115p5.bit`
- `reports/phase19a_frequency_sweep_impl/116p0/bitstreams/fpga_top_phase19a_forwardtiming_mmcm_116p0.bit`
- `reports/phase19a_frequency_sweep_impl/116p5/bitstreams/fpga_top_phase19a_forwardtiming_mmcm_116p5.bit`
- `reports/phase19a_frequency_sweep_impl/117p0/bitstreams/fpga_top_phase19a_forwardtiming_mmcm_117p0.bit`

## Board Test Procedure

For each valid bitstream:

1. Program the Basys 3.
2. Press and release BTNC reset.
3. Confirm LED0 is on for MMCM lock.
4. Set SW0 = 1 to run.
5. Set SW3:SW1 = `000` for MIPS mode.
6. Wait at least two one-second measurement windows.
7. Record the 7-segment display.
8. If available, record CPI x100 and control-flush modes.
9. Take photo/video evidence.

## Interpretation

Phase 19A produced timing-clean candidates up to 117.000 MHz for the original Phase 13 CPU path. The 117.000 MHz board test displayed `0102`, making Phase 19A the current best real FPGA-measured result.
