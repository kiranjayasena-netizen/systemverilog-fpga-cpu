# Phase 17D Forward-Timing Timing Sweep

## Purpose

Phase 17D checks whether the original Phase 13 forward-timing five-stage CPU can close timing above the fixed 100 MHz Basys 3 board clock. The goal is to determine whether the confirmed hardware CPI can be combined with a higher timing-clean clock for a future high-frequency hardware test.

No CPU RTL changed in this phase.

## Why The Original Phase 13 CPU

Phase 17C tested a separate direct EX-stage redirect optimisation. That copy passed focused simulation but failed 10 ns post-route timing, so it is not accepted as the preferred hardware CPU.

Phase 17D therefore returns to the original timing-clean Phase 13 forward-timing path:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`

Note: the older `fpga_top_pipeline` module instantiates the Phase 12 `cpu_core_pipeline_full` path. The actual Phase 13 forward-timing top is `fpga_top_pipeline_forwardtiming`.

## Confirmed FPGA Baseline

Phase 17A/17B hardware profiler readings at the fixed 100 MHz board clock:

| Metric | Display | Meaning |
| --- | ---: | --- |
| MIPS | `0087` | approximately 87 MIPS |
| CPI x100 | `0115` | approximately 1.15 CPI |
| Control-flush percentage x100 | `1250` | approximately 12.50% |

Performance formula:

```text
estimated MIPS = frequency_MHz / 1.15
```

Targets:

| Goal | Required frequency | Required period |
| --- | ---: | ---: |
| Reach 100 MIPS | 115.0 MHz | about 8.70 ns |
| Beat Phase 14G estimated 101.8 MIPS | 117.1 MHz | about 8.54 ns |

## Script

- `scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl`

The script targets:

- part `xc7a35tcpg236-1`
- constraints `constraints/basys3.xdc`
- top `fpga_top_pipeline_forwardtiming`
- original Phase 13 RTL

Run command:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl
```

Targeted run example:

```powershell
$env:PHASE17D_PERIODS = "8.500"
$env:PHASE17D_STRATEGIES = "fanout_opt"
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl
```

Generated outputs are written under:

- `reports/phase17d_forwardtiming_timing_sweep_impl/`

The first local 8.500 ns targeted run was performed before the output-root rename and produced generated files under:

- `reports/phase17d_forwardtiming_timing_sweep/fanout_opt_8p500ns/`

Those generated folders should not be committed wholesale.

## Timing Runs

The table combines the existing Phase 13I implementation-strategy evidence with the new Phase 17D targeted 8.500 ns run.

| Period ns | Frequency MHz | Strategy | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Pass? | Estimated MIPS |
| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 10.000 | 100.000 | not separately rerun | covered by tighter pass | covered | covered | covered | - | - | - | - | covered | 87.0 |
| 9.500 | 105.263 | not separately rerun | covered by tighter pass | covered | covered | covered | - | - | - | - | covered | 91.5 |
| 9.000 | 111.111 | not separately rerun | covered by tighter pass | covered | covered | covered | - | - | - | - | covered | 96.6 |
| 8.850 | 112.994 | Phase 13H baseline | +0.126 | 0.000 | +0.034 | 0.000 | 1,383 | 1,513 | 1 tile / 2 RAMB18 | 0 | pass | 98.3 |
| 8.800 | 113.636 | Phase 13H baseline | -0.026 | -0.161 | +0.039 | 0.000 | - | - | - | - | fail | invalid |
| 8.800 | 113.636 | fanout_opt | +0.012 | 0.000 | +0.039 | 0.000 | - | - | - | - | pass | 98.8 |
| 8.750 | 114.286 | fanout_opt | +0.012 | 0.000 | +0.034 | 0.000 | - | - | - | - | pass | 99.4 |
| 8.700 | 114.943 | fanout_opt | +0.034 | 0.000 | +0.094 | 0.000 | - | - | - | - | pass | 100.0 |
| 8.650 | 115.607 | fanout_opt | +0.059 | 0.000 | +0.057 | 0.000 | 1,363 | 1,510 | 1 tile / 2 RAMB18 | 0 | pass | 100.5 |
| 8.500 | 117.647 | fanout_opt | -0.412 | -36.784 | +0.009 | 0.000 | 1,358 | 1,508 | 1 tile / 2 RAMB18 | 0 | fail | invalid |
| 8.250 | 121.212 | not run after 8.500 failed | - | - | - | - | - | - | - | - | not run | invalid |
| 8.000 | 125.000 | not run after 8.500 failed | - | - | - | - | - | - | - | - | not run | invalid |
| 7.750 | 129.032 | not run after 8.500 failed | - | - | - | - | - | - | - | - | not run | invalid |
| 7.500 | 133.333 | not run after 8.500 failed | - | - | - | - | - | - | - | - | not run | invalid |

## Best Passing Timing Point

Best verified passing point:

| Metric | Value |
| --- | ---: |
| Period | 8.650 ns |
| Frequency | 115.607 MHz |
| Strategy | fanout_opt |
| WNS | +0.059 ns |
| TNS | 0.000 ns |
| WHS | +0.057 ns |
| THS | 0.000 ns |
| LUTs | 1,363 |
| FFs | 1,510 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Bitstream | passed |

Estimated performance using the confirmed board CPI:

```text
115.607 MHz / 1.15 CPI = 100.5 MIPS
```

This is timing-supported, but it is not yet a physical high-frequency board measurement.

## Best Failing Timing Point

New Phase 17D targeted run:

| Metric | Value |
| --- | ---: |
| Period | 8.500 ns |
| Frequency | 117.647 MHz |
| Strategy | fanout_opt |
| WNS | -0.412 ns |
| TNS | -36.784 ns |
| Failing setup endpoints | 234 |
| WHS | +0.009 ns |
| THS | 0.000 ns |
| LUTs | 1,358 |
| FFs | 1,508 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Bitstream | generated, but timing failed |

Because setup timing failed, the 117.647 MHz point does not count as a valid performance result.

Worst 8.500 ns setup path:

| Item | Value |
| --- | --- |
| Source | `cpu_inst/mem_wb_reg_reg[rd][2]/C` |
| Destination | `cpu_inst/id_ex_reg_reg[operand_b][12]/R` |
| Slack | -0.412 ns |
| Data path delay | 8.314 ns |
| Logic delay | 2.431 ns, 29.239% |
| Route delay | 5.883 ns, 70.761% |
| Logic levels | 10 |

The 8.500 ns failure is route-heavy and sits in the writeback/register-dependency/ID-EX operand-control family.

## Decision

Phase 17D supports a timing-estimated 100 MIPS result for the original Phase 13 forward-timing CPU:

```text
8.650 ns passing period -> 115.607 MHz -> about 100.5 MIPS at CPI 1.15
```

Phase 17D does not support beating the Phase 14G estimated 101.8 MIPS result, because the required 117.1 MHz point is near 8.54 ns and the 8.500 ns run failed timing.

## Limitations

- The 100.5 MIPS value is timing-estimated using the hardware-measured 100 MHz CPI.
- It is not yet a direct Basys 3 board measurement above 100 MHz.
- The Phase 13 hardware CPI was measured on the FPGA demo workload; if the workload changes, CPI may change.
- Generated Vivado outputs are local evidence and should not be committed wholesale.

## Recommended Next Step

Proceed to an MMCM / Clocking Wizard hardware test only if the goal is to physically demonstrate the Phase 13 CPU above 100 MHz. The first practical target is around 115.6 MHz, matching the verified 8.650 ns timing point. That should display approximately `0100` MIPS if the board workload CPI remains close to 1.15.
