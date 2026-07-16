# Phase 17D Forward-Timing Optimised Timing Sweep

## Purpose

Phase 17D records the timing-sweep plan and result for the Phase 17C optimised forward-timing CPU.

The sweep is only meaningful if the 10.000 ns baseline implementation passes. In this experiment, the Phase 17C RTL failed 10.000 ns timing, so tighter periods were not run.

## Script

- `scripts/run_vivado_impl_pipeline_forwardtiming_opt_sweep.tcl`

Default periods:

- 10.000 ns
- 9.500 ns
- 9.000 ns
- 8.750 ns
- 8.650 ns
- 8.500 ns
- 8.250 ns
- 8.000 ns

Run command:

```powershell
vivado -mode batch -source scripts\run_vivado_impl_pipeline_forwardtiming_opt_sweep.tcl
```

Generated outputs:

- `reports/phase17d_forwardtiming_opt_timing_sweep/`

The generated output folder should not be committed wholesale.

## Actual Timing Evidence

The Phase 17C implementation was run at 10.000 ns first:

| Period | Equivalent Fmax | WNS | TNS | WHS | THS | Status |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 10.000 ns | 100.000 MHz | -0.552 ns | -2.159 ns | +0.088 ns | 0.000 ns | Failed setup |

Because 10.000 ns failed setup timing, all requested tighter periods are expected to fail for the same RTL. They were not run in this checkpoint to avoid spending more Vivado runtime on known-failing constraints.

## Estimated MIPS

The simulation CPI for the Phase 17C experiment is:

```text
CPI = 424 / 319 = 1.329
```

If the design had met 100 MHz timing, its simulation-CPI throughput would have been:

```text
100 / 1.329 = 75.236 MIPS
```

However, because post-route WNS is negative at 10.000 ns, there is no accepted Phase 17C timing-clean MIPS result.

## Decision

The timing sweep does not replace the existing Phase 13E/13I result. Phase 13E/13I remains preferred for the five-stage CPU path.

## Recommended Next Step

The failed path shows that direct EX-stage branch target requests are too timing-expensive for this implementation. Future Phase 17 work should first expose detailed hardware bottleneck counters, then try a timing-safe optimisation that does not put branch comparison and forwarding directly on the instruction-BRAM address path.
