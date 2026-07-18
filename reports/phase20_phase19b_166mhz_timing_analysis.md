# Phase 20 Phase 19B 166 MHz Timing Analysis

## Purpose

Phase 20F analyses the failed Phase 19B 166.667 MHz six-stage measurement wrapper. The goal is to understand the limiter without modifying the proven Phase 14G CPU RTL.

## Known Failed Path

| Metric | Value |
| --- | ---: |
| CPU | Phase 14G six-stage pipeline |
| Target clock | 166.667 MHz |
| Requirement | 6.000 ns |
| Source | `impl/cpu_inst/op_ex_reg_reg[operand_b][25]/C` |
| Destination | `impl/cpu_inst/fetch_pc_reg_reg[30]/D` |
| Data path delay | 6.121 ns |
| Setup slack | -0.102 ns |
| TNS | -0.287 ns |
| Hold slack | +0.098 ns |
| Logic delay | 3.173 ns |
| Route delay | 2.948 ns |
| Logic levels | 12 (`CARRY4=9 LUT3=1 LUT6=2`) |

## Interpretation

The path runs from execute-stage operand/control logic into fetch PC update. That is consistent with branch/jump redirect target generation remaining on a high-frequency path. The delay is split almost evenly between logic and route, so a small RTL cleanup might help, but it is not a trivial wrapper-only fix.

## Safe Options

Possible future experiments, all in copied files only:

- reduce fetch redirect mux depth;
- register or duplicate high-fanout redirect enables;
- simplify branch target datapath;
- split branch comparison and redirect target calculation if CPI impact is acceptable;
- create `cpu_core_pipeline6_phase20.sv` only if the change remains local and testable.

## Deferred Changes

No Phase 14G RTL change is made in Phase 20. The existing Phase 19B 160 MHz board-tested result remains the best physical six-stage result, and the 166.667 MHz result remains invalid as board evidence because setup timing failed.

## Recommended Next Step

If six-stage work resumes, create a copied `cpu_core_pipeline6_phase20.sv`, add focused control-flow regression, then rerun the 166.667 MHz implementation before any board test.
