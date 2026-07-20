# Phase 21 Phase 19B 166 MHz Timing Follow-Up

## Purpose

This report records the Phase 21 follow-up analysis for the Phase 19B six-stage 166.667 MHz timing failure. The original Phase 14G CPU RTL was not modified.

## Baseline Six-Stage Result

| Metric | Value |
| --- | ---: |
| Best physical six-stage board result | Phase 19B |
| CPU | Phase 14G six-stage pipeline |
| Clock | 160.000 MHz |
| Board display | `0101` |
| Meaning | approximately 101 MIPS |
| 166.667 MHz wrapper status | failed setup timing |

The 160 MHz result is valid board evidence. The 166.667 MHz Phase 19B wrapper is not valid board evidence because setup timing failed.

## Failed 166.667 MHz Path

Recorded failure summary:

| Item | Value |
| --- | --- |
| Source | `op_ex_reg_reg[operand_b][25]/C` |
| Destination | `fetch_pc_reg_reg[30]/D` |
| Requirement | 6.000 ns |
| Data path delay | 6.121 ns |
| Setup miss | approximately 0.102 ns |
| Likely area | execute/control redirect into fetch-PC update logic |

The path suggests the critical timing pressure is around branch/JUMP redirect generation and fetch PC update. This is consistent with a deeper pipeline carrying operand/control information into the execute stage and then feeding a high-fanout frontend redirect decision.

## Safe Fix Options

These should only be attempted in a copied six-stage CPU variant, not in `rtl/cpu_core_pipeline6.sv`:

| Option | Expected benefit | Risk |
| --- | --- | --- |
| Reduce redirect mux depth | Shorter fetch-PC update path | Medium |
| Duplicate high-fanout redirect signals | Less routing delay | Low to medium |
| Simplify branch target datapath | Less EX-to-IF logic | Medium |
| Split branch compare and target calculation | Shorter single path | High; can change CPI/control penalty |
| Move JUMP target earlier | Could reduce control penalty | Medium; must protect stale fetch responses |

## Phase 21 Decision

No copied six-stage Phase 21 CPU was created in this pass. The first Phase 21 priority was the five-stage aligned benchmark CPI experiment. Since that experiment did not improve CPI, the six-stage 166.667 MHz path remains analysis-only.

Future six-stage work should start with a copied `cpu_core_pipeline6_phaseXX.sv` and a focused control-flow regression before any timing claim is made.
