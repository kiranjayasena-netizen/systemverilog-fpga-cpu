# Phase 17C Forward-Timing Optimisation Experiment

## Purpose

Phase 17C created a separate experimental optimisation path for the Phase 13 forward-timing five-stage CPU. The fixed-100 MHz board result for the Phase 13 path is approximately 87 MIPS, implying CPI around 1.15 on the loaded hardware demo program.

The goal was to reduce CPI without modifying the known-good Phase 13E/13I RTL.

## Files Added

- `rtl/cpu_core_pipeline_forwardtiming_opt.sv`
- `rtl/fpga_top_pipeline_forwardtiming_opt.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming_opt.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming_opt.tcl`
- `scripts/run_vivado_impl_pipeline_forwardtiming_opt_sweep.tcl`

## Baseline Preserved

The original Phase 13 forward-timing files were not modified:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming.sv`

Phase 14G, Phase 15A/15B and Phase 16A RTL were also left untouched.

## Bottleneck Targeted

The existing load-use detector already avoids the common false-stall cases:

- no stall when the producer is `x0`;
- no stall when the following instruction does not use `rs1`;
- no stall when the following instruction does not use `rs2`;
- no stall for invalid instructions.

Therefore this experiment targeted control-flow recovery instead of removing useful forwarding or changing load-use behaviour.

## RTL Change

The experimental core directly launches an EX-stage redirect target request to instruction BRAM when a taken BEQ resolves in EX.

Baseline flow:

```text
BEQ taken in EX
-> register redirect_pending_valid
-> request target on a later cycle
-> capture synchronous instruction response
```

Phase 17C experimental flow:

```text
BEQ taken in EX
-> drive ex_redirect_target onto instruction_addr in the same cycle
-> save fetch_pending_pc = ex_redirect_target
-> capture the synchronous target response on the following usable cycle
```

The existing ID-stage fast JUMP mechanism is preserved.

## Focused XSim Result

Command sequence used:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_pipeline_forwardtiming_opt.sv tb\tb_cpu_core_pipeline_forwardtiming_opt.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_pipeline_forwardtiming_opt -s tb_cpu_core_pipeline_forwardtiming_opt_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_pipeline_forwardtiming_opt_sim -runall
```

`xelab` built the snapshot but returned the known XSim object-directory cleanup warning. `xsim` ran successfully.

Result:

| Metric | Phase 13E baseline | Phase 17C opt |
| --- | ---: | ---: |
| Tests run | 3,232 | 3,217 |
| Tests failed | 0 | 0 |
| Aggregate cycles | 427 | 424 |
| Aggregate retired | 319 | 319 |
| Aggregate CPI | 1.339 | 1.329 |
| MIPS at 100 MHz from simulation CPI | 74.707 | 75.236 |

The experiment improves the existing aggregate simulation workload by 3 cycles. That is a small CPI gain, not a large fixed-100 MHz board-throughput improvement.

## Vivado 100 MHz Result

Implementation command:

```powershell
vivado -mode batch -source scripts\run_vivado_impl_pipeline_forwardtiming_opt.tcl
```

The first sandboxed run failed before synthesis because Vivado could not complete its writeability probe. The rerun with normal filesystem access completed synthesis, implementation, report generation and bitstream generation.

Final post-route timing did not meet the 10.000 ns constraint:

| Metric | Value |
| --- | ---: |
| Target period | 10.000 ns |
| WNS | -0.552 ns |
| TNS | -2.159 ns |
| WHS | +0.088 ns |
| THS | 0.000 ns |
| LUTs | 1,387 |
| FFs | 1,469 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Power estimate | 0.093 W |
| Bitstream generated | Yes, but not timing-clean |

Generated bitstream path:

- `reports/phase17c_forwardtiming_opt_impl/bitstreams/fpga_top_pipeline_forwardtiming_opt.bit`

This bitstream should not be used as an accepted 100 MHz performance result because setup timing failed.

## Critical Path

Worst setup path:

- Source: `cpu_inst/mem_wb_reg_reg[rd][2]/C`
- Destination: `cpu_inst/instr_mem_inst/instruction_reg/RSTRAMB`
- Slack: `-0.552 ns`
- Data path delay: `10.163 ns`
- Logic delay: `2.821 ns`
- Route delay: `7.342 ns`
- Logic levels: 13

Interpretation:

The direct EX redirect request connects writeback/decode-bypass state through branch comparison and redirect selection into the instruction-BRAM address/control path. This is exactly the timing risk that earlier Phase 13 branch-prefetch work avoided.

## Decision

Phase 17C is functionally correct in simulation but is not accepted as a hardware improvement because it fails the 100 MHz post-route setup timing requirement.

The Phase 13E/13I forward-timing implementation remains the preferred five-stage CPU path.

## Recommended Next Step

Do not keep the direct EX redirect request as the preferred design. The next useful work is either:

- expose more Phase 17A hardware counters through UART/ILA or additional display modes, then optimise the measured dominant bottleneck; or
- pursue a timing-safe control-flow technique, such as registered target prefetch, only if the hardware counter data proves control flushes dominate.
