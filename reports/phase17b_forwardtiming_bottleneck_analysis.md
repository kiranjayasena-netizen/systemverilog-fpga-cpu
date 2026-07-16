# Phase 17B Forward-Timing Bottleneck Analysis

## Purpose

Phase 17B is the analysis step after the Phase 17A hardware profiling wrapper. Its goal is to explain why the Phase 13 forward-timing five-stage pipeline measures around 87 MIPS at the fixed 100 MHz Basys 3 clock instead of approaching the theoretical 100 MIPS limit.

## Current Known Measurement

| Metric | Value | Interpretation |
| --- | ---: | --- |
| Measured MIPS | ~87 | Current best fixed-100 MHz board result |
| Implied CPI | ~1.15 | `100 / 87` |
| Retired instructions/window | ~87,000,000 | Implied by 87 MIPS over one second |
| Lost cycles/window | ~13,000,000 | Approximate gap from 100 MIPS ideal |

The exact lost-cycle breakdown needs Phase 17A board profiling data.

## Phase 17B Display Modes

Phase 17B extends the Phase 17A hardware profiler display so the board can show the likely cycle-loss sources directly.

Controls:

| Switch | Function |
| --- | --- |
| SW0 | CPU run enable |
| SW3:SW1 | Seven-segment display mode |
| BTNC | Reset |

Display modes:

| Display mode | Metric | FPGA value | Interpretation |
|---|---|---:|---|
| 000 | MIPS | 87 | Baseline throughput |
| 001 | CPI x100 | TBD | Expected around 115 |
| 010 | Load-use stall % x100 | TBD | Data hazard cost |
| 011 | Control flush % x100 | TBD | Branch/jump cost |
| 100 | Fetch wait % x100 | TBD | Instruction fetch cost |
| 101 | Memory wait % x100 | TBD | Data memory cost |
| 110 | Branch/jump events | TBD | Control-flow activity |
| 111 | Retired instruction count in millions | TBD | Sanity check; should match MIPS for a one-second window |

Percentage modes use the 100 MHz one-second measurement window:

```text
percentage_x100 = event_cycles * 10000 / 100,000,000
```

The wrapper implements this as one displayed count per 10,000 event cycles, avoiding a wide runtime divider. For example:

| Display | Meaning |
| ---: | --- |
| 0000 | 0.00% |
| 0050 | 0.50% |
| 0100 | 1.00% |
| 1250 | 12.50% |

## Hardware Counter Table

Fill this table after running the Phase 17A profiling bitstream.

| Metric | Value | Interpretation |
| --- | ---: | --- |
| Measured MIPS | TBD | Throughput at 100 MHz |
| Implied CPI | TBD | `100 / measured MIPS` |
| Retired instructions/window | TBD | Instructions per second |
| Load-use stall cycles | TBD | Data hazard cost |
| Control flush cycles | TBD | Branch/jump cost |
| Memory wait cycles | TBD | Memory cost |
| Fetch wait cycles | TBD | Instruction-fetch cost |
| Taken branches | TBD | Control-flow mix |
| Not-taken branches | TBD | Control-flow mix |
| Jumps | TBD | Control-flow mix |
| Wrong-path instructions flushed | TBD | Redirect penalty evidence |

## Hardware Test Procedure

1. Build the profiler bitstream with `scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl`.
2. Program `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`.
3. Press and release BTNC reset.
4. Set SW0 on.
5. Wait at least two one-second measurement windows.
6. Read each display mode by changing SW3:SW1.
7. Record mode `000` first; it should still show about `0087`.
8. Record mode `001`; it should show about `0115`.
9. Fill the display-mode table above.

## Implementation Result

The expanded Phase 17B-capable profiler bitstream was generated through the Phase 17A profiler script:

- Script: `scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl`
- Bitstream: `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`

Post-route result at the 10.000 ns / 100 MHz board clock:

| Metric | Value |
| --- | ---: |
| WNS | +0.191 ns |
| TNS | 0.000 ns |
| WHS | +0.037 ns |
| THS | 0.000 ns |
| LUTs | 1,784 |
| FFs | 2,289 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Bitstream generation | Passed |

## Likely Bottleneck Ranking Before Board Counter Readout

Expected order, based on the existing Phase 13 pipeline architecture and prior simulation/timing work:

1. Load-use stalls.
2. Control hazard flushes.
3. Instruction fetch waits.
4. Memory waits.
5. Pipeline fill/drain overhead.

This ranking is a hypothesis. Phase 17C should not change RTL until the Phase 17A hardware counter data confirms the dominant source.

## CPI Versus Timing Classification

At the fixed 100 MHz board clock, Phase 13 is not limited by FPGA timing; the relevant performance gap is CPI-related. The known board result of approximately 87 MIPS implies that about 13% of cycles do not retire a useful instruction on the measured workload.

The Phase 13I timing result still matters for possible future high-frequency operation:

- Phase 13I timing-clean Fmax: 115.607 MHz.
- Existing simulation CPI: 1.339 on the aggregate Phase 13 benchmark.
- Board-measured implied CPI: approximately 1.15 on the loaded hardware program.

The difference between simulation CPI and hardware-implied CPI is likely workload-related. The board program and simulation aggregate benchmark are not identical.

## Phase 17C Decision Gate

Recommended optimisation choice after counters are available:

| Dominant measured source | Recommended Phase 17C action |
| --- | --- |
| Load-use stalls dominate | Refine load-use hazard detection, avoiding false stalls on unused fields and `x0` |
| Control flushes dominate | Investigate a simple control-hazard improvement without target buffers or prediction complexity |
| Fetch/memory waits dominate | Inspect frontend buffering and synchronous BRAM request/response handling |
| Program mix dominates | Create a better hardware benchmark program before changing CPU RTL |

## Current Conclusion

Phase 17B currently records the expected analysis framework and known 87 MIPS / CPI 1.15 result. The bottleneck conclusion remains pending until the Phase 17A profiling bitstream is run on hardware and the counter values are recorded.
