# Phase 22 Forward-Timing Optimisation

## Purpose

Phase 22 creates a copied Phase 13-derived CPU to test a frontend/control-flow CPI improvement without modifying the original Phase 13 CPU RTL.

## Files

Created:

- `rtl/cpu_core_pipeline_forwardtiming_phase22.sv`
- `tb/tb_phase22_forwardtiming_correctness.sv`
- `tb/tb_phase22_final_benchmark.sv`
- `scripts/run_xsim_phase22_performance.ps1`
- `rtl/fpga_top_phase22_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase22_forwardtiming_mmcm_targets.sv`
- `scripts/run_vivado_impl_phase22_forwardtiming_mmcm_115.tcl`
- `scripts/run_vivado_impl_phase22_forwardtiming_mmcm_117.tcl`
- `scripts/run_vivado_impl_phase22_forwardtiming_mmcm_119.tcl`
- `scripts/run_vivado_impl_phase22_forwardtiming_mmcm_120.tcl`

Untouched:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/cpu_core_pipeline6.sv`

## Optimisation Implemented

The Phase 22 CPU copy adds a one-entry unconditional JUMP target cache:

1. When a JUMP is decoded, the CPU records the JUMP PC and target.
2. If the same JUMP PC is fetched again, the frontend requests the cached target instead of the sequential wrong-path PC.
3. When the JUMP reaches decode, the CPU can consume the already-returning target response.
4. If the target response is not ready, the CPU falls back to the original fast-JUMP redirect path.

The first implementation attempt exposed a useful correctness issue: the metadata was updated to the cached target, but the BRAM address still used the sequential fetch PC. The fix was to drive `instruction_addr` from `jump_cache_target` on a cache hit so request metadata and BRAM address remain aligned.

## Correctness Verification

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase22_performance.ps1
```

Result:

| Metric | Value |
| --- | ---: |
| Checks | 29 |
| Failures | 0 |
| Result | passed |

The correctness test includes a repeated backward-JUMP loop to exercise the cache path.

Pass message:

```text
PHASE 22 FORWARDTIMING CORRECTNESS TEST PASSED
```

## Benchmark Result

The aligned benchmark improves in simulation:

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
| CPI <= 1.190 target | met |

## Vivado 119 MHz Implementation

The 119 MHz implementation was run because that clock is the first point where the improved CPI predicts more than 100 MIPS.

| Metric | Value |
| --- | ---: |
| Target clock | 119.000 MHz |
| Period | 8.403 ns |
| WNS | -1.258 ns |
| TNS | -246.378 ns |
| WHS | +0.087 ns |
| THS | 0.000 ns |
| LUTs | 1,959 |
| FFs | 2,147 |
| BRAM | 1 Block RAM Tile |
| DSP | 0 |
| MMCM | 1 |
| Bitstream | not generated |

Critical path summary:

- source: `impl/cpu_inst/mem_wb_reg_reg[rd][1]/C`
- destination: instruction BRAM control/address path, including `instr_mem_inst/instruction_reg/RSTRAMARSTRAM`
- data path delay: 9.166 ns
- logic delay: 2.500 ns
- route delay: 6.666 ns
- logic levels: 11

The added frontend cache improves simulated CPI but makes timing substantially worse at the required 119 MHz point. Therefore Phase 22 does not produce a valid hardware candidate yet.

## Decision

Phase 22 is a useful CPI proof in simulation, but it does not replace Phase 20E because the 119 MHz implementation fails timing. No new board MIPS result is claimed.

Recommended next work:

- retime or simplify the cache hit path;
- avoid feeding the cache decision into the instruction BRAM address path in the same cycle;
- consider a registered frontend prediction stage if CPI gain can survive the extra cycle;
- rerun timing only after the frontend path is made timing-aware.
