# Phase 23 Forward-Timing Optimisation

## Purpose

Phase 23 continues the CPI-focused work from Phase 22. Phase 22 proved that targeting unconditional JUMP/frontend behaviour can improve aligned-benchmark CPI, but its implementation failed 119 MHz timing. Phase 23 tries to keep that CPI improvement while retiming the JUMP target-cache path.

## Files Added

- `rtl/cpu_core_pipeline_forwardtiming_phase23.sv`
- `tb/tb_phase23_forwardtiming_correctness.sv`
- `tb/tb_phase23_final_benchmark.sv`
- `scripts/run_xsim_phase23_performance.ps1`
- `rtl/fpga_top_phase23_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase23_forwardtiming_mmcm_targets.sv`
- `scripts/run_vivado_impl_phase23_forwardtiming_mmcm_115.tcl`
- `scripts/run_vivado_impl_phase23_forwardtiming_mmcm_117.tcl`
- `scripts/run_vivado_impl_phase23_forwardtiming_mmcm_119.tcl`
- `scripts/run_vivado_impl_phase23_forwardtiming_mmcm_120.tcl`

## RTL Strategy

The Phase 23 CPU is copied from `rtl/cpu_core_pipeline_forwardtiming_phase22.sv`.

The main change is retiming the JUMP cache lookup:

- Phase 22 used a same-cycle fetch-PC cache compare in the frontend request path.
- Phase 23 registers the lookup hit and target before using them for a predicted fetch request.
- Registered predictor metadata is cleared on reset, redirects and unsafe stalls.
- JUMP confirmation and recovery still use the real decoded JUMP instruction and target.

This keeps the predictor limited to unconditional JUMP. BEQ, LOAD, STORE, x0 behaviour and invalid-opcode safety are preserved.

## Correctness Verification

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase23_performance.ps1
```

Focused correctness result:

| Metric | Value |
| --- | ---: |
| Checks | 29 |
| Failures | 0 |
| Result | passed |

Pass message:

```text
PHASE 23 FORWARDTIMING CORRECTNESS TEST PASSED
```

Covered behaviours include arithmetic, LOAD/STORE, BEQ taken/not-taken, JUMP forward, JUMP backward loop, repeated JUMP predictor use, wrong-path register suppression, wrong-path STORE suppression, x0 protection and invalid-opcode safety.

## Benchmark Result

The aligned benchmark result is unchanged versus Phase 22:

| Metric | Value |
| --- | ---: |
| Enabled cycles | 20,000 |
| Retired instructions | 16,921 |
| CPI | 1.181963 |
| Predicted MIPS at 115 MHz | 97.296 |
| Predicted MIPS at 117 MHz | 98.988 |
| Predicted MIPS at 119 MHz | 100.680 |
| Predicted MIPS at 120 MHz | 101.526 |
| CPI improvement versus Phase 18/21 | 4.415% |
| CPI difference versus Phase 22 | 0.000% |
| CPI <= 1.190 target | yes |

Counters:

| Counter | Value |
| --- | ---: |
| Load-use stalls | 1,538 |
| Control flush cycles | 1,845 |
| Fetch wait cycles | 1,538 |
| Memory wait cycles | 1,538 |
| Taken branches | 307 |
| Not-taken branches | 1,538 |
| Jumps | 1,538 |
| Wrong-path flushed | 1,229 |

The Windows `xelab` object-directory cleanup warning appeared after snapshot creation, matching earlier local XSim behaviour. Both Phase 23 simulations ran and passed.

## Implementation Decision

The retiming helped but not enough. Vivado implementation still failed timing at 119, 117 and 115 MHz, so no Phase 23 bitstream was generated and no board MIPS result is claimed.

Phase 23 does not replace Phase 20E.

## Recommended Next Step

The next useful CPI/timing experiment should split more of the redirect/frontend update path, or evaluate a smaller predictor feature that does not touch the instruction BRAM request, IF/ID update and redirect recovery logic in the same timing cone.

