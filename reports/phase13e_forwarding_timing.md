# Phase 13E Forwarding-Path Timing Optimisation

## Purpose

Phase 13E investigated whether the Phase 13C data-memory/load-result critical path could be improved without adding the CPI penalty seen in Phase 13D.

The goal was to preserve the Phase 13C forwarding behaviour and aggregate benchmark cycle count while restructuring the writeback/load forwarding path so Vivado could route and optimise it more effectively.

## Baseline

Preferred baseline before this phase: Phase 13C timing-optimised pipeline.

| Metric | Phase 13C |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| Best verified period | 9.100 ns |
| Verified Fmax | 109.890 MHz |
| Practical estimated MIPS | ~82.1 |
| LUTs | 1,239 |
| FFs | 1,503 |
| BRAM | 1 tile / 2 RAMB18 |
| WNS at best period | +0.166 ns |
| TNS | 0.000 ns |

Phase 13D removed the decode-time WB-to-ID bypass and added a decode stall. That remained functionally correct, but CPI worsened to 1.361 and practical estimated MIPS dropped to about 80.7. Phase 13E therefore kept the bypass behaviour instead of removing it.

## RTL Change

New separate implementation path:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming.tcl`

Phase 13E preserves the Phase 13C architecture and instruction behaviour. The controlled RTL change splits the writeback source into explicit ALU and LOAD paths:

- `wb_alu_write_data`
- `wb_load_write_data`
- `wb_is_alu`
- `wb_is_load`

It also precomputes decode and EX forwarding select signals for `rs1` and `rs2`. This keeps the WB-to-ID bypass behaviour, EX-stage forwarding, STORE forwarding, load-use stalls, branch/jump behaviour, invalid-opcode safety and `x0` protection.

No instruction encoding, benchmark program, BRAM module, retirement rule or Phase 13C/13D source file was changed.

## Simulation Result

Focused Phase 13E test:

- Transcript: `reports/simulation_transcripts/phase13e_forwardtiming_focused_20260712_193438.txt`
- Tests run: 3,232
- Tests failed: 0
- Result: passed

Full XSim regression:

- Transcript: `reports/simulation_transcripts/phase13e_xsim_regression_20260712_193518.txt`
- Result: passed
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Phase 13E aggregate benchmark:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| MIPS at 100 MHz | 74.707 |

The aggregate cycle count and CPI match Phase 13C.

## Vivado Implementation

Target:

- Board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top_pipeline_forwardtiming`
- Vivado: 2026.1

Implementation commands:

```powershell
$env:PHASE13E_PERIOD='9.100'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_pipeline_forwardtiming.tcl
$env:PHASE13E_PERIOD='8.900'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_pipeline_forwardtiming.tcl
```

The first Vivado attempt failed before synthesis because Vivado could not remove a temporary `.hdi.isWriteableTest` file. The same implementation command was rerun with normal filesystem access and completed successfully. This was a tool/file-access issue, not an RTL compile failure.

Best verified implementation result:

| Metric | Phase 13E |
| --- | ---: |
| Best verified period | 8.900 ns |
| Verified Fmax | 112.360 MHz |
| WNS | +0.059 ns |
| TNS | 0.000 ns |
| WHS | +0.040 ns |
| THS | 0.000 ns |
| LUTs | 1,359 |
| FFs | 1,510 |
| BRAM | 1 tile / 2 RAMB18 |
| DSP | 0 |
| Power estimate | 0.092 W |
| Bitstream | generated |

Report paths:

- `reports/phase13e_timing/perf_directive_8p900ns/utilisation/fpga_top_pipeline_forwardtiming_impl_utilization.rpt`
- `reports/phase13e_timing/perf_directive_8p900ns/timing/fpga_top_pipeline_forwardtiming_impl_timing_summary.rpt`
- `reports/phase13e_timing/perf_directive_8p900ns/timing/fpga_top_pipeline_forwardtiming_impl_worst_paths.rpt`
- `reports/phase13e_timing/perf_directive_8p900ns/route/fpga_top_pipeline_forwardtiming_route_status.rpt`
- `reports/phase13e_timing/perf_directive_8p900ns/power/fpga_top_pipeline_forwardtiming_impl_power.rpt`

## Critical Path

At 8.900 ns, the worst setup path is still in the load/operand path family:

- Source: `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`
- Destination: `cpu_inst/id_ex_reg_reg[operand_a][24]/CE`
- Data path delay: 8.527 ns
- Logic delay: 4.139 ns
- Route delay: 4.388 ns
- Logic levels: 8

The path remains data-memory/forwarding/control related, but Phase 13E gives enough timing margin to verify an 8.900 ns implementation.

## Performance Comparison

Practical estimated MIPS is calculated as:

```text
post-route verified Fmax in MHz / measured aggregate CPI
```

| Architecture | CPI | Verified Fmax | Practical MIPS | LUTs | FFs | BRAM | Best WNS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 13C timingopt | 1.339 | 109.890 MHz | ~82.1 | 1,239 | 1,503 | 1 tile / 2 RAMB18 | +0.166 ns at 9.100 ns |
| Phase 13D loadtiming | 1.361 | 109.890 MHz | ~80.7 | 1,249 | 1,506 | 1 tile / 2 RAMB18 | +0.044 ns at 9.100 ns |
| Phase 13E forwardtiming | 1.339 | 112.360 MHz | ~83.9 | 1,359 | 1,510 | 1 tile / 2 RAMB18 | +0.059 ns at 8.900 ns |

Phase 13E improves practical estimated MIPS by about 2.2% versus Phase 13C while preserving CPI.

## Conclusion

Phase 13E is successful and should replace Phase 13C as the current preferred measured FPGA implementation path.

The optimisation does not reach the 90 MIPS target, but it improves verified Fmax without sacrificing architectural correctness or aggregate CPI. The remaining bottleneck is still the data-memory/load-result path into operand and branch/decode control.

## Recommended Next Step

Phase 13F should focus on the remaining data-memory-to-ID/EX operand critical path. The most promising next experiment is to reduce high-fanout operand/control enables or add a carefully measured register boundary only if the resulting Fmax gain outweighs any CPI cost.
