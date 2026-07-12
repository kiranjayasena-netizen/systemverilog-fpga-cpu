# Phase 13D Data-Memory Forwarding Timing Experiment

## Purpose

Phase 13D investigates whether the remaining Phase 13C data-memory-to-ID/EX operand critical path can be reduced by simplifying the decode-time writeback bypass path.

The experiment is intentionally separate from Phase 13C. The Phase 13C timing-optimised pipeline remains the preferred baseline unless Phase 13D improves practical estimated MIPS.

```text
Practical estimated MIPS = post-route Fmax in MHz / measured aggregate CPI
```

## Phase 13C Baseline

| Metric | Phase 13C |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Best verified Fmax | 109.890 MHz |
| Practical estimated MIPS | ~82.1 |
| LUTs | 1,239 |
| FFs | 1,503 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| WNS at 9.100 ns | +0.166 ns |
| TNS at 9.100 ns | 0.000 ns |

The Phase 13C critical path at 9.100 ns was:

```text
Source:      cpu_inst/data_mem_inst/mem_reg/CLKBWRCLK
Destination: cpu_inst/id_ex_reg_reg[operand_b][16]/R
Data delay:  8.455 ns
Logic delay: 3.834 ns
Route delay: 4.621 ns
```

This suggested that the data-memory read result and writeback/forwarding logic still influenced ID/EX operand timing.

## RTL Change

New separate Phase 13D files:

- `rtl/cpu_core_pipeline_loadtiming.sv`
- `rtl/fpga_top_pipeline_loadtiming.sv`
- `tb/tb_cpu_core_pipeline_loadtiming.sv`
- `scripts/run_vivado_impl_pipeline_loadtiming.tcl`

The controlled RTL change was:

- remove the decode-time WB-to-ID data bypass from `decode_operand_a` and `decode_operand_b`;
- add `wb_decode_stall`, a one-cycle stall when IF/ID needs a source register currently being written in MEM/WB;
- retain EX-stage forwarding from EX/MEM and MEM/WB;
- retain load-use stalls, store-data forwarding, branch operand forwarding, fast `JUMP`, BEQ behaviour, invalid-opcode safety and `x0` protection.

The intent was to remove `data_mem_read_data -> wb_write_data -> decode_operand -> id_ex_reg.operand_*` from the decode operand capture path. Correctness is preserved by waiting one cycle for the register file update when decode would otherwise need the current WB value.

## Simulation Result

Focused transcript:

- `reports/simulation_transcripts/phase13d_loadtiming_focused_20260712_145154.txt`

Full regression transcript:

- `reports/simulation_transcripts/phase13d_xsim_regression_20260712_145218.txt`

Result:

| Metric | Phase 13D |
| --- | ---: |
| Focused checks | 3,262 |
| Focused failures | 0 |
| Full regression | Passed |
| Aggregate cycles | 434 |
| Retired instructions | 319 |
| Aggregate CPI | 1.361 |
| MIPS at 100 MHz | 73.502 |

The full regression passed. Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

The experiment adds 7 aggregate cycles compared with Phase 13C because some consumers that previously used the WB-to-ID bypass now wait one cycle for the register file update.

## Vivado Implementation Result

Command:

```powershell
$env:PHASE13D_PERIOD='9.100'
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_loadtiming.tcl
```

Result at 9.100 ns:

| Metric | Phase 13D |
| --- | ---: |
| WNS | +0.044 ns |
| TNS | 0.000 ns |
| WHS | +0.112 ns |
| THS | 0.000 ns |
| LUTs | 1,249 |
| FFs | 1,506 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Power | 0.094 W |
| Bitstream | Passed |

Worst setup path:

```text
Source:      cpu_inst/ex_mem_reg_reg[rd][0]/C
Destination: cpu_inst/id_ex_reg_reg[operand_b][23]/R
Slack:       +0.044 ns
Data delay:  8.549 ns
Logic delay: 2.562 ns
Route delay: 5.987 ns
Logic levels: 10
```

The direct data-BRAM source is removed from the worst setup path, but the new stall/control path from EX/MEM register metadata to ID/EX operand capture becomes route-heavy.

## Performance Comparison

| Metric | Phase 13C | Phase 13D |
| --- | ---: | ---: |
| Aggregate cycles | 427 | 434 |
| Retired instructions | 319 | 319 |
| Aggregate CPI | 1.339 | 1.361 |
| Fmax | 109.890 MHz | 109.890 MHz |
| Practical estimated MIPS | ~82.1 | ~80.7 |
| LUTs | 1,239 | 1,249 |
| FFs | 1,503 | 1,506 |
| BRAM | 1 tile / 2 RAMB18 | 1 tile / 2 RAMB18 |
| WNS at 9.100 ns | +0.166 ns | +0.044 ns |
| TNS at 9.100 ns | 0.000 ns | 0.000 ns |

Calculation:

```text
109.890 MHz / 1.361 CPI = 80.7 practical estimated MIPS
```

Phase 13D is slower than Phase 13C overall. Even though the design remains timing-clean at 9.100 ns, the CPI penalty is not offset by a higher verified Fmax.

## Conclusion

Phase 13D is a correct but unsuccessful performance experiment.

The removed WB-to-ID bypass did reduce the direct data-memory-to-decode operand dependency, but the replacement stall/control path still limited timing and increased CPI. Phase 13D should not replace Phase 13C as the preferred implementation.

## Recommended Next Work

Keep Phase 13C as the preferred path. A better Phase 13E candidate should avoid adding CPI stalls and instead target the route-heavy operand/stall-control path directly, for example:

- register or localise hazard-control metadata without stalling extra instructions;
- reduce fanout from EX/MEM register identifiers into decode/stall control;
- keep the WB-to-ID data bypass but split load and ALU bypass control;
- investigate a lightweight registered load-result forwarding path only if the measured CPI impact is acceptable.
