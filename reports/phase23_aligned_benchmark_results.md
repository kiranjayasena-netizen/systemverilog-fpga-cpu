# Phase 23 Aligned Benchmark Results

## Purpose

This report records the Phase 23 XSim result for the shared aligned benchmark:

- `programs/final_benchmark.mem`

The goal is to compare the retimed JUMP target-cache CPU against the Phase 18/21 baseline and the Phase 22 JUMP-cache experiment using the same instruction memory image and the same retirement definition.

## Simulation Command

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase23_performance.ps1
```

## Correctness Result

| Metric | Value |
| --- | ---: |
| Checks | 29 |
| Failures | 0 |
| Result | passed |

Pass message:

```text
PHASE 23 FORWARDTIMING CORRECTNESS TEST PASSED
```

## CPI Comparison

| Design | Benchmark | CPI | Predicted MIPS at 115 MHz | Predicted MIPS at 117 MHz | Predicted MIPS at 119 MHz | Predicted MIPS at 120 MHz |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Phase 18 baseline | `final_benchmark.mem` | 1.236552 | 93.001 | 94.618 | 96.235 | 97.044 |
| Phase 21 BEQ predictor | `final_benchmark.mem` | 1.236552 | 93.001 | 94.618 | 96.235 | 97.044 |
| Phase 22 JUMP cache | `final_benchmark.mem` | 1.181963 | 97.296 | 98.988 | 100.680 | 101.526 |
| Phase 23 retimed JUMP cache | `final_benchmark.mem` | 1.181963 | 97.296 | 98.988 | 100.680 | 101.526 |

Phase 23 preserves the Phase 22 CPI improvement:

- improvement versus Phase 18/21 baseline: 4.415%;
- difference versus Phase 22 CPI: 0.000%;
- CPI <= 1.190 target: yes.

## Raw Phase 23 Metrics

| Metric | Value |
| --- | ---: |
| Enabled cycles | 20,000 |
| Retired instructions | 16,921 |
| CPI | 1.181963 |
| Predicted MIPS at 100 MHz | 84.605 |
| Predicted MIPS at 115 MHz | 97.296 |
| Predicted MIPS at 117 MHz | 98.988 |
| Predicted MIPS at 119 MHz | 100.680 |
| Predicted MIPS at 120 MHz | 101.526 |
| Load-use stalls | 1,538 |
| Control flush cycles | 1,845 |
| Fetch wait cycles | 1,538 |
| Memory wait cycles | 1,538 |
| Taken branches | 307 |
| Not-taken branches | 1,538 |
| Jumps | 1,538 |
| Wrong-path flushed | 1,229 |

## Interpretation

The CPI result is good enough to predict more than 100 MIPS at 119 MHz, but simulation alone is not hardware evidence. The implementation must also be timing-clean and physically board-tested. The Phase 23 implementation did not meet timing, so the result remains simulation-only.

