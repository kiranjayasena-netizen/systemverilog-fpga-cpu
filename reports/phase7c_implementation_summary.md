# Phase 7C Implementation Summary

## Overview

This report captures the Phase 7C Vivado implementation and bitstream-generation result for the frozen Phase 7A simulation baseline after Phase 7B synthesis.

- Date/time: July 8, 2026, approximately 14:22
- Vivado version: Vivado 2026.1, build 6511674
- Target board: Digilent Basys 3
- Target FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Constraint file: `constraints/basys3.xdc`
- Implementation script: `scripts/run_vivado_impl.tcl`

No CPU RTL, testbench, program file or instruction encoding was changed for this phase.

## Command

The implementation flow was run with the local Vivado installation:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl.tcl
```

The batch command exited successfully.

## Implementation Status

| Step | Result |
| --- | --- |
| `synth_design` | Passed |
| `opt_design` | Passed |
| `place_design` | Passed |
| `route_design` | Passed |
| `write_bitstream` | Passed |

Bitstream generation completed successfully. This confirms that the design can be built through the Vivado implementation flow, but it does not claim physical Basys 3 board testing.

## Generated Evidence

- Implementation utilisation report: `reports/utilisation/fpga_top_impl_utilization.rpt`
- Post-route timing summary report: `reports/timing/fpga_top_impl_timing_summary.rpt`
- Post-route worst-path timing report: `reports/timing/fpga_top_impl_worst_paths.rpt`
- Implementation power report: `reports/power/fpga_top_impl_power.rpt`
- Implementation checkpoint: `reports/checkpoints/fpga_top_impl.dcp`
- Bitstream: `reports/bitstreams/fpga_top.bit`
- Vivado log: `vivado.log`
- Vivado journal: `vivado.jou`

The raw Vivado reports, checkpoint, bitstream, log and journal are generated artifacts and should not be committed unless explicitly selected for documentation.

## Post-Route Utilisation

| Resource | Used | Available | Utilisation |
| --- | ---: | ---: | ---: |
| Slice LUTs | 2,983 | 20,800 | 14.34% |
| Slice registers | 8,314 | 41,600 | 19.99% |
| Block RAM tiles | 0 | 50 | 0.00% |
| DSPs | 0 | 90 | 0.00% |
| Bonded IOBs | 19 | 106 | 17.92% |

The current memories are still implemented without BRAM inference in this build.

## Post-Route Timing

Target clock:

- Clock name: `sys_clk_pin`
- Period: 10.000 ns
- Frequency target: 100.000 MHz

Timing summary:

| Metric | Result |
| --- | ---: |
| WNS | -1.551 ns |
| TNS | -5707.315 ns |
| Setup failing endpoints | 8,192 |
| WHS | 0.075 ns |
| THS | 0.000 ns |
| Hold failing endpoints | 0 |

Post-route setup timing does not meet the 100 MHz target. Hold timing is met.

Using the worst setup slack as an estimate, the worst path implies an approximate minimum clock period of 11.551 ns, or about 86.6 MHz. This is only a timing-report estimate and should be treated as an implementation-analysis guide, not as a board-tested frequency.

## Worst Path Summary

- Slack: -1.551 ns
- Source: `cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C`
- Destination: `cpu_inst/reg_file_inst/regs_reg[2][12]/D`
- Path group: `sys_clk_pin`
- Requirement: 10.000 ns
- Data path delay: 11.343 ns
- Logic levels: 12
- Route share of data path delay: approximately 69%

The worst path is consistent with the existing single-cycle-style CPU structure. It starts at the program counter, passes through instruction fetch/decode/control and datapath logic, and ends at a register-file writeback destination.

## Comparison With Phase 7B Synthesis

| Metric | Phase 7B synthesis | Phase 7C post-route |
| --- | ---: | ---: |
| Slice LUTs | 2,915 | 2,983 |
| Slice registers | 8,314 | 8,314 |
| WNS | -0.600 ns | -1.551 ns |
| TNS | -3879.171 ns | -5707.315 ns |
| WHS | 0.070 ns | 0.075 ns |

The post-route setup timing result is worse than the post-synthesis estimate, which is expected once placement and routing delays are included. Hold timing remains clean.

## Power Summary

- Total on-chip power estimate: 0.081 W
- Dynamic power: 0.010 W
- Device static power: 0.072 W
- Junction temperature estimate: 25.4 C
- Confidence level: Medium

The power estimate is based on Vivado implementation analysis and should be treated as an early estimate until real switching activity or board measurements are available.

## Important Warnings

Non-blocking warnings reviewed:

- `Route 35-328`: router estimated timing not met. This matches the final post-route timing summary and is the main Phase 7D timing-analysis item.
- `Synth 8-7129`: low byte-address bits on instruction/data memory addresses are unused. This is expected because the current memories use word addressing.
- `Netlist 29-101`: `data_memory` contains many primitives and is not ideal for floorplanning. This is not blocking for Phase 7C, but memory implementation may be worth revisiting during timing/resource optimisation.
- `Project 1-236`: implementation-specific XDC commands are ignored during synthesis but used during implementation. This is expected in the combined implementation script.

No warning blocked implementation or bitstream generation.

## Conclusion

Phase 7C implementation completed successfully and generated a bitstream for the Basys 3 target. The implemented design does not meet the 100 MHz setup timing target, while hold timing passes.

Next step: Phase 7D post-route timing analysis. That phase should document the critical path in more detail and decide whether the project should proceed with a lower-frequency board demo, a clock-enable demonstration only, or a future multi-cycle/timing-closure redesign.
