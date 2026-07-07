# Phase 3B Slow-Tick Synthesis Summary

## Scope

This synthesis run checks the updated Basys 3 FPGA wrapper after adding `slow_tick_generator`. The CPU still uses the real 100 MHz board clock, and `fpga_top` advances the CPU only when `enable_sw && slow_tick` is true.

## Target

- Board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Vivado version: Vivado v2026.1, run on July 7, 2026
- Command: `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_synth.tcl`

## Simulation Regression

The full Vivado XSim regression passed before synthesis. The regression included `slow_tick_generator_tb` and `fpga_top_tb`.

Vivado/XSim reported the known object-directory cleanup warning during elaboration, but the snapshots ran successfully and the regression script exited with code 0.

## Synthesis Status

Passed. Vivado completed `synth_design`, generated utilisation, timing and power reports, and wrote the synthesis checkpoint.

- Errors: 0
- Critical warnings: 0
- Warnings: 7

Main warnings:

- `addr[1:0]` on instruction and data memory is reported as unconnected or having no load. This is expected because both memories use word addressing with `addr[31:2]`.
- Vivado reports that the synthesized `data_memory` cell view has many primitives and is not ideal for floorplanning. This is a useful optimisation note, not a functional error.

## Resource Usage

- Slice LUTs: 2,915 / 20,800, 14.01%
- Slice registers: 8,314 / 41,600, 19.99%
- Block RAM tiles: 0 / 50, 0.00%
- DSPs: 0 / 90, 0.00%

Compared with the Phase 3A baseline, this is an increase of 96 LUTs and 28 registers. This is consistent with adding a configurable slow-tick counter in the FPGA wrapper.

## Timing Summary

- Target clock: 10.000 ns, 100 MHz, `sys_clk_pin`
- Worst negative slack: -0.600 ns
- Total negative slack: -3879.171 ns
- Setup failing endpoints: 8,256
- Worst hold slack: 0.070 ns
- Hold timing: met
- Result: setup timing is not met at the post-synthesis timing estimate

Estimated maximum frequency from the worst setup path is approximately 94.3 MHz, based on a 10.600 ns estimated required path period.

## Worst Path

- Startpoint: `cpu_inst/fetch_inst/pc_inst/pc_reg[17]/C`
- Endpoint: `cpu_inst/data_mem_inst/mem_reg[12][0]/CE`
- Requirement: 10.000 ns
- Data path delay: 10.218 ns
- Logic levels: 12

The worst path still runs through the CPU's single-cycle-style fetch/decode/execute/memory control path. The slow tick makes board observation human-visible, but it does not by itself close the internal 100 MHz timing path because the design is still clocked by the Basys 3 100 MHz clock.

## Power Estimate

- Total on-chip power: 0.093 W
- Dynamic power: 0.022 W
- Device static power: 0.072 W
- Confidence level: medium

The estimate is from synthesized design data without placed/routed implementation or simulation activity.

## Next Steps

- Use the slow tick for initial LED-visible board bring-up when the Basys 3 arrives.
- Do not treat 100 MHz timing as closed yet.
- Keep implementation and bitstream generation for the next step after reviewing this synthesis result.
- Consider a later multi-cycle or pipelined CPU structure if the project goal requires 100 MHz timing closure.
