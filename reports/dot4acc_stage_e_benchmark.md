# DOT4ACC Stage E Same-Clock Architectural Benchmark

Status: complete functional benchmark dataset. All results in this report are
**100 MHz same-clock architectural/simulation performance** from Vivado XSim.
They are not measured board performance, post-route timing evidence, an Fmax
claim, or a neural-network inference claim.

## Objective

Stage E measures how much complete-CPU performance is gained by moving the
same signed INT8 mathematical work from the original scalar ISA to `MAC8` and
then to `DOT4ACC`. It deliberately changes no RTL, issue policy, forwarding,
arithmetic, pipeline depth, memory system, or conservative hold behaviour.

Machine-readable source data is in
[`dot4acc_stage_e/results.csv`](dot4acc_stage_e/results.csv). The focused XSim
testbench regenerates that file and checks every architectural result against
the Stage A1 oracle or an equivalent scalar recurrence.

## Experimental controls

- Simulator/toolchain: AMD Vivado XSim 2026.1.
- Nominal comparison clock: 100 MHz (`10 ns` testbench period).
- Scalar and MAC8 CPU: unmodified `cpu_core_pipeline_mac8_timingopt`.
- DOT CPU: unmodified `cpu_core_pipeline_dot4acc_wb`.
- All compared rows use identical signed lane data, accumulator initial value,
  useful INT8 MAC count, and final mathematical result.
- Register-resident operands are preloaded after reset for every implementation;
  preload time is outside the measured window. Memory-fed operands are
  identically preloaded into data BRAM.
- Program start is the first rising edge with `enable=1` after reset and setup.
- The end point is the edge on which the designated final STORE retires.
- `cycles_to_store` is the CPU `total_cycles` value sampled on that retirement.
  The benchmark stops there, so `total_cycles == cycles_to_store` for all rows.
- Retired instructions are counted only through that same STORE.
- One `MAC8` is one useful INT8 MAC; one `DOT4ACC` is four useful INT8 MACs.

Derived metrics use:

```text
CPI                 = cycles_to_store / retired_instructions
MACs/cycle          = useful_macs / cycles_to_store
MMAC/s @ 100 MHz    = MACs/cycle * 100
speedup             = reference_cycles / candidate_cycles
DOT peak utilisation = 100 * achieved_MMAC/s / 400
```

## Historical four-element benchmark reproduction

The committed scalar and MAC8 images were used without modification:

- `programs/ai_dot_product_baseline.mem`;
- `programs/ai_dot_product_mac.mem`.

They compute:

```text
[3, -2, 5, -4] dot [-3, 4, -1, -2] = -14 = 0xfffffff2
```

The DOT equivalent uses `programs/ai_dot_product_dot4acc.mem`, two packed
LOADs, one DOT, and the same zero accumulator and final STORE.

| Metric | Scalar | MAC8 | DOT4ACC |
| --- | ---: | ---: | ---: |
| Useful INT8 MACs | 4 | 4 | 4 |
| Program/retired instructions through STORE | 24 | 14 | 6 |
| Cycles through STORE / total measured cycles | 29 | 19 | 16 |
| CPI | 1.208 | 1.357 | 2.667 |
| MACs/cycle | 0.138 | 0.211 | 0.250 |
| MMAC/s @ 100 MHz | 13.793 | 21.053 | 25.000 |
| Speedup vs scalar | 1.000x | 1.526x | 1.813x |
| Speedup vs MAC8 | 0.655x | 1.000x | 1.188x |
| DOT arithmetic peak utilisation | N/A | N/A | 6.250% |
| Final result | `0xfffffff2` | `0xfffffff2` | `0xfffffff2` |

The repository's historical `29/19` cycle and `24/14` retired-instruction
results are exactly reproduced. The numbers `24` and `14` are instruction
counts, not separate cycle measurements.

## Register-resident packed benchmark and vector scaling

The scaling workload repeats this deterministic four-lane block:

```text
A = [3, -2, 1, -1]
B = [127, -128, 0, 5]
dot(A,B) = 632
initial accumulator = 37
```

It contains positive and negative operands, zero, `+127`, and `-128`. Per
block, scalar software uses seven repeated ADD/SUB instructions, MAC8 uses
four instructions, and DOT uses one. N=128 still fits the 256-word instruction
memory: 225 scalar instructions including the final STORE.

| N | Implementation | Retired | Cycles | CPI | MAC/cycle | MMAC/s | Speedup vs scalar | Speedup vs MAC8 | DOT peak util. |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | Scalar | 8 | 13 | 1.625 | 0.308 | 30.769 | 1.000x | 0.769x | N/A |
| 4 | MAC8 | 5 | 10 | 2.000 | 0.400 | 40.000 | 1.300x | 1.000x | N/A |
| 4 | DOT4ACC | 2 | 12 | 6.000 | 0.333 | 33.333 | 1.083x | 0.833x | 8.333% |
| 8 | Scalar | 15 | 20 | 1.333 | 0.400 | 40.000 | 1.000x | 0.700x | N/A |
| 8 | MAC8 | 9 | 14 | 1.556 | 0.571 | 57.143 | 1.429x | 1.000x | N/A |
| 8 | DOT4ACC | 3 | 13 | 4.333 | 0.615 | 61.538 | 1.538x | 1.077x | 15.385% |
| 16 | Scalar | 29 | 34 | 1.172 | 0.471 | 47.059 | 1.000x | 0.647x | N/A |
| 16 | MAC8 | 17 | 22 | 1.294 | 0.727 | 72.727 | 1.545x | 1.000x | N/A |
| 16 | DOT4ACC | 5 | 15 | 3.000 | 1.067 | 106.667 | 2.267x | 1.467x | 26.667% |
| 32 | Scalar | 57 | 62 | 1.088 | 0.516 | 51.613 | 1.000x | 0.613x | N/A |
| 32 | MAC8 | 33 | 38 | 1.152 | 0.842 | 84.211 | 1.632x | 1.000x | N/A |
| 32 | DOT4ACC | 9 | 19 | 2.111 | 1.684 | 168.421 | 3.263x | 2.000x | 42.105% |
| 64 | Scalar | 113 | 118 | 1.044 | 0.542 | 54.237 | 1.000x | 0.593x | N/A |
| 64 | MAC8 | 65 | 70 | 1.077 | 0.914 | 91.429 | 1.686x | 1.000x | N/A |
| 64 | DOT4ACC | 17 | 27 | 1.588 | 2.370 | 237.037 | 4.370x | 2.593x | 59.259% |
| 128 | Scalar | 225 | 230 | 1.022 | 0.557 | 55.652 | 1.000x | 0.583x | N/A |
| 128 | MAC8 | 129 | 134 | 1.039 | 0.955 | 95.522 | 1.716x | 1.000x | N/A |
| 128 | DOT4ACC | 33 | 43 | 1.303 | 2.977 | 297.674 | 5.349x | 3.116x | 74.419% |

For N=4, DOT is two cycles slower than MAC8 because its registered issue,
three-stage arithmetic, architectural completion, and final STORE drain are
not amortised. DOT first overtakes MAC8 at N=8. Increasing N amortises the
fixed ten-cycle overhead around the K-operation DOT stream, while MAC8 and
scalar approach one retired arithmetic instruction per cycle.

Charts generated directly from the CSV with only Python's standard library:

- [cycles versus vector length](dot4acc_stage_e/cycles_vs_vector_length.svg)
- [retired instructions versus vector length](dot4acc_stage_e/retired_vs_vector_length.svg)
- [MMAC/s versus vector length](dot4acc_stage_e/mmac_vs_vector_length.svg)
- [speedup versus vector length](dot4acc_stage_e/speedup_vs_vector_length.svg)
- [DOT peak utilisation](dot4acc_stage_e/dot_peak_utilisation.svg)

## Same-rd chain scaling and theoretical model

For K contiguous same-`rd` DOTs, measurements exactly follow:

```text
first issue       = cycle 4
last issue        = cycle K+3
first completion  = cycle 7
last completion   = cycle K+6
first retirement  = cycle 8
last retirement   = cycle K+7
final STORE retire = cycle K+11
```

Thus measured complete-CPU cycles are `K+11`, not merely K arithmetic cycles.

| DOTs K | Useful MACs | First/last issue | First/last retire | Cycles | Retired | Issue/complete/retire II | MMAC/s | Peak util. | Final accumulator |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 4 | 4 / 4 | 8 / 8 | 12 | 2 | N/A | 33.333 | 8.333% | `0x0000029d` |
| 2 | 8 | 4 / 5 | 8 / 9 | 13 | 3 | 1.000 | 61.538 | 15.385% | `0x00000515` |
| 4 | 16 | 4 / 7 | 8 / 11 | 15 | 5 | 1.000 | 106.667 | 26.667% | `0x00000a05` |
| 8 | 32 | 4 / 11 | 8 / 15 | 19 | 9 | 1.000 | 168.421 | 42.105% | `0x000013e5` |
| 16 | 64 | 4 / 19 | 8 / 23 | 27 | 17 | 1.000 | 237.037 | 59.259% | `0x000027a5` |
| 32 | 128 | 4 / 35 | 8 / 39 | 43 | 33 | 1.000 | 297.674 | 74.419% | `0x00004f25` |

This confirms architectural II=1 for a 32-member chain, including ordered
per-member retirement and final architectural STORE.

## Independent DOT stream

Independent destinations have the same issue, completion, retirement, and
total-cycle curves as same-`rd` chains for K=1,2,4,8,16. The K=16 stream issues
at cycles 4..19, retires at 8..23, and reaches the final STORE at cycle 27.
All three measured intervals are 1.000. The completion-side chain recurrence
therefore adds no throughput penalty relative to independent destinations.

## Memory-fed performance

The memory workload repeats `LOAD packed A; LOAD packed B; DOT4ACC` and then
stores the accumulator. It uses the existing single data-memory port and
unchanged dependency/hold logic.

| N | LOAD / DOT / STORE | Retired | Cycles | CPI | DOT issue II | MAC/cycle | MMAC/s | Peak util. | Cycles / register-resident |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | 8 / 4 / 1 | 13 | 42 | 3.231 | 9.000 | 0.381 | 38.095 | 9.524% | 2.800x |
| 32 | 16 / 8 / 1 | 25 | 78 | 3.120 | 9.000 | 0.410 | 41.026 | 10.256% | 4.105x |
| 64 | 32 / 16 / 1 | 49 | 150 | 3.061 | 9.000 | 0.427 | 42.667 | 10.667% | 5.556x |
| 128 | 64 / 32 / 1 | 97 | 294 | 3.031 | 9.000 | 0.435 | 43.537 | 10.884% | 6.837x |

The exact measured model is `9K+6` cycles for K DOTs. Each load pair breaks
contiguous chaining, the second LOAD has a load-use dependency, and younger
non-DOT work cannot overlap an active DOT. Operand delivery, not the four-DSP
arithmetic pipeline, is the bottleneck: N=128 falls from 297.674 to 43.537
MMAC/s.

## Conservative non-DOT hold cost

An independent `ADDI` was inserted between otherwise contiguous same-`rd`
DOTs. This intentionally adds side work; it is a control-cost experiment, not
a same-workload speedup claim.

| DOTs | Useful MACs | Added ADDIs | Pure-chain cycles | Interleaved cycles | DOT issue II | Hold cycles | Added cycles |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 16 | 3 | 15 | 33 | 7.000 | 20 | 18 |
| 8 | 32 | 7 | 19 | 61 | 7.000 | 40 | 42 |
| 16 | 64 | 15 | 27 | 117 | 7.000 | 80 | 90 |

The measured interleaved model is `7K+5`, versus `K+11` for a pure chain.
Each inserted scalar gap costs six cycles: one for the scalar instruction and
five additional correctness-first hold/drain cycles. This is the principal
register-resident control limitation when DOT and scalar work alternate.

## DOT result consumption

| Pattern | Retired | Cycles | Increment vs direct DOT→STORE | Result |
| --- | ---: | ---: | ---: | ---: |
| DOT→STORE | 2 | 12 | reference | `0x0000029d` |
| DOT→ADD→STORE | 3 | 13 | +1 | `0x000002a4` |
| DOT→taken BEQ→STORE | 3 | 16 | +4 | `0x0000029d` |

The ADD naturally reads committed DOT state after hold release and costs one
additional cycle. The taken branch adds redirect/refill cost. Correctness
checks prove no stale accumulator value or wrong-path ADDI is observed.

## Headline neural-style kernel

The primary Stage E headline is the N=64 signed INT8 neuron dot product using
the scaling data above. All variants perform 64 useful MACs and produce
`0x000027a5`.

| Metric | Scalar | MAC8 | DOT4ACC |
| --- | ---: | ---: | ---: |
| Useful INT8 MACs | 64 | 64 | 64 |
| Program/retired instructions | 113 | 65 | 17 |
| Cycles through STORE / total cycles | 118 | 70 | 27 |
| CPI | 1.044 | 1.077 | 1.588 |
| MACs/cycle | 0.542 | 0.914 | 2.370 |
| MMAC/s @ 100 MHz | 54.237 | 91.429 | 237.037 |
| Speedup vs scalar | 1.000x | 1.686x | 4.370x |
| Speedup vs MAC8 | 0.593x | 1.000x | 2.593x |
| DOT arithmetic peak utilisation | N/A | N/A | 59.259% |

The DOT speedup exceeds 4x versus this scalar program because DOT reduces both
lane count and the repeated-ADD/SUB software multiplication cost. Versus MAC8,
the result remains below the theoretical 4x lane ratio because ten fixed
startup/drain cycles are included in the complete-CPU measurement.

## Optional 4x16 matrix-vector kernel

Four deterministic 16-element row dot products were evaluated. All four
architectural outputs were checked; the final stored row is `0xfffffe1f`.

| Implementation | Useful MACs | Retired | Cycles | CPI | MMAC/s | Speedup vs scalar | Speedup vs MAC8 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Scalar | 64 | 109 | 114 | 1.046 | 56.140 | 1.000x | 0.614x |
| MAC8 | 64 | 65 | 70 | 1.077 | 91.429 | 1.629x | 1.000x |
| DOT4ACC | 64 | 17 | 27 | 1.588 | 237.037 | 4.222x | 2.593x |

The four expected outputs are `0x000009e0`, `0xfffffc41`, `0x000001d2`, and
`0xfffffe1f`.

## Instruction count, CPI, and performance causes

- Instruction-count reduction is the dominant gain: at N=64 the arithmetic
  plus STORE sequence shrinks from 113 scalar instructions to 65 MAC8 and 17
  DOT instructions.
- Scalar and MAC8 approach CPI 1 as N grows because their arithmetic remains in
  the ordinary five-stage flow.
- DOT CPI is higher because retirement includes a private issue boundary and
  completion drain, but each DOT retirement represents four useful MACs; CPI
  alone therefore understates its useful throughput.
- Startup/drain dominates N=4 and makes DOT slower than MAC8.
- Same-`rd` chaining successfully removes accumulator dependency bubbles.
- Memory feeding and scalar interleaving prevent sustained DOT II=1 and are the
  two largest measured bottlenecks.

## Resource/performance context

Confirmed repository evidence is not perfectly configuration-equivalent:

| Variant/evidence | LUT | FF | DSP48E1 | Memory | Context |
| --- | ---: | ---: | ---: | ---: | --- |
| Historical scalar Phase 12 | 1,146 | 1,473 | 0 | 1 BRAM tile | routed 100 MHz evidence |
| Timing-optimised MAC8 | 1,457 | 1,507 | 1 | 1 BRAM tile | routed 100 MHz evidence |
| Stage D DOT core | 2,162 | 2,471 | 5 | 2 RAMB18E1 | exposed-core synthesis only |

At N=64, effective throughput is 54.237, 91.429, and 237.037 MMAC/s. The DOT
core uses four additional DSPs over MAC8 for a measured 2.593x same-clock
kernel speedup. Indicative throughput per 1000 LUT is approximately 47.3,
62.8, and 109.6 MMAC/s respectively, but the DOT number is synthesis-only and
must not be treated as a routed apples-to-apples efficiency result. Counting
all five Stage D DSPs gives 47.4 MMAC/s per DSP at N=64; counting only the four
DOT DSPs gives 59.3. Neither is an energy-efficiency measurement.

## Verification and limitations

- Focused Stage E benchmark: 233 self-checks, zero failures, 48 CSV rows.
- Every CSV row is marked `PASS`.
- Historical scalar/MAC8 results reproduce exactly.
- No RTL file was modified for Stage E.
- Results assume prepacked register operands for arithmetic-stream tests.
- Memory-fed results use the existing single-port BRAM and conservative hold;
  no scheduling, scratchpad, cache, or DMA optimisation is modeled.
- The deterministic scalar benchmark uses compile-time repeated ADD/SUB for
  small coefficients; it is not a general software multiplier.
- The 100 MHz rate is a common analytical clock applied to XSim cycles. Stage D
  has not yet been placed or routed.

## Exact Stage F recommendation

Stage F should do only repeatable post-route timing characterization of the
completed Stage D core: prove implementation at 100 MHz, run a bounded Fmax
characterization, report setup and hold slack/endpoints, identify critical
paths, confirm routed resources, and verify final DSP register placement
(`AREG`, `BREG`, and relevant output registers). It should not change the ISA,
DOT arithmetic, issue/hold policy, memory system, or benchmark workloads.
