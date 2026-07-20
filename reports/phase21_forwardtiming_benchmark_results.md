# Phase 21 Forward-Timing Benchmark Results

## Purpose

This report records the Phase 21 copied-CPU verification and aligned-benchmark CPI result. Phase 21 is a simulation and candidate-generation phase; it does not claim a new board-measured MIPS result.

## Files Added

- `rtl/cpu_core_pipeline_forwardtiming_phase21.sv`
- `tb/tb_phase21_forwardtiming_correctness.sv`
- `tb/tb_phase21_final_benchmark.sv`
- `scripts/run_xsim_phase21_performance.ps1`
- `rtl/fpga_top_phase21_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase21_forwardtiming_mmcm_targets.sv`
- `scripts/run_vivado_impl_phase21_forwardtiming_mmcm_115.tcl`
- `scripts/run_vivado_impl_phase21_forwardtiming_mmcm_117.tcl`
- `scripts/run_vivado_impl_phase21_forwardtiming_mmcm_119.tcl`
- `scripts/run_vivado_impl_phase21_forwardtiming_mmcm_120.tcl`

The original `rtl/cpu_core_pipeline_forwardtiming.sv` file was left untouched.

## Simulation Command

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase21_performance.ps1
```

## Correctness Result

| Metric | Value |
| --- | ---: |
| Checks | 26 |
| Failures | 0 |
| Result | passed |

The correctness test printed:

```text
PHASE 21 FORWARDTIMING CORRECTNESS TEST PASSED
```

Coverage includes arithmetic, LOAD/STORE, BEQ taken/not-taken, a backward branch prediction case, JUMP, `x0` protection, invalid-opcode safety and no-stuck execution.

## Aligned Benchmark Result

Benchmark:

- `programs/final_benchmark.mem`

Measured by XSim:

| Metric | Value |
| --- | ---: |
| Enabled cycles | 20,000 |
| Retired instructions | 16,174 |
| CPI | 1.236552 |
| Predicted MIPS at 100 MHz | 80.870 |
| Predicted MIPS at 115 MHz | 93.001 |
| Predicted MIPS at 117 MHz | 94.618 |
| Predicted MIPS at 119 MHz | 96.235 |
| Data hazard stalls | 1,470 |
| Load-use stalls | 1,470 |
| Control flush cycles | 1,763 |
| Fetch wait cycles | 1,470 |
| Memory wait cycles | 1,470 |
| Taken branches | 294 |
| Not-taken branches | 1,469 |
| Jumps | 1,469 |
| Wrong-path flushed | 2,057 |

Comparison against Phase 18:

| Design | CPI | Predicted MIPS at 115 MHz | Improvement |
| --- | ---: | ---: | ---: |
| Phase 18 baseline | 1.236552 | 93.001 | baseline |
| Phase 21 copied CPU | 1.236552 | 93.001 | 0.0% |

## FPGA Candidate Scripts

The Phase 21 benchmark-wrapper implementation scripts are prepared but were not run in this pass:

```powershell
vivado -mode batch -source scripts\run_vivado_impl_phase21_forwardtiming_mmcm_115.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase21_forwardtiming_mmcm_117.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase21_forwardtiming_mmcm_119.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase21_forwardtiming_mmcm_120.tcl
```

Expected output folders:

- `reports/phase21_forwardtiming_mmcm_impl/115/`
- `reports/phase21_forwardtiming_mmcm_impl/117/`
- `reports/phase21_forwardtiming_mmcm_impl/119/`
- `reports/phase21_forwardtiming_mmcm_impl/120/`

No Phase 21 board result is claimed until a timing-clean bitstream is programmed and physically observed.

## Interpretation

The Phase 21 copied CPU is functionally correct but does not improve the aligned benchmark. At CPI `1.236552`, the aligned benchmark would need about 123.655 MHz to reach 100 MIPS.

Phase 20E remains the best confirmed physical FPGA result:

- original Phase 13 CPU;
- 119.000 MHz generated clock;
- board display `0104`;
- approximately 104 MIPS.
