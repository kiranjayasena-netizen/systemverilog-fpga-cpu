# Phase 17D Forward-Timing Timing Sweep

## Purpose

Phase 17D explores whether the Phase 13 forward-timing five-stage CPU can run above 100 MHz while preserving its strong board-measured CPI.

This phase does not change CPU RTL. It prepares a repeatable Vivado timing sweep for the existing Phase 13E/13I forward-timing implementation path.

## Script

- `scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl`

Default periods:

- 10.000 ns
- 9.500 ns
- 9.000 ns
- 8.750 ns
- 8.650 ns
- 8.500 ns
- 8.250 ns
- 8.000 ns
- 7.750 ns
- 7.500 ns

Default strategies:

- `default`
- `fanout_opt`
- `explore`
- `physopt`

Run command:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl
```

Shorter targeted run example:

```powershell
$env:PHASE17D_PERIODS = "8.650 8.500 8.250"
$env:PHASE17D_STRATEGIES = "fanout_opt"
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl
```

Generated outputs:

- `reports/phase17d_forwardtiming_timing_sweep/`

These are generated Vivado artifacts and should not be committed wholesale.

## Break-Even Targets

Using the current Phase 13 board-implied CPI of approximately 1.15:

| Goal | Required frequency |
| --- | ---: |
| Reach 100 MIPS | ~115 MHz |
| Beat Phase 14G estimated 101.8 MIPS | ~117.1 MHz |

Examples:

| Frequency | Estimated MIPS at CPI 1.15 |
| ---: | ---: |
| 115 MHz | 100.0 |
| 125 MHz | 108.7 |
| 140 MHz | 121.7 |

These estimates are only valid if the same workload CPI holds at the higher clock.

## Sweep Result Table

A full new multi-strategy sweep has not been run as part of this checkpoint. Fill in this table after running the script.

| Strategy | Period | Fmax | Pass/fail | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Bitstream |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Known Existing Reference

The best existing Phase 13I result is:

| Metric | Phase 13I |
| --- | ---: |
| Period | 8.650 ns |
| Fmax | 115.607 MHz |
| WNS | +0.059 ns |
| TNS | 0.000 ns |
| WHS | +0.057 ns |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| Practical MIPS using simulation CPI 1.339 | ~86.4 |

Using the confirmed 100 MHz board-implied CPI of about 1.15, this same verified 115.607 MHz timing point would correspond to:

```text
115.607 MHz / 1.15 CPI = 100.5 MIPS
```

This is a timing-estimated result only. A future high-frequency hardware clocking test is still required before claiming a physical board measurement above 100 MHz.

The Phase 17D sweep should determine whether this path can be pushed further for the board-measured Phase 13 workload.

## Decision Rule

Phase 17D should be considered useful if it produces a timing-clean period that improves estimated peak MIPS without changing CPU behaviour. It should not be used to claim a higher physical board MIPS value unless a later high-frequency hardware clocking experiment measures it on the Basys 3.
