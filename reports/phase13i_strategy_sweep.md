# Phase 13I Implementation Strategy Sweep

## Purpose

Phase 13I investigates whether the preferred Phase 13E forwarding-timing pipeline can be improved using Vivado implementation strategy changes only.

No CPU RTL, instruction encoding, benchmark program, BRAM module or architectural behaviour was changed. The experiment keeps the Phase 13E CPU path and changes only implementation directives.

## Baseline

Current preferred baseline before Phase 13I:

| Metric | Phase 13H / Phase 13E |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| Final verified period | 8.850 ns |
| Verified Fmax | 112.994 MHz |
| Practical estimated MIPS | ~84.4 |
| LUTs | 1,383 |
| FFs | 1,513 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |

The performance equation remains:

```text
Practical MIPS = verified post-route Fmax in MHz / measured CPI
```

## Strategy Script

Phase 13I adds:

- `scripts/run_vivado_phase13i_strategy_sweep.tcl`

The script reuses:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`
- `constraints/basys3.xdc`
- target part `xc7a35tcpg236-1`

It supports period and strategy selection through:

```powershell
$env:PHASE13I_PERIOD='8.650'
$env:PHASE13I_STRATEGY='fanout_opt'
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_phase13i_strategy_sweep.tcl
```

## Strategies Tested

| Strategy | Main directives | Purpose |
| --- | --- | --- |
| Phase 13H baseline | `PerformanceOptimized`, `Explore`, `ExtraNetDelay_high`, `AggressiveExplore`, `AggressiveExplore` | Existing preferred implementation strategy. |
| `route_highcost` | Existing placement/phys-opt flow with `route_design -directive HigherDelayCost` | Check whether a route-cost directive fixes the 8.800 ns failure. |
| `fanout_opt` | Existing flow with `phys_opt_design -directive AggressiveFanoutOpt` before route | Target the route-heavy/high-fanout control-enable timing family. |

The `fanout_opt` strategy was the only tested strategy that improved the accepted timing point.

## Timing Sweep

| Strategy | Period | Fmax | WNS | TNS | WHS | THS | Bitstream | Status |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Phase 13H baseline | 8.850 ns | 112.994 MHz | +0.126 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed | Previous preferred result |
| Phase 13H baseline | 8.800 ns | 113.636 MHz | -0.026 ns | -0.161 ns | +0.039 ns | 0.000 ns | Generated, timing failed | Rejected |
| `route_highcost` | 8.800 ns | 113.636 MHz | -0.087 ns | -0.512 ns | +0.039 ns | 0.000 ns | Generated, timing failed | Rejected |
| `fanout_opt` | 8.800 ns | 113.636 MHz | +0.012 ns | 0.000 ns | +0.039 ns | 0.000 ns | Passed | Accepted |
| `fanout_opt` | 8.750 ns | 114.286 MHz | +0.012 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed | Accepted |
| `fanout_opt` | 8.700 ns | 114.943 MHz | +0.034 ns | 0.000 ns | +0.094 ns | 0.000 ns | Passed | Accepted |
| `fanout_opt` | 8.650 ns | 115.607 MHz | +0.059 ns | 0.000 ns | +0.057 ns | 0.000 ns | Passed | Final accepted Phase 13I result |

The highest verified passing period tested in Phase 13I is 8.650 ns.

## Final Phase 13I Result

| Metric | Phase 13I |
| --- | ---: |
| Preferred implementation | Phase 13E RTL with Phase 13I `fanout_opt` Vivado strategy |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| Verified period | 8.650 ns |
| Verified Fmax | 115.607 MHz |
| Practical estimated MIPS | ~86.4 |
| LUTs | 1,363 |
| FFs | 1,510 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Power estimate | 0.093 W, medium confidence |

Calculation:

```text
115.607 MHz / (427 / 319) = 86.4 practical estimated MIPS
```

This improves over the Phase 13H result:

```text
84.4 MIPS -> 86.4 MIPS, about +2.3%
```

## Critical Path

At 8.650 ns, the worst path remains in the data-memory/writeback-to-frontend or ID/EX control family:

| Item | Value |
| --- | --- |
| Slack | +0.059 ns |
| Source | `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK` |
| Destination | `cpu_inst/fetch_pending_pc_reg[26]/CE` |
| Data path delay | 8.273 ns |
| Logic delay | 4.002 ns, 48.371% |
| Route delay | 4.271 ns, 51.629% |
| Logic levels | 7 |

The strategy did not remove the underlying critical-path family, but it improved placement/physical optimisation enough to close timing at a tighter period.

## Verification

No functional RTL changed in Phase 13I, so no new functional testbench was required. The Phase 13H full XSim regression remains the functional evidence for the unchanged Phase 13E RTL:

- `reports/simulation_transcripts/phase13h_xsim_regression_final_20260713_124649.txt`

That transcript completed successfully with `All XSim regression tests completed.`

## Decision

Phase 13I should replace the Phase 13H timing result as the current preferred measured implementation result because:

- practical estimated MIPS improves from about 84.4 to about 86.4;
- timing is fully passing at 8.650 ns;
- TNS remains zero;
- hold timing passes;
- bitstream generation passes;
- BRAM inference remains unchanged;
- no CPU behaviour changed.

Phase 13I still does not reach 90 MIPS. At the measured CPI of 1.339, 90 MIPS would require about 120.5 MHz, or an 8.301 ns period.

## Repository Hygiene

Raw Vivado outputs are generated under:

- `reports/phase13i_strategy/`

These generated `.rpt`, `.dcp`, `.bit`, `.log` and related implementation artifacts should remain local unless explicitly requested for archival.

## Recommended Next Phase

Recommended next work:

1. Keep Phase 13I as the preferred measured implementation strategy for the Phase 13E RTL.
2. Avoid additional control-flow target-buffer work unless it can preserve timing.
3. For a further push toward 90 MIPS, investigate a tiny RTL cleanup around the data-memory/load-result to frontend/ID/EX control path, but only if it preserves CPI 1.339.
4. If project time is limited, stop optimisation here and prepare a supervisor-facing final comparison report: the design is timing-clean, BRAM-based, and reaches about 86.4 practical estimated MIPS without changing architecture semantics.
