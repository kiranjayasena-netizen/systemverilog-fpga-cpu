# Phase 3C Implementation Summary

## Scope

This report records the first placed-and-routed Vivado implementation result for the Basys 3 `fpga_top` design with the slow LED-visible CPU stepping path included.

No physical FPGA programming or board testing has been performed.

## Target

- Board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Vivado version: Vivado v2026.1, run on July 7, 2026
- Command: `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl.tcl`

## Status

- XSim regression before implementation: passed
- Implementation flow: passed
- Bitstream generation: passed
- Bitstream file generated locally: `reports/bitstreams/fpga_top.bit`
- Errors: 0
- Critical warnings: 0

The generated bitstream is a local build artifact and should not be committed.

## Resource Usage

- Slice LUTs: 2,983 / 20,800, 14.34%
- Slice registers: 8,314 / 41,600, 19.99%
- Block RAM tiles: 0 / 50, 0.00%
- DSPs: 0 / 90, 0.00%

## Timing Result

- Target clock: 10.000 ns, 100 MHz, `sys_clk_pin`
- Post-route WNS: -1.551 ns
- Post-route TNS: -5707.315 ns
- Setup failing endpoints: 8,192
- Worst hold slack: 0.075 ns
- Hold timing: met
- Result: 100 MHz setup timing is not met after placement and routing

Estimated maximum frequency from the worst setup slack is approximately 86.6 MHz, based on an estimated 11.551 ns required path period.

## Worst Path Summary

- Startpoint: `cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C`
- Endpoint: `cpu_inst/reg_file_inst/regs_reg[2][12]/D`
- Requirement: 10.000 ns
- Data path delay: 11.343 ns
- Logic levels: 12

The worst path is still consistent with the simple single-cycle-style CPU datapath. It starts at the program counter, passes through instruction fetch/decode/control and execute/writeback selection logic, and ends at a register file write data flop.

The slow tick makes CPU state changes visible on LEDs for board bring-up, but it does not by itself close the internal 100 MHz timing path because all registers are still clocked by the Basys 3 100 MHz clock.

## Power Estimate

- Total on-chip power: 0.081 W
- Dynamic power: 0.010 W
- Device static power: 0.072 W
- Confidence level: medium

The estimate is from the routed design, but no simulation activity file was provided.

## Main Warnings

- `addr[1:0]` on instruction and data memory is reported as unconnected or having no load. This is expected because both memories use word addressing with `addr[31:2]`.
- Vivado reports that the synthesized `data_memory` cell view has many primitives and is not ideal for floorplanning.
- Router estimated timing was not met. The final post-route timing summary confirms the 100 MHz setup timing miss.

## Interpretation

Phase 3C proves that the design can complete Vivado synthesis, optimisation, placement, routing and bitstream generation for the Basys 3 target. The result is not timing-clean at 100 MHz, so it should be treated as an implementation baseline rather than final timing closure.

## Recommended Next Action

Document the 100 MHz timing miss and decide whether the next step is:

- a controlled lower-effective-frequency board demo using the existing slow enable path, with timing assumptions documented carefully, or
- a later CPU timing improvement phase, such as multi-cycle execution, registered memory outputs or a pipelined datapath.

Do not claim hardware validation until the Basys 3 has actually been programmed and observed.
