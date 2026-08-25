# Stage 13 — Cycle-Level Bottleneck Characterization

Stage 13 leaves the Stage 12 RTL and all earlier baselines frozen. The
analysis testbench classifies every active execution cycle using hierarchical
observability only. Primary classifications are mutually exclusive; overlap
is recorded as a flag so cycles are not double-counted.

## Measured totals

| Benchmark | Total | ALU | VLOAD hit | VLOAD miss issue | Load WB | VSTORE | Control/idle/other | Overlap |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| REG_VADD | 4 | 4 | 0 | 0 | 0 | 0 | 0 | 0 |
| ARRAY_ADD | 21 | 4 | 3 | 5 | 5 | 4 | 0 | 4 |
| XOR | 13 | 4 | 3 | 1 | 1 | 4 | 0 | 3 |
| VSRA | 13 | 4 | 3 | 1 | 1 | 4 | 0 | 3 |

All primary-category sums equal the measured cycle counts. There are no
idle or control bubbles in these unchanged workloads.

## ARRAY_ADD evidence

The eight loads split into three useful hits and five misses. Each miss has
one architectural read issue cycle followed by one `S_LOAD_WB` cycle. Hits,
ALU operations, and stores retire in one cycle. The full timeline is in
`reports/vector_stage13/stage13_array_timeline.txt`.

Useful hit lead time was two cycles for the observed addresses 1, 2, and 3.
There was one two-outstanding interval. Four speculative requests were made;
three were consumed as hits, leaving one useless request.

## Lower bound and bottleneck

For the current frozen FSM, the measured lower bound is:

`4 ALU + 4 VSTORE + 3 one-cycle hit loads + 5 two-cycle miss loads = 21`.

The observed ARRAY_ADD result equals this bound. The remaining cost is not
idle time or an unexploited control bubble; it is the five architectural
load misses and their mandatory writeback phases.

Stage 11’s deeper visibility and Stage 12’s second in-flight request are
working, but they do not change the number of loads that are valid at the
architectural consumption point for this fixed instruction schedule.

## Recommendation

The next experiment should be a narrowly scoped Stage 14 investigation of
load-miss/writeback sequencing or a fused load-completion path, subject to
the existing in-order architectural contract. Additional prefetch entries
or deeper lookahead are not justified by this cycle trace alone.
