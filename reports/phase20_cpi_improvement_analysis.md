# Phase 20 CPI Improvement Analysis

## Purpose

Phase 20 starts from the confirmed Phase 19A result of approximately 102 MIPS on the Basys 3 and looks for real CPU performance improvements. The main question is whether the benchmark-aligned Phase 18 workload can exceed 100 MIPS honestly by reducing CPI, not just by changing the workload or counting method.

## Phase 18 Aligned Benchmark Baseline

| Metric | Value |
| --- | ---: |
| Benchmark | `programs/final_benchmark.mem` |
| XSim enabled cycles | 20,000 |
| XSim retired instructions | 16,174 |
| CPI | 1.236552 |
| Predicted MIPS at 115 MHz | 93.001 |
| FPGA board display at 115 MHz | `0093` |

The Phase 18 result is important because it uses the same instruction-memory image and the same `retire_valid` definition in simulation and on the FPGA.

## Required Improvement

```text
MIPS = clock frequency in MHz / CPI
```

| Target | Calculation | Result |
| --- | --- | ---: |
| Required CPI for 100 MIPS at 115 MHz | 115 / 100 | 1.150000 |
| Required CPI for 100 MIPS at 117 MHz | 117 / 100 | 1.170000 |
| Required clock for 100 MIPS at CPI 1.236552 | 100 * 1.236552 | 123.655 MHz |

At 117 MHz, the aligned benchmark still needs CPI to improve from 1.236552 to 1.170000 or better to reach 100 MIPS.

## Bottlenecks

The Phase 20 benchmark run on the experimental CPU copy measured:

| Counter | Value |
| --- | ---: |
| Data hazard stalls | 1,470 |
| Load-use stalls | 1,470 |
| Control flush cycles | 1,763 |
| Fetch wait cycles | 1,470 |
| Memory wait cycles | 1,470 |
| Taken branches | 294 |
| Not-taken branches | 1,469 |
| Jumps | 1,469 |
| Wrong-path flushed instructions | 2,057 |

The dominant costs remain control-flow redirects and load-use/fetch-wait behaviour around synchronous memory.

## Optimisation Options

| Optimisation | Expected effect | Risk | Implement in Phase 20? |
| --- | --- | --- | --- |
| Static backward-branch prediction | Reduce control flushes in loops that use backward BEQ | Medium | yes, in copied CPU only |
| Load-use stall refinement | Reduce unnecessary stalls | Medium | audited; original logic is already selective |
| Branch delay slot | Reduce branch penalty | Changes ISA/programming model | analysis only |
| Zero-overhead loop instruction | Big loop improvement | Changes ISA | analysis only |
| Higher MMCM clock | Higher MIPS if timing passes | High | scripts prepared for sweep |
| Six-stage redirect timing fix | Could improve Phase 19B 166.667 MHz path | High | analysis only in this pass |

## Phase 20 Conclusion

The safe CPU-copy change was implemented and verified, but it did not improve CPI on `programs/final_benchmark.mem`. The benchmark's hot loop uses already-early JUMP handling and forward BEQs, so static backward-BEQ prediction does not reduce the main loop cost.

The next honest routes are:

- test higher timing-clean MMCM frequencies for the original Phase 19A path;
- change the benchmark/program structure only if labelled as a different workload;
- use a more invasive but separately verified control-flow optimisation in a future CPU copy.
