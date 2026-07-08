# Phase 7B Synthesis Summary

## Overview

This report captures the Phase 7B Vivado synthesis result for the frozen Phase 7A simulation baseline.

- Date/time: July 8, 2026, approximately 14:01
- Vivado version: Vivado 2026.1, build 6511674
- Target board: Digilent Basys 3
- Target FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Constraint file: `constraints/basys3.xdc`
- Synthesis script: `scripts/run_vivado_synth.tcl`

## Command

The requested command was:

```powershell
vivado -mode batch -source scripts/run_vivado_synth.tcl
```

In this shell, `vivado` was not on `PATH`, so the local Vivado install was used:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_synth.tcl
```

The first sandboxed attempt failed before RTL was read because Vivado could not create/remove a temporary write-test file. The synthesis was then rerun outside the sandbox. The wrapper command reached the tool timeout shortly after reports were written, but `vivado.log` shows `synth_design completed successfully`, `report_power completed successfully`, and the synthesis checkpoint was generated.

## Synthesis Status

Synthesis passed.

- Errors: 0
- Critical warnings: 0
- Vivado log summary during synthesis: `Synthesis finished with 0 errors, 0 critical warnings and 2 warnings.`
- Overall `synth_design` summary: `39 Infos, 7 Warnings, 0 Critical Warnings and 0 Errors encountered.`
- Checkpoint generated: `reports/checkpoints/fpga_top_synth.dcp`

## Generated Evidence

- Utilisation report: `reports/utilisation/fpga_top_synth_utilization.rpt`
- Timing summary report: `reports/timing/fpga_top_synth_timing_summary.rpt`
- Worst-path timing report: `reports/timing/fpga_top_synth_worst_paths.rpt`
- Power report: `reports/power/fpga_top_synth_power.rpt`
- Synthesis log: `vivado.log`
- Synthesis journal: `vivado.jou`
- Checkpoint: `reports/checkpoints/fpga_top_synth.dcp`

The raw Vivado reports and checkpoint are generated artifacts and should not be committed unless they are explicitly selected for documentation.

## Utilisation Summary

| Resource | Used | Available | Utilisation |
| --- | ---: | ---: | ---: |
| Slice LUTs | 2,915 | 20,800 | 14.01% |
| Slice registers | 8,314 | 41,600 | 19.99% |
| Block RAM tiles | 0 | 50 | 0.00% |
| DSPs | 0 | 90 | 0.00% |
| Bonded IOBs | 19 | 106 | 17.92% |

The design still maps the current memories into registers/LUT logic rather than BRAM at this stage.

## Post-Synthesis Timing

Target clock:

- Clock name: `sys_clk_pin`
- Period: 10.000 ns
- Frequency: 100.000 MHz

Timing summary:

| Metric | Result |
| --- | ---: |
| WNS | -0.600 ns |
| TNS | -3879.171 ns |
| Setup failing endpoints | 8,256 |
| WHS | 0.070 ns |
| THS | 0.000 ns |
| Hold failing endpoints | 0 |

Post-synthesis timing is not met for the 100 MHz target. Hold timing is met.

Worst setup path summary:

- Slack: -0.600 ns
- Source: `cpu_inst/fetch_inst/pc_inst/pc_reg[17]/C`
- Destination: `cpu_inst/data_mem_inst/mem_reg[12][0]/CE`
- Requirement: 10.000 ns
- Data path delay: 10.218 ns
- Logic levels: 12
- Likely path category: single-cycle PC/fetch/decode/control path feeding data-memory write enable logic.

This timing miss is consistent with the current educational single-cycle-style CPU structure. It is not a functional simulation failure.

## Power Summary

- Total on-chip power estimate: 0.093 W
- Dynamic power: 0.022 W
- Device static power: 0.072 W
- Junction temperature estimate: 25.5 C
- Confidence level: Medium

The power estimate is vectorless and should be treated as an early synthesis estimate.

## Important Warnings

Non-blocking warnings reviewed:

- `Synth 8-7129`: `addr[1:0]` on `instruction_memory` and `data_memory` are unconnected or have no load. This is expected because the memories use word addressing and ignore the low byte-offset bits.
- `Netlist 29-101`: `data_memory` contains many primitives and is not ideal for floorplanning. This is not blocking for Phase 7B; it may matter later if floorplanning or memory implementation is improved.
- Utilisation report notes that final LUT count after physical optimisation and implementation may differ from post-synthesis utilisation.

No warning is considered blocking for Phase 7B.

## Conclusion

Phase 7B synthesis evidence was captured successfully. The frozen simulation baseline synthesizes for the Basys 3 target without fatal errors or critical warnings. Resource usage is modest, but post-synthesis setup timing does not meet the 100 MHz target.

Next step: Phase 7C implementation and bitstream generation, followed by Phase 7D post-implementation timing analysis.
