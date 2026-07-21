# Phase 24 Forward-Timing Frontend-Split Optimisation

## Purpose

Phase 24 creates a copied Phase 13-derived CPU to test a timing-friendly frontend split after the Phase 22/23 JUMP-cache timing failures.

The goal was not to overwrite the proven CPU. The original Phase 13 forward-timing CPU remains untouched and Phase 20E remains the best confirmed physical FPGA result at approximately 104 MIPS.

## Files Created

- `rtl/cpu_core_pipeline_forwardtiming_phase24.sv`
- `rtl/fpga_top_phase24_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase24_forwardtiming_mmcm_targets.sv`
- `tb/tb_phase24_forwardtiming_correctness.sv`
- `tb/tb_phase24_final_benchmark.sv`
- `scripts/run_xsim_phase24_performance.ps1`
- `scripts/run_vivado_impl_phase24_forwardtiming_mmcm_100.tcl`
- `scripts/run_vivado_impl_phase24_forwardtiming_mmcm_105.tcl`
- `scripts/run_vivado_impl_phase24_forwardtiming_mmcm_110.tcl`
- `scripts/run_vivado_impl_phase24_forwardtiming_mmcm_115.tcl`
- `scripts/run_vivado_impl_phase24_forwardtiming_mmcm_117.tcl`
- `scripts/run_vivado_impl_phase24_forwardtiming_mmcm_119.tcl`

## RTL Change

The copied CPU was changed conservatively:

- instruction-memory address now comes from a registered request PC;
- instruction-memory request validity is registered;
- redirect requests are staged through pending redirect state;
- synchronous instruction response capture is kept explicit;
- architectural state write protection, x0 behavior and invalid-opcode safety are preserved.

This creates a cleaner frontend timing structure, but it also delays useful instruction fetch after redirects and stalls.

## Correctness Verification

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase24_performance.ps1
```

Focused correctness result:

| Metric | Value |
| --- | ---: |
| Checks | 29 |
| Failures | 0 |
| Result | passed |

Pass message:

```text
PHASE 24 FRONTEND SPLIT CORRECTNESS TEST PASSED
```

The test covers arithmetic, LOAD/STORE, load-use stall behavior, BEQ taken/not-taken, forward and backward JUMP, wrong-path register-write suppression, wrong-path STORE suppression, x0 protection, invalid-opcode safety and pause/resume behavior.

## Benchmark Result

The aligned benchmark uses `programs/final_benchmark.mem`.

| Metric | Value |
| --- | ---: |
| Enabled cycles | 20,000 |
| Retired instructions | 13,254 |
| CPI | 1.508978 |
| Predicted MIPS at 100 MHz | 66.270 |
| Predicted MIPS at 115 MHz | 76.210 |
| Predicted MIPS at 117 MHz | 77.536 |
| Predicted MIPS at 119 MHz | 78.861 |
| Predicted MIPS at 120 MHz | 79.524 |
| CPI improvement versus Phase 18/21 | -22.031% |
| CPI difference versus Phase 22/23 | +27.667% |
| CPI <= 1.190 target | no |

Counter summary:

| Counter | Value |
| --- | ---: |
| Load-use stalls | 1,205 |
| Control flush cycles | 1,444 |
| Fetch wait cycles | 1,205 |
| Memory wait cycles | 1,205 |
| Taken branches | 240 |
| Not-taken branches | 1,204 |
| Jumps | 1,204 |
| Wrong-path flushed | 1,444 |

## Interpretation

The frontend split is functionally safe but overly conservative. It removes the Phase 22/23 predictor-critical path, but it also adds frontend bubbles. The aligned benchmark CPI is worse than the original Phase 18/21 baseline and much worse than the Phase 22/23 JUMP-cache CPI.

Phase 24 is therefore not a CPU performance improvement.

## Decision

Phase 24 should remain an experimental branch:

- do not replace the original Phase 13 CPU;
- do not replace Phase 20E as the best physical result;
- do not claim a Phase 24 hardware performance result;
- use the timing and CPI data to guide a future frontend design with a safe prefetch buffer or narrower redirect path.
