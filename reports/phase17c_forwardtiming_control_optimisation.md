# Phase 17C Forward-Timing Control-Hazard Optimisation

## Purpose

Phase 17C targets the measured control-flow bottleneck in the Phase 13 forward-timing five-stage pipeline.

Confirmed Basys 3 hardware readings from the Phase 17 profiler at the fixed 100 MHz board clock:

| Display mode | Value | Meaning |
| --- | ---: | --- |
| MIPS | `0087` | approximately 87 MIPS |
| CPI x100 | `0115` | approximately 1.15 CPI |
| Control-flush percentage x100 | `1250` | approximately 12.50% of cycles |

This makes control-hazard recovery the dominant measured CPI target for Phase 17C.

## Baseline Inspection

The original Phase 13 forward-timing CPU was left unchanged:

- `rtl/cpu_core_pipeline_forwardtiming.sv`

Inspection showed that unconditional JUMP is already handled early in the Phase 13 baseline. The baseline has ID-stage fast-JUMP request logic equivalent to:

```systemverilog
id_jump_fast_request
id_jump_redirect
jump_response_pending
jump_response_pc
```

The instruction-BRAM address can already be driven from the ID-stage JUMP target. Therefore Phase 17C is not a "move JUMP from EX to ID" change; that optimisation already exists in the known-good design.

## Experimental Optimisation

The separate Phase 17C CPU copy is:

- `rtl/cpu_core_pipeline_forwardtiming_opt.sv`

The experiment keeps the existing ID-stage fast-JUMP path and instead tests a more aggressive control-hazard optimisation: directly launching the EX-stage redirect target request for older taken BEQ/JUMP redirects.

Baseline EX redirect flow:

```text
taken BEQ/JUMP resolves in EX
-> register redirect_pending_valid
-> launch target request on a later cycle
-> accept synchronous instruction-BRAM response
```

Phase 17C experimental flow:

```text
taken BEQ/JUMP resolves in EX
-> drive ex_redirect_target onto instruction_addr immediately
-> save target PC as fetch response metadata
-> accept synchronous target response on the next usable cycle
```

This is intended to remove one target-request launch cycle for EX-stage redirects, mainly taken BEQ.

## Verification Result

Focused simulation was rerun on 2026-07-16:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_pipeline_forwardtiming_opt.sv tb\tb_cpu_core_pipeline_forwardtiming_opt.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_pipeline_forwardtiming_opt -s tb_cpu_core_pipeline_forwardtiming_opt_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_pipeline_forwardtiming_opt_sim -runall
```

The first elaboration attempt hit the known XSim generated-object cleanup warning. Re-running elaboration with normal filesystem access built the snapshot successfully.

Simulation result:

| Metric | Phase 13 baseline aggregate | Phase 17C opt aggregate |
| --- | ---: | ---: |
| Tests run | 3,232 | 3,217 |
| Tests failed | 0 | 0 |
| Cycles | 427 | 424 |
| Retired instructions | 319 | 319 |
| CPI | 1.339 | 1.329 |
| MIPS at 100 MHz from simulation CPI | 74.707 | 75.236 |

The experiment is functionally correct in focused simulation and reduces the aggregate benchmark by 3 cycles.

## Vivado Result

Implementation script:

- `scripts/run_vivado_impl_pipeline_forwardtiming_opt.tcl`

Post-route result at 10.000 ns:

| Metric | Value |
| --- | ---: |
| WNS | -0.552 ns |
| TNS | -2.159 ns |
| WHS | +0.088 ns |
| THS | 0.000 ns |
| LUTs | 1,387 |
| FFs | 1,469 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Bitstream generation | completed, but not timing-clean |

The 7-segment opt wrapper also failed 10 ns setup timing:

| Wrapper | WNS | TNS | WHS |
| --- | ---: | ---: | ---: |
| `fpga_top_pipeline_forwardtiming_opt` | -0.552 ns | -2.159 ns | +0.088 ns |
| `fpga_top_pipeline_forwardtiming_opt_perf7seg` | -0.705 ns | -4.684 ns | +0.034 ns |

## Timing Interpretation

Worst path for the non-display opt top:

- Source: `cpu_inst/mem_wb_reg_reg[rd][2]/C`
- Destination: `cpu_inst/instr_mem_inst/instruction_reg/RSTRAMB`
- Slack: -0.552 ns
- Data path delay: 10.163 ns
- Logic delay: 2.821 ns
- Route delay: 7.342 ns
- Logic levels: 13

The direct EX redirect request puts branch/forwarding/writeback-related control back onto the instruction-BRAM address/control path. That is not timing-safe on this implementation.

## Decision

Phase 17C is not accepted as a hardware improvement.

Reasons:

- It passes focused simulation.
- It improves aggregate simulation CPI slightly.
- It fails 100 MHz post-route setup timing.
- It does not produce a valid timing-clean FPGA MIPS result.

The accepted Phase 17 hardware baseline remains the original Phase 13 forward-timing CPU profiling bitstream:

- MIPS display: `0087`
- CPI x100 display: `0115`
- Control flush x100 display: `1250`

## FPGA Test Procedure

The Phase 17C opt bitstream should not be used as an accepted performance result because timing fails. If it is programmed for experiment only:

1. Program the opt bitstream.
2. Press BTNC reset.
3. Set SW0 = 1.
4. Read SW3:SW1 = `000` for MIPS.
5. Read SW3:SW1 = `001` for CPI x100.
6. Read SW3:SW1 = `011` for control-flush percentage x100.
7. Compare against the accepted baseline `0087`, `0115`, `1250`.
8. Treat any improvement as unsupported unless timing is fixed.

## Recommended Next Step

Do not keep the direct EX redirect request as the preferred design. The next useful Phase 17 work should be timing-safe:

- keep the original Phase 13 fast-JUMP path;
- avoid branch-compare-to-instruction-BRAM-address combinational paths;
- consider high-frequency hardware measurement for the existing timing-clean Phase 13I result;
- or collect more detailed hardware counter data before attempting another CPI optimisation.
