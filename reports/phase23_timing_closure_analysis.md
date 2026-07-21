# Phase 23 Timing-Closure Analysis

## Purpose

Phase 23 investigates whether the Phase 22 one-entry unconditional JUMP target cache can be retimed enough to recover FPGA timing while keeping the aligned-benchmark CPI improvement.

The proven hardware baseline remains Phase 20E:

- CPU: original Phase 13 forward-timing five-stage pipeline
- Clock: 119.000 MHz MMCM-generated
- Board display: `0104`
- Result: approximately 104 MIPS

No Phase 23 board result is claimed.

## Background

Phase 22 improved the aligned benchmark CPI from `1.236552` to `1.181963`, predicting `100.680` MIPS at 119 MHz for `programs/final_benchmark.mem`. The 119 MHz implementation failed setup timing:

- WNS: -1.258 ns
- TNS: -246.378 ns
- WHS: +0.087 ns
- THS: 0.000 ns
- Bitstream: not generated

The likely cause was a long frontend path through the JUMP target cache lookup, predictor hit, target selection and fetch request logic.

## Phase 23 Approach

Phase 23 creates a copied CPU:

- `rtl/cpu_core_pipeline_forwardtiming_phase23.sv`

The original Phase 13 CPU and the Phase 22 CPU are not modified.

The Phase 23 copy keeps the one-entry unconditional JUMP target cache, but retimes lookup metadata:

- register the JUMP-cache lookup hit;
- register the predicted target;
- use the registered predictor result for a later fetch request;
- clear predictor metadata on reset, redirect and stalls where stale metadata would be unsafe;
- keep architectural recovery and wrong-path side-effect protection intact.

This removes the Phase 22 same-cycle `fetch PC -> cache compare -> predictor hit -> target select -> fetch request` path, but it does not remove all long frontend/control paths.

## Result Summary

| Design | CPI | Predicted MIPS @119 MHz | 119 MHz timing | Hardware status |
| --- | ---: | ---: | --- | --- |
| Phase 18 baseline | 1.236552 | 96.235 | passed at 115 MHz only | board displayed `0093` at 115 MHz |
| Phase 21 BEQ predictor | 1.236552 | 96.235 | not run | simulation only |
| Phase 22 JUMP cache | 1.181963 | 100.680 | failed, WNS -1.258 ns | no bitstream |
| Phase 23 retimed JUMP cache | 1.181963 | 100.680 | failed, WNS -0.981 ns | no bitstream |

Phase 23 preserved the CPI gain from Phase 22 and improved the 119 MHz WNS by about 0.277 ns, but it still missed timing.

## Timing Interpretation

The worst 119 MHz Phase 23 path is no longer described as only a direct predictor compare path. The reported critical path crosses memory/control/frontend logic:

- source: `impl/cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`
- destination: `impl/cpu_inst/if_id_reg_reg[pc][30]/D`
- data path delay: 9.290 ns
- logic delay: 5.190 ns
- route delay: 4.100 ns
- logic levels: 13

The path still includes branch/control signals and the retimed predictor target logic. Retiming the predictor was useful, but a larger frontend/control restructuring would be needed before this copied CPU can become a high-frequency board candidate.

## Decision

Phase 23 is a useful timing-closure experiment, but it does not replace Phase 20E:

- Correctness: passed in XSim.
- CPI target: met in XSim.
- 119 MHz timing: failed.
- 117 MHz timing: failed.
- 115 MHz timing: failed.
- Bitstream: not generated for the tested Phase 23 targets.
- Hardware result: none.

Phase 20E remains the best confirmed physical FPGA result.

