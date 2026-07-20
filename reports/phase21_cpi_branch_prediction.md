# Phase 21 CPI Branch Prediction

## Purpose

Phase 21 investigates CPI-focused improvements after the confirmed Phase 20E hardware result of `0104`, approximately 104 MIPS at 119.000 MHz. The target is the benchmark-aligned path from Phase 18, where `programs/final_benchmark.mem` measured CPI `1.236552` and displayed `0093` at 115 MHz.

The original Phase 13 forward-timing CPU RTL was not modified. Phase 21 uses a copied experimental CPU:

- `rtl/cpu_core_pipeline_forwardtiming_phase21.sv`

## Baseline

| Metric | Value |
| --- | ---: |
| Best confirmed physical result before Phase 21 | Phase 20E, `0104`, approximately 104 MIPS |
| Aligned benchmark | `programs/final_benchmark.mem` |
| Phase 18 aligned CPI | 1.236552 |
| Phase 18 predicted MIPS at 115 MHz | 93.001 |
| Phase 18 board display at 115 MHz | `0093` |

Target calculations:

| Target | Requirement |
| --- | ---: |
| 100 MIPS at 115 MHz | CPI <= 1.150 |
| 100 MIPS at 117 MHz | CPI <= 1.170 |
| 100 MIPS at 119 MHz | CPI <= 1.190 |
| 100 MIPS at CPI 1.236552 | 123.655 MHz |

## Optimisation Attempted

The Phase 21 CPU copy preserves the Phase 13 forward-timing pipeline shape and adds conservative static BEQ prediction:

- backward BEQ with a negative signed immediate is predicted taken;
- forward BEQ is predicted not taken;
- wrong predictions redirect in EX and invalidate wrong-path frontend work;
- JUMP keeps the existing early redirect behaviour;
- architectural side effects remain protected by valid bits and write-enable controls.

The load-use hazard logic was audited rather than aggressively changed. The existing Phase 13-derived logic already checks whether the following instruction actually uses `rs1` or `rs2`, ignores `x0`, and only stalls for a valid pending load producer. No safe load-use stall reduction was found in this phase.

## Correctness Rules Preserved

- Wrong-path register writes are blocked.
- Wrong-path STOREs are blocked.
- `x0` remains hardwired to zero.
- LOAD/STORE behaviour is preserved.
- Invalid opcodes remain safe.
- Existing debug and performance counters remain available.

## Result

Focused XSim verification passed, but the aligned benchmark CPI did not improve.

| Design | Benchmark | CPI | Predicted MIPS at 115 MHz | Predicted MIPS at 117 MHz | Predicted MIPS at 119 MHz |
| --- | --- | ---: | ---: | ---: | ---: |
| Phase 18 baseline | `final_benchmark.mem` | 1.236552 | 93.001 | 94.618 | 96.235 |
| Phase 21 copied CPU | `final_benchmark.mem` | 1.236552 | 93.001 | 94.618 | 96.235 |

The static backward-BEQ predictor is correct, but it does not help the hot path of the aligned benchmark. The benchmark loop cost is dominated by existing JUMP/control behaviour and load/fetch/memory wait accounting rather than backward BEQ mispredicts.

## Decision

Phase 21A does not replace the original Phase 13 CPU. Phase 20E remains the best confirmed physical FPGA result at approximately 104 MIPS.

Future CPI work should target the actual hot-loop control path, especially JUMP and frontend recovery cost, or use deeper profiling through UART/ILA rather than relying only on the four-digit display.
