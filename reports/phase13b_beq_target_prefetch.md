# Phase 13B BEQ Target Prefetch

## Purpose

Phase 13B evaluates a timing-safe optimisation for taken `BEQ` recovery in the separate pipelined CPU path. The goal was to reduce the branch redirect penalty without moving the branch comparison into ID and without replacing the verified Phase 13A jumpfast baseline.

The performance metric remains:

```text
Practical estimated MIPS = post-route estimated Fmax in MHz / measured aggregate CPI
```

## Phase 13A Baseline

| Metric | Phase 13A |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| MIPS at 100 MHz | 74.682 |
| Post-route estimated Fmax | ~101.9 MHz |
| Practical estimated MIPS | ~76.1 |
| LUTs | 1,233 |
| FFs | 1,507 |
| BRAM | 1 tile / 2 RAMB18 |
| DSP | 0 |
| WNS | +0.182 ns |
| TNS | 0.000 ns |
| 100 MHz timing | Passed |
| Bitstream | Passed |

Phase 13A already detects `JUMP` in ID and uses a timing-safe fast target request for unconditional jumps. `BEQ` remains resolved in EX using forwarded operands. A taken `BEQ` uses the registered redirect request path so the branch comparison does not directly drive the instruction-BRAM address.

## Why Early BEQ Resolution Was Rejected

Direct early `BEQ` resolution would place a long path through register forwarding, equality comparison and instruction-BRAM address selection. That is exactly the type of path Phase 12 and Phase 13A avoided to keep 100 MHz timing clean.

Phase 13B therefore keeps:

- `BEQ` comparison in EX.
- Branch operand forwarding in EX.
- The forwarded equality result off the instruction-BRAM address path.
- Phase 13A fast `JUMP` behaviour unchanged.

## Architecture Change

New separate Phase 13B files:

- `rtl/bram_instr_mem_dualread.sv`
- `rtl/cpu_core_pipeline_branchprefetch.sv`
- `rtl/fpga_top_pipeline_branchprefetch.sv`
- `tb/tb_cpu_core_pipeline_branchprefetch.sv`
- `scripts/run_vivado_synth_pipeline_branchprefetch.tcl`
- `scripts/run_vivado_impl_pipeline_branchprefetch.tcl`

The original Phase 12 and Phase 13A paths remain available.

## Dual-Read Instruction Memory

`bram_instr_mem_dualread.sv` provides two synchronous read ports over the same instruction contents:

- Port A: normal sequential fetch and existing redirect fetch.
- Port B: speculative `BEQ` target fetch.

Both ports use byte addresses and word selection from the address bits. Out-of-range reads return the configured NOP instruction.

Vivado inferred block RAM, but the result did not retain the Phase 13A total of 2 RAMB18 blocks. Phase 13B uses 3 RAMB18 blocks, or 1.5 Block RAM Tiles. This is the main resource cost of the experiment.

## BEQ Target Prefetch

During ID, when a valid `BEQ` advances into ID/EX, the core calculates:

```text
branch_target = if_id_pc + (sign_extended_imm13 << 2)
```

The branch target is captured in ID/EX and also issued on instruction-memory Port B as a speculative target read. Metadata records the matching branch PC and target PC:

```text
beq_prefetch_pending
beq_prefetch_branch_pc
beq_prefetch_target_pc
```

The target prefetch request is issued once when the `BEQ` is accepted into ID/EX. It is not repeatedly issued during decode stalls.

## Taken and Not-Taken Behaviour

For a taken `BEQ`, if the matching Port B response is available:

- The prefetched target instruction is paired with the saved target PC.
- The target response enters IF/ID without the old full redirect request delay.
- Younger wrong-path sequential state is flushed.
- The normal pending sequential response and fetch buffer are invalidated.
- Wrong-path register writes and STORE operations are blocked.
- The `BEQ` itself retires once.

For a not-taken `BEQ`:

- The speculative target response is discarded.
- Normal sequential Port A fetch continues.
- No control flush is counted.
- No extra stall is introduced unless a real data hazard requires it.

## Priority and Safety Rules

Older EX-stage redirects retain priority over younger ID-stage control flow. In particular, an older taken `BEQ` overrides:

- a younger ID-stage `JUMP`;
- a younger sequential fetch;
- a younger `BEQ` target prefetch.

The Phase 13A fast `JUMP` path is retained. A younger wrong-path `JUMP` cannot redirect, retire or increment the jump counter after an older taken `BEQ`.

Reset clears all target-prefetch metadata. When `enable == 0`, branch-prefetch metadata and pipeline state are held; no retirement, register write or memory write occurs while paused.

## Focused Verification

Focused Phase 13B checks were added for:

- taken forward `BEQ` target prefetch;
- not-taken `BEQ` target discard;
- load-to-`BEQ` dependency with the existing load-use stall;
- invalid opcode at the branch target;
- pause after target request;
- branch-heavy target-prefetch benchmark.

The retained Phase 13A jump-focused tests also continue to cover:

- single forward `JUMP`;
- consecutive `JUMP`s;
- backward `JUMP` loops;
- older taken `BEQ` flushing a younger `JUMP`;
- wrong-path STORE protection;
- fetch-buffer interaction near a jump.

Focused/full Phase 13B testbench result:

| Metric | Result |
| --- | ---: |
| Tests run | 4,004 |
| Tests failed | 0 |
| Result string | `PHASE 13B BRANCH-PREFETCH PIPELINE TEST PASSED` |

Regression transcript:

- `reports/simulation_transcripts/phase13b_xsim_regression_final_20260711_203157.txt`

Known warning:

- Some `xelab` steps reported the known object-directory cleanup warning after building the snapshot.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

## Branch-Heavy Benchmark

The added branch-heavy benchmark was intended to stress the new target-prefetch path.

| Metric | Result |
| --- | ---: |
| Cycles | 75 |
| Retired instructions | 45 |
| CPI | 1.667 |
| MIPS at 100 MHz | 60.000 |
| Taken BEQs | 16 |
| Not-taken BEQs | 7 |
| Target prefetch requests | 23 |
| Target prefetch hits | 16 |
| Target prefetch discards | 7 |

This confirms that the target prefetch machinery is exercised and distinguishes taken and not-taken branches correctly.

## Unchanged Aggregate Benchmark

The Phase 13B testbench also reran the existing aggregate benchmark mix used for Phase 12 and Phase 13A comparison.

| Metric | Phase 13A | Phase 13B |
| --- | ---: | ---: |
| Aggregate cycles | 427 | 424 |
| Retired instructions | 319 | 319 |
| Aggregate CPI | 1.339 | 1.329 |
| MIPS at 100 MHz | 74.682 | 75.236 |

Phase 13B saves 3 aggregate cycles relative to Phase 13A. The aggregate benchmark contains relatively few taken `BEQ` instructions, so the CPI improvement is small.

## Vivado Implementation Result

Command run:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_branchprefetch.tcl
```

Generated report paths:

- `reports/phase13b/utilisation/fpga_top_pipeline_branchprefetch_impl_utilization.rpt`
- `reports/phase13b/timing/fpga_top_pipeline_branchprefetch_impl_timing_summary.rpt`
- `reports/phase13b/timing/fpga_top_pipeline_branchprefetch_impl_worst_paths.rpt`
- `reports/phase13b/power/fpga_top_pipeline_branchprefetch_impl_power.rpt`
- `reports/phase13b/route/fpga_top_pipeline_branchprefetch_route_status.rpt`
- `reports/phase13b/bitstreams/fpga_top_pipeline_branchprefetch.bit`

| Metric | Phase 13B |
| --- | ---: |
| LUTs | 1,475 / 20,800, 7.09% |
| FFs | 1,600 / 41,600, 3.85% |
| BRAM | 1.5 tiles / 3 RAMB18 |
| DSP | 0 |
| WNS | +0.008 ns |
| TNS | 0.000 ns |
| WHS | +0.037 ns |
| THS | 0.000 ns |
| 100 MHz timing | Passed |
| Bitstream generation | Passed |
| Total power estimate | 0.094 W, medium confidence |

Estimated Fmax from post-route WNS:

```text
Fmax ~= 1000 / (10.000 ns - 0.008 ns) = 100.1 MHz
```

Practical estimated MIPS:

```text
100.1 MHz / 1.329 CPI ~= 75.3 MIPS
```

## Critical Path

Worst setup path:

```text
Source:      cpu_inst/data_mem_inst/mem_reg/CLKBWRCLK
Destination: cpu_inst/redirect_pending_target_reg[29]/D
Slack:       +0.008 ns
Logic levels: 12
Data path delay: 9.989 ns
  logic: 5.405 ns, 54.107%
  route: 4.584 ns, 45.893%
```

The initial implementation placed the EX-stage redirect condition on the Port B address request and failed timing. The final implementation split the decode-only Port B address request from the architectural prefetch metadata commit. This restored 100 MHz timing, but the remaining margin is very small.

## Comparison Against Phase 13A

| Metric | Phase 13A | Phase 13B | Change |
| --- | ---: | ---: | ---: |
| Aggregate cycles | 427 | 424 | -3 |
| Aggregate CPI | 1.339 | 1.329 | Better |
| Estimated Fmax | ~101.9 MHz | ~100.1 MHz | Worse |
| Practical estimated MIPS | ~76.1 | ~75.3 | Worse |
| LUTs | 1,233 | 1,475 | +242 |
| FFs | 1,507 | 1,600 | +93 |
| BRAM | 2 RAMB18 | 3 RAMB18 | +1 RAMB18 |
| WNS | +0.182 ns | +0.008 ns | Worse |
| TNS | 0.000 ns | 0.000 ns | Same |

## Decision

Phase 13B is functionally correct and meets the 100 MHz timing constraint, but it should not replace Phase 13A as the preferred implementation path.

Reason:

- The aggregate CPI improves slightly.
- The dual-read instruction memory increases BRAM use.
- The post-route timing margin becomes very tight.
- Practical estimated throughput falls from about 76.1 MIPS to about 75.3 MIPS.

Phase 13B is useful as a documented branch-heavy experiment and as evidence that speculative `BEQ` target prefetch can work architecturally, but the resource/timing trade-off is not favourable for the current benchmark mix.

## Limitations

- No physical Basys 3 hardware validation has been performed.
- Fmax is estimated from Vivado post-route timing, not measured on hardware.
- The aggregate benchmark contains relatively few taken `BEQ` instructions.
- The branch-heavy benchmark improves coverage of the mechanism but is not used alone to claim overall improvement.
- Dual-read instruction memory increased BRAM usage instead of retaining the Phase 13A 2-RAMB18 total.

## Recommended Phase 13C Work

The next optimisation should focus on preserving the Phase 13A timing/resource profile while reducing remaining penalties:

1. Keep Phase 13A as the preferred baseline.
2. Investigate the current redirect target critical path before adding more speculative hardware.
3. Consider a lower-cost branch-target reuse mechanism or a tiny target buffer only if it can preserve BRAM use and timing.
4. Profile whether load-use stalls or mixed benchmark control flushes dominate the remaining CPI.
5. Reject any optimisation that improves CPI but reduces practical estimated MIPS after post-route timing.
