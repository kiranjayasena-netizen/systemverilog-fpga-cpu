# Phase 19 Past-100-MIPS Plan

## Purpose

Phase 19 explores honest routes beyond the confirmed Phase 17E physical 100 MIPS result. Phase 19A and 19B now include real board-measured results, while untested or failed timing points remain clearly labelled.

## Current Confirmed Results

| Result type | Value |
| --- | ---: |
| Phase 19A physical result | approximately 102 MIPS at 117.000 MHz |
| Phase 19B physical result | approximately 101 MIPS at 160.000 MHz |
| Phase 17E physical result | approximately 100 MIPS at 115.000 MHz |
| Phase 18 aligned benchmark board result | `0093`, approximately 93 MIPS at 115.000 MHz |
| Phase 18 aligned benchmark CPI | 1.236552 |
| Phase 14G timing-estimated result | approximately 101.8 MIPS |

## Aligned-Benchmark Requirement

The Phase 18 aligned benchmark is more demanding than the Phase 17E FPGA demo workload:

```text
CPI = 1.236552
MIPS = frequency MHz / CPI
```

Clock required for 100 MIPS on the aligned benchmark:

```text
required frequency = 100 * 1.236552 = 123.6552 MHz
```

CPI required for 100 MIPS at 115 MHz:

```text
required CPI = 115 / 100 = 1.15
```

CPI required for 105 MIPS at 115 MHz:

```text
required CPI = 115 / 105 = 1.095
```

Therefore the aligned benchmark cannot exceed 100 MIPS at 115 MHz unless CPI improves from 1.236552 to 1.15 or better.

## Phase 19A Route

Phase 19A keeps the original Phase 13 CPU and demo workload, but pushes the MMCM clock slightly above 115 MHz. This is the least invasive route because it does not change CPU logic.

Phase 19A produced timing-clean candidates up to 117.000 MHz. The 117.000 MHz board test displayed `0102`, making it the current best real FPGA-measured project result.

## Phase 19B Route

Phase 19B tests the Phase 14G six-stage CPU at high generated clocks with a board MIPS counter. It is useful because Phase 14G has the best timing-estimated result.

Phase 19B produced timing-clean candidates at 150, 155 and 160 MHz. The 160 MHz board test displayed `0101`, approximately 101 MIPS. The 166.667 MHz measurement wrapper failed setup timing and is not valid for board testing.

## Future CPI Optimisation Options

Do not implement these without a separate phase and verification plan:

- Static branch prediction or branch target prefetch.
- Branch delay slot style ISA/software scheduling experiment.
- Safer earlier branch resolution.
- Better branch target handling for loops.
- Load-use scheduling or selective load-use reduction.
- Hardware benchmark program alignment with simulation workloads.

## Decision Rule

A new past-100-MIPS result should only be recorded when:

1. Post-route timing is clean.
2. Hold timing passes.
3. Bitstream generation passes.
4. The board physically displays the result.
5. The benchmark/program is identified.
6. The MIPS counter window uses the correct generated CPU clock.
