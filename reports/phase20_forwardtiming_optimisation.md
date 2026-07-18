# Phase 20 Forward-Timing Optimisation

## Purpose

Phase 20 creates a copied experimental CPU path derived from the original Phase 13 forward-timing CPU. The original Phase 13 RTL remains untouched.

## Files

Created:

- `rtl/cpu_core_pipeline_forwardtiming_phase20.sv`
- `tb/tb_phase20_forwardtiming_correctness.sv`
- `tb/tb_phase20_final_benchmark.sv`
- `scripts/run_xsim_phase20_performance.ps1`
- `rtl/fpga_top_phase20_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase20_forwardtiming_mmcm_targets.sv`
- `scripts/run_vivado_impl_phase20_forwardtiming_mmcm_115.tcl`
- `scripts/run_vivado_impl_phase20_forwardtiming_mmcm_117.tcl`
- `scripts/run_vivado_impl_phase20_forwardtiming_mmcm_118.tcl`
- `scripts/run_vivado_impl_phase20_forwardtiming_mmcm_119.tcl`
- `scripts/run_vivado_impl_phase20_forwardtiming_mmcm_120.tcl`

## RTL Change

The CPU copy adds conservative static backward-BEQ prediction:

- BEQ with a negative immediate is predicted taken in ID.
- The predicted target is requested early through the existing instruction-memory response path style.
- If the branch resolves not taken in EX, the CPU redirects to `PC + 4`.
- Wrong-path frontend state is invalidated before wrong-path instructions can retire or cause side effects.
- Existing JUMP, LOAD/STORE, forwarding, x0 and invalid-opcode behaviour is preserved.

Load-use logic was audited. The original Phase 13 forward-timing CPU already stalls only when:

- the producer is a valid LOAD in ID/EX,
- the producer destination is not x0,
- the following instruction actually uses the matching source register.

No additional safe load-use reduction was found in this fast pass.

## Simulation Result

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase20_performance.ps1
```

Focused correctness result:

| Metric | Value |
| --- | ---: |
| Checks | 26 |
| Failures | 0 |
| Result | passed |

Benchmark result using `programs/final_benchmark.mem`:

| Metric | Phase 18 baseline | Phase 20 copy |
| --- | ---: | ---: |
| Enabled cycles | 20,000 | 20,000 |
| Retired instructions | 16,174 | 16,174 |
| CPI | 1.236552 | 1.236552 |
| Predicted MIPS at 100 MHz | 80.870 | 80.870 |
| Predicted MIPS at 115 MHz | 93.001 | 93.001 |
| Predicted MIPS at 117 MHz | 94.618 | 94.618 |

The Phase 20 CPU copy is functionally correct in the focused test, but it does not improve the aligned benchmark CPI.

## Interpretation

The static backward-BEQ predictor is correct, but it does not help the current final benchmark because the hot loop uses the already-optimised early JUMP path and a forward BEQ for loop exit. The aligned benchmark remains limited by a combination of control redirects and load-use/fetch-wait behaviour.

## FPGA Candidate Status

The Phase 20 copied-CPU MMCM wrapper and scripts were prepared for 115, 117, 118, 119 and 120 MHz. In the fast-pass completion, the long Vivado sweep for this copied CPU was not rerun after the earlier Vivado temporary-file access issue. No copied-CPU board MIPS result is claimed.

Candidate bitstream paths, if timing-clean when built:

- `reports/phase20_forwardtiming_mmcm_impl/115/bitstreams/fpga_top_phase20_forwardtiming_mmcm_115.bit`
- `reports/phase20_forwardtiming_mmcm_impl/117/bitstreams/fpga_top_phase20_forwardtiming_mmcm_117.bit`
- `reports/phase20_forwardtiming_mmcm_impl/118/bitstreams/fpga_top_phase20_forwardtiming_mmcm_118.bit`
- `reports/phase20_forwardtiming_mmcm_impl/119/bitstreams/fpga_top_phase20_forwardtiming_mmcm_119.bit`
- `reports/phase20_forwardtiming_mmcm_impl/120/bitstreams/fpga_top_phase20_forwardtiming_mmcm_120.bit`

## Decision

This copied CPU optimisation does not replace Phase 19A or Phase 20E. The current best measured result after the separate original-CPU frequency extension is Phase 20E, approximately 104 MIPS at 119 MHz.

## Recommended Next Step

Use the Phase 20E original-CPU frequency-extension scripts first. They preserve the known-good CPU and are more likely to produce a useful hardware result than the CPI copy, which did not improve aligned benchmark CPI.
