# Thesis Extension Plan

## Frozen baseline

All future work must identify `summer-project-final` as its starting point.
The baseline is H1.3b/T2 on `xc7a35tcpg236-1`, validated at 93 MHz PASS 5/5.
Every thesis candidate should report cycles, validated MHz, execution time,
MAC/cycle, MMAC/s, LUT, FF, BRAM, DSP, critical path, and result correctness.

Headline comparison points are:

- Stage H memory-fed N=128: 263 cycles, 45.26 MMAC/s.
- Stage J J1 N=128: 358 cycles, 33.2514 MMAC/s.
- Stage J J2 2x64: 331 cycles, 35.9637 MMAC/s.
- Stage L MAC8/DOT4ACC: 134/43 cycles for 128 useful MACs.
- Final physical point: 93 MHz PASS 5/5; 94 MHz failed.

## Candidate research directions

| Candidate | Measured motivation | Likely change and metrics | Risk / originality | Thesis suitability | Priority |
|---|---|---|---|---|---|
| Local memory / scratchpad | Stage H improves from 294 to 263, while Stage J falls to 358 because feed and control work remain visible. | Add a bounded local-data structure or explicitly managed scratchpad; measure BRAM/LUT, feed stalls, cycles, MMAC/s, and timing. | Memory arbitration and software management are substantial, but the trade-off is directly evidenced and researchable. | Strong | **1** |
| Pipeline/timing partitioning | Final frequency is 93 MHz and the limiting path is BRAM/control/forwarding, not simply DSP arithmetic. | Compare narrow pipeline/control partitions; measure WNS, Fmax bracket, resources, II, and application throughput. | Timing experiments can change semantics and require rigorous equivalence. | Strong | 2 |
| Instruction-memory/control scalability | 256 words prevented a simple 4x128 Stage J program. | Larger/alternative instruction storage or compact loop support; measure capacity, branch/control overhead, area, and timing. | May become a memory-system/ISA project rather than an arithmetic study. | Good | 3 |
| Wider SIMD/DOT widths | Four lanes yield a 3.1163x DOT over MAC8 arithmetic result. | Evaluate 8/16 lanes; measure DSP/LUT/BRAM bandwidth, routing, II, frequency, and useful application throughput. | DSP and routing growth may erase arithmetic gains; clear quantitative novelty. | Strong | 4 |
| Quantized inference support | Complete workloads expose program/control overhead beyond MAC arithmetic. | Add saturation, rounding, requantization, or activation support; measure numerical fidelity, instruction count, area, and timing. | Semantics and golden-reference complexity increase quickly. | Good | 5 |
| DMA/streaming movement | Memory-fed and complete-program rates are far below register-resident arithmetic rate. | Add explicit movement/streaming engine; measure overlap, BRAM use, control cost, and end-to-end throughput. | Major architecture expansion; difficult to isolate from a CPU study. | Strong but broad | 6 |

## Recommended primary direction

The recommended thesis question is:

> How should a small FPGA CPU balance int8 arithmetic parallelism, local data
> feeding, and timing closure for representative AI inference workloads?

This is stronger than simply adding more AI instructions because the completed
measurements already show three interacting limits: DOT arithmetic can sustain
II=1, Stage H removes a measurable memory-feed bottleneck, and the physical
clock is ultimately limited by a BRAM/control/forwarding path. A thesis can
therefore make a defensible contribution by comparing one controlled local-data
or pipeline organization against the frozen baseline, rather than collecting
instructions without an end-to-end hypothesis.

The first experiment should be a small, explicitly managed local-data design
or equivalent feed optimization, with the CPU ISA and DOT semantics initially
held constant. It must be a separate branch and must preserve the baseline
comparison table above.

## Suggested thesis protocol

1. Reproduce the baseline from `docs/reproducibility.md` and the final results
   CSV.
2. State one hypothesis and one architectural change.
3. Run independent functional/golden tests before physical implementation.
4. Measure complete-program cycles and instruction/stall breakdowns.
5. Run the same default-flow timing/resource methodology.
6. Compare end-to-end useful work per second, not only instruction latency.
7. Report rejected candidates and negative results with the same care as wins.

No candidate above is implemented by this document. This plan is a research
handoff, not a new architecture stage.
