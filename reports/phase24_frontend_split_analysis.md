# Phase 24 Frontend Split Analysis

## Purpose

Phase 24 is a timing-friendly frontend/control-flow experiment after the Phase 22 and Phase 23 JUMP-cache work. Phase 20E remains the best confirmed physical FPGA result:

- CPU: original Phase 13 forward-timing five-stage pipeline
- Clock: 119.000 MHz MMCM-generated
- Board display: `0104`
- Result: approximately 104 MIPS

Phase 22 and Phase 23 showed that reducing JUMP/frontend recovery can improve aligned-benchmark CPI, but the added predictor/cache path did not close timing. Phase 24 tests a broader frontend split to see whether the fetch request path can be made easier to time.

## Starting Point

The Phase 24 copied CPU starts from the original Phase 13 forward-timing CPU, not the Phase 22 or Phase 23 predictor copies. This avoids inheriting the immediate JUMP-cache compare/target-select path that failed timing.

The original Phase 13 CPU RTL, Phase 14G CPU RTL, Phase 22 CPU and Phase 23 CPU were not modified.

## Comparison

| Design | CPI | Predicted MIPS @119 MHz | Timing result | Status |
| --- | ---: | ---: | --- | --- |
| Phase 18 baseline | 1.236552 | 96.235 | 115 MHz timing-clean | board displayed `0093` |
| Phase 21 BEQ predictor | 1.236552 | 96.235 | not run | simulation only |
| Phase 22 JUMP cache | 1.181963 | 100.680 | 119 MHz WNS -1.258 ns | no bitstream |
| Phase 23 retimed JUMP cache | 1.181963 | 100.680 | 115/117/119 MHz failed | no bitstream |
| Phase 24 frontend split | 1.508978 | 78.861 | 100/105 MHz pass, 110 MHz fails | timing-clean only at low frequencies |

## Intended Frontend Split

The likely frontend problem before Phase 24 was:

```text
fetch PC -> predictor / redirect decision -> memory request -> IF/ID update
```

The Phase 24 experiment separates the instruction-memory request from the immediate fetch PC path:

```text
IF request register -> instruction memory response capture -> decode/execute redirect confirmation
```

The copied CPU adds registered instruction-memory request state:

- `imem_request_pc_reg`
- `imem_request_valid_reg`

Redirects are converted into pending registered redirect requests before issuing the next instruction-memory request. This is deliberately conservative and aims to reduce direct combinational pressure into the fetch address.

## Resulting Trade-Off

The experiment is functionally correct but not performance-positive. Registering the request path adds frontend latency and reduces aligned-benchmark retired instructions over the fixed 20,000-cycle XSim window:

- Phase 18/21 retired instructions: 16,174
- Phase 22/23 retired instructions: 16,921
- Phase 24 retired instructions: 13,254

Phase 24 therefore demonstrates an important trade-off: a frontend split can improve structural timing clarity, but if it adds fetch bubbles without a compensating predictor or prefetch buffer, CPI can become much worse.

## Conclusion

Phase 24 should not replace Phase 20E or the original Phase 13 CPU path. It is useful as a negative engineering result:

- correctness is preserved;
- the copied CPU can close timing at 100 and 105 MHz;
- CPI regresses to 1.508978;
- 110 MHz fails setup timing;
- no board result is claimed.

The next useful direction is a smaller frontend recovery improvement or a prefetch buffer that hides the added request latency without putting predictor logic back on the critical PC path.
