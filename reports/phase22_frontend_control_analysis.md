# Phase 22 Frontend and Control-Flow Analysis

## Purpose

Phase 22 starts from the Phase 21 result: the copied backward-BEQ predictor was correct, but it did not improve the aligned benchmark. This report identifies the next useful CPI target.

## Baseline Counter Data

Aligned benchmark:

- `programs/final_benchmark.mem`

Phase 18 / Phase 21 baseline:

| Metric | Value |
| --- | ---: |
| Enabled cycles | 20,000 |
| Retired instructions | 16,174 |
| CPI | 1.236552 |
| Predicted MIPS at 115 MHz | 93.001 |
| Predicted MIPS at 117 MHz | 94.618 |
| Predicted MIPS at 119 MHz | 96.235 |
| Load-use stalls | 1,470 |
| Control flush cycles | 1,763 |
| Fetch wait cycles | 1,470 |
| Memory wait cycles | 1,470 |
| Taken branches | 294 |
| Not-taken branches | 1,469 |
| Jumps | 1,469 |
| Wrong-path flushed | 2,057 |

## Why Phase 21 Did Not Help

The Phase 21 static backward-BEQ predictor did not improve CPI because the aligned benchmark is not dominated by backward BEQ misprediction. The hot path contains many unconditional JUMPs, and the frontend still pays recovery/fetch costs after redirects.

The useful bottlenecks are therefore:

- JUMP/control redirect behaviour;
- frontend recovery after redirects;
- stale or wrong-path frontend work;
- fetch wait cycles;
- load/fetch/memory wait interactions.

## Phase 22 Direction

The next useful optimisation should target unconditional JUMP/frontend recovery rather than another broad branch-prediction change.

Phase 22 tests a small one-entry JUMP target cache in a copied CPU:

- learn the PC and target of an unconditional JUMP;
- when that JUMP PC is fetched again, pre-request the cached target;
- when the JUMP is decoded, consume the already-returning target response;
- fall back to the original redirect path if the cache is not ready.

The design still preserves the existing architectural safety rules:

- wrong-path register writes are blocked;
- wrong-path STOREs are blocked;
- `x0` remains hardwired to zero;
- invalid opcodes remain safe;
- LOAD/STORE and BEQ behaviour remain unchanged.

## Target CPI

| Goal | Required CPI |
| --- | ---: |
| 100 MIPS at 115 MHz | <= 1.150 |
| 100 MIPS at 117 MHz | <= 1.170 |
| 100 MIPS at 119 MHz | <= 1.190 |

The primary Phase 22 simulation target is CPI <= 1.190, which would predict at least 100 MIPS at the already-demonstrated 119 MHz clock point.
