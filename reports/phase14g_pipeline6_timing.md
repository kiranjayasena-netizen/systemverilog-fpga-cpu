# Phase 14G Pipeline6 Vivado Timing Comparison

## Purpose

Phase 14G runs Vivado implementation and a post-route timing sweep for the separate six-stage pipeline path:

`IF -> ID -> OP -> EX -> MEM -> WB`

This phase does not change CPU architecture or instruction encodings. It uses the Phase 14F simulation CPI result and post-route Vivado timing to decide whether the six-stage pipeline can beat the current Phase 13I preferred measured implementation.

## Baseline

The preferred measured baseline before Phase 14G remains Phase 13E RTL with the Phase 13I `fanout_opt` implementation strategy.

| Metric | Phase 13I preferred result |
| --- | ---: |
| Fmax | 115.607 MHz |
| CPI | 1.339 |
| Practical estimated MIPS | ~86.4 |
| LUTs | 1,363 |
| FFs | 1,510 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |

## Phase 14F CPI Input

Phase 14G uses the Phase 14F measured simulation CPI:

| Metric | Phase 14F six-stage pipeline |
| --- | ---: |
| Enabled cycles | 95 |
| Retired instructions | 58 |
| CPI | 1.638 |
| Branch redirects | 2 |
| Jump redirects | 3 |
| Load-use stalls | 10 |
| Memory writes | 11 |

Practical estimated MIPS is calculated as:

```text
Practical estimated MIPS = post-route Fmax in MHz / measured CPI
```

Thresholds using CPI 1.638:

| Goal | Required Fmax | Required period |
| --- | ---: | ---: |
| Beat Phase 13I ~86.4 MIPS | ~141.5 MHz | ~7.07 ns |
| Reach 90 MIPS | ~147.4 MHz | ~6.78 ns |

## Vivado Flow

Script:

- `scripts/run_vivado_impl_pipeline6.tcl`

Target:

- Board: Basys 3
- FPGA: `xc7a35tcpg236-1`
- Top: `fpga_top_pipeline6`
- Constraint file: `constraints/basys3.xdc`
- Vivado: 2026.1

Source files:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `rtl/fpga_top_pipeline6.sv`

Generated Vivado outputs are under `reports/phase14g_impl/` and are evidence artifacts. They should not be committed wholesale.

## Timing Sweep

All rows below are post-route implementation results using the `fanout_opt` strategy. A row is counted as passing only if setup timing passes, hold timing passes, TNS is zero, THS is zero and bitstream generation completes.

| Target period | Fmax | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Bitstream | MIPS @ CPI 1.638 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 8.000 ns | 125.000 MHz | +0.841 ns | 0.000 ns | +0.058 ns | 0.000 ns | 1,292 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 76.313 |
| 7.500 ns | 133.333 MHz | +0.694 ns | 0.000 ns | +0.098 ns | 0.000 ns | 1,292 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 81.400 |
| 7.000 ns | 142.857 MHz | +0.451 ns | 0.000 ns | +0.059 ns | 0.000 ns | 1,294 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 87.214 |
| 6.800 ns | 147.059 MHz | +0.344 ns | 0.000 ns | +0.057 ns | 0.000 ns | 1,295 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 89.780 |
| 6.750 ns | 148.148 MHz | +0.533 ns | 0.000 ns | +0.082 ns | 0.000 ns | 1,295 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 90.445 |
| 6.700 ns | 149.254 MHz | +0.337 ns | 0.000 ns | +0.054 ns | 0.000 ns | 1,294 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 91.119 |
| 6.650 ns | 150.376 MHz | +0.212 ns | 0.000 ns | +0.034 ns | 0.000 ns | 1,297 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 91.805 |
| 6.500 ns | 153.846 MHz | +0.129 ns | 0.000 ns | +0.033 ns | 0.000 ns | 1,296 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 93.923 |
| 6.400 ns | 156.250 MHz | +0.216 ns | 0.000 ns | +0.059 ns | 0.000 ns | 1,295 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 95.391 |
| 6.200 ns | 161.290 MHz | +0.088 ns | 0.000 ns | +0.037 ns | 0.000 ns | 1,298 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 98.468 |
| 6.100 ns | 163.934 MHz | +0.041 ns | 0.000 ns | +0.101 ns | 0.000 ns | 1,302 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 100.082 |
| 6.000 ns | 166.667 MHz | +0.024 ns | 0.000 ns | +0.058 ns | 0.000 ns | 1,308 | 1,602 | 1 tile / 2 RAMB18 | 0 | pass | 101.750 |

The best verified passing point in this sweep is 6.000 ns, or 166.667 MHz.

## Best Passing Result

| Metric | Phase 14G result |
| --- | ---: |
| Best verified period | 6.000 ns |
| Verified Fmax | 166.667 MHz |
| Phase 14F CPI used | 1.638 |
| Practical estimated MIPS | 101.750 |
| WNS | +0.024 ns |
| TNS | 0.000 ns |
| WHS | +0.058 ns |
| THS | 0.000 ns |
| LUTs | 1,308 |
| FFs | 1,602 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total on-chip power estimate | 0.100 W |
| Dynamic power estimate | 0.028 W |
| Static power estimate | 0.072 W |
| Bitstream | generated |

## Comparison Against Phase 13I

| Architecture / implementation | Fmax | CPI | Practical MIPS | LUTs | FFs | BRAM | DSP |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 13I preferred Phase 13E RTL | 115.607 MHz | 1.339 | ~86.4 | 1,363 | 1,510 | 1 tile / 2 RAMB18 | 0 |
| Phase 14G six-stage pipeline | 166.667 MHz | 1.638 | 101.750 | 1,308 | 1,602 | 1 tile / 2 RAMB18 | 0 |

Phase 14G beats the Phase 13I practical estimated MIPS result because the Fmax improvement is large enough to overcome the higher CPI. It also exceeds the 90 MIPS target and crosses 100 MIPS in this measured post-route sweep.

## Critical Path Summary

Best-run report:

- `reports/phase14g_impl/fanout_opt_6p000ns/timing/fpga_top_pipeline6_impl_worst_paths.rpt`

Worst setup path:

- Source: `cpu_inst/op_ex_reg_reg[operand_b][1]/C`
- Destination: `cpu_inst/op_ex_reg_reg[store_data][1]/R`
- Requirement: 6.000 ns
- Slack: +0.024 ns
- Data path delay: 5.376 ns
- Logic delay: 1.891 ns, 35.173%
- Route delay: 3.485 ns, 64.827%
- Logic levels: 6, including 3 CARRY4 levels, one LUT4 and two LUT6 levels

Interpretation:

- The limiting path is still route-heavy.
- The path passes through branch comparison / redirect-valid related control and OP/EX store-data metadata reset/update logic.
- This is consistent with the Phase 14 design trading more pipeline stages for higher Fmax, while remaining limited by control fanout and store-data/operand update muxing rather than BRAM inference.

## Decision

Phase 14G replaces Phase 13I as the current best measured implementation result.

Reasons:

- Phase 14F full custom-ISA style simulation passed before timing measurement.
- Phase 14G post-route implementation passes timing at 6.000 ns.
- TNS is zero and hold timing passes.
- Bitstream generation passes.
- BRAM inference remains 1 Block RAM Tile / 2 RAMB18.
- Practical estimated MIPS improves from about 86.4 to about 101.8.

## Known Limitations

- The 166.667 MHz point is the best period tested in this sweep, not a proven absolute maximum frequency.
- CPI is measured from the Phase 14F benchmark; broader software workloads may differ.
- Hardware validation on a physical Basys 3 board remains pending.
- Phase 14 uses conservative control-flow and load-use handling, so CPI can still be improved in later work.

## Recommended Next Phase

Phase 14H should consolidate the Phase 14 result into a supervisor-facing summary and preserve the 6.000 ns implementation evidence. A later optimisation phase could investigate the remaining route-heavy branch/store-data control path, but the next step should first document the new preferred result clearly and avoid destabilising the now-passing 100+ MIPS evidence.
