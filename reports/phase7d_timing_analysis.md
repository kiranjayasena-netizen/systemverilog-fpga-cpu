# Phase 7D Timing Analysis

## Purpose

Phase 7D investigates the post-route timing result from Phase 7C. The aim is to document the critical path, explain why the 100 MHz setup timing target is not met, and identify realistic next steps without changing CPU RTL behaviour.

No RTL, testbench, program file, CPU behaviour or instruction encoding was changed in Phase 7D.

## Build Context

- Vivado version: Vivado 2026.1, build 6511674
- Target board: Digilent Basys 3
- Target FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Constraint file: `constraints/basys3.xdc`
- Timing report: `reports/timing/fpga_top_impl_timing_summary.rpt`
- Worst-path report: `reports/timing/fpga_top_impl_worst_paths.rpt`
- Implementation summary: `reports/phase7c_implementation_summary.md`

## Timing Summary

Target clock:

- Clock name: `sys_clk_pin`
- Period: 10.000 ns
- Frequency: 100.000 MHz

Post-route setup result:

| Metric | Result |
| --- | ---: |
| WNS | -1.551 ns |
| TNS | -5707.315 ns |
| Setup failing endpoints | 8,192 |

Post-route hold result:

| Metric | Result |
| --- | ---: |
| WHS | 0.075 ns |
| THS | 0.000 ns |
| Hold failing endpoints | 0 |

The implemented design does not meet the 100 MHz setup timing target. Hold timing is met.

Using the worst setup slack, the estimated minimum period is:

```text
10.000 ns + 1.551 ns = 11.551 ns
```

This gives an estimated maximum frequency of approximately:

```text
1000 / 11.551 ns = 86.6 MHz
```

This is a timing-report estimate only. It is not a measured board frequency.

## Worst Path Summary

Worst setup path:

- Slack: -1.551 ns
- Source: `cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C`
- Destination: `cpu_inst/reg_file_inst/regs_reg[2][12]/D`
- Path group: `sys_clk_pin`
- Path type: setup, max at slow process corner
- Requirement: 10.000 ns
- Data path delay: 11.343 ns
- Logic delay: 3.520 ns, 31.034%
- Route delay: 7.823 ns, 68.966%
- Logic levels: 12
- Logic elements: `CARRY4=1 LUT5=3 LUT6=4 MUXF7=3 MUXF8=1`

The high route-delay share shows that physical placement and routing are a major part of the timing miss, not only the pure logic delay.

## Critical-Path Classification

The worst path is classified as a single-cycle PC/fetch/decode/execute/writeback path.

It begins at the program counter register in the fetch path and ends at a register-file write destination. The signal names in the path show instruction fetch and decode logic, ALU-related logic, memory/register-selection logic and register-file writeback logic all contributing within one clock cycle.

This is consistent with the current educational CPU structure, where one instruction is intended to move through fetch, decode, control, register read, ALU/memory selection and writeback in a single 100 MHz clock period.

## Why This Is Expected

The CPU currently uses a simple single-cycle-style datapath. That is useful for learning because the control flow is easy to understand and the simulation behaviour is direct. The tradeoff is timing: a long combinational path has to settle between two clock edges.

At 100 MHz, the design has 10 ns available for the full path. The post-route worst path needs about 11.551 ns after including clocking effects and routed interconnect delay. This explains the setup timing miss while still preserving correct functional simulation behaviour.

The slow tick used in `fpga_top` helps make CPU steps visible on LEDs, but it does not change the fact that the CPU registers are clocked by the 100 MHz Basys 3 clock. Therefore, the slow tick improves observability for board bring-up but does not close the internal 100 MHz timing path.

## Comparison With Phase 7B Synthesis

| Metric | Phase 7B synthesis | Phase 7C post-route |
| --- | ---: | ---: |
| WNS | -0.600 ns | -1.551 ns |
| TNS | -3879.171 ns | -5707.315 ns |
| WHS | 0.070 ns | 0.075 ns |
| Setup failing endpoints | 8,256 | 8,192 |
| LUTs | 2,915 | 2,983 |
| Flip-flops | 8,314 | 8,314 |

The post-route result is worse than the synthesis estimate because placement and routing add real interconnect delay. This is normal: post-route timing is the more meaningful FPGA timing result.

## Resource Fit

The design fits comfortably in the Basys 3 Artix-7 device:

| Resource | Used | Available | Utilisation |
| --- | ---: | ---: | ---: |
| Slice LUTs | 2,983 | 20,800 | 14.34% |
| Slice registers | 8,314 | 41,600 | 19.99% |
| Block RAM tiles | 0 | 50 | 0.00% |
| DSPs | 0 | 90 | 0.00% |

The issue is not capacity. The issue is that the current single-cycle-style CPU datapath is too long for the 100 MHz target after routing.

## Warning Review

The Phase 7C implementation warnings are not functional blockers, but they guide future work:

- `Route 35-328`: router estimated timing not met. This matches the final post-route setup timing miss and is the main Phase 7D finding.
- `Synth 8-7129`: low byte-address bits on instruction/data memory addresses are unused. This is expected because current memories are word addressed.
- `Netlist 29-101`: `data_memory` contains many primitives and is not ideal for floorplanning. This suggests that memory implementation may deserve attention during timing/resource optimisation.
- `Project 1-236`: implementation-specific XDC commands are ignored during synthesis but used during implementation. This is expected for the current combined implementation flow.

No warning stopped implementation or bitstream generation.

## Realistic Next Options

1. Lower-frequency or slow-enable board demo

   Use the generated bitstream for a cautious first bring-up only if the supervisor accepts the known timing limitation, or adjust the clocking approach for a lower-frequency internal CPU clock in a future controlled design change. The existing slow tick makes LED stepping visible, but by itself it does not close the 100 MHz internal timing path.

2. Multi-cycle redesign

   Split instruction execution across multiple cycles, for example fetch, decode, execute, memory and writeback states. This is the most practical next architecture step because it keeps the design beginner-readable while shortening each clock-cycle path.

3. Pipelining

   Add pipeline registers between stages. This could improve maximum frequency but adds hazards, forwarding, stalls and branch-control complexity. It is better treated as a later extension after a multi-cycle design is understood.

4. BRAM/register-memory redesign

   Rework instruction and data memory inference so memories map cleanly to FPGA block RAM or registered memory structures where appropriate. This may improve resource usage and timing, but it changes memory timing assumptions and must be verified carefully.

## Recommended Next Action

For this summer project, the recommended next action is to document Phase 7D as the timing-closure baseline and then prepare a controlled Phase 7E board bring-up plan. The first board session should not claim 100 MHz timing closure. It should focus on programming the Basys 3, checking reset and enable controls, and comparing LED-observable behaviour with the expected sequence.

After bring-up evidence is captured, the best engineering improvement path is a multi-cycle CPU redesign. That would directly address the critical-path issue while preserving the custom ISA and keeping the design understandable.

## Conclusion

Phase 7D confirms that the design fits in the Basys 3 and builds through bitstream generation, but the implemented single-cycle-style CPU does not meet the 100 MHz setup timing target. The worst path is a PC/fetch/decode/writeback path with significant route delay. Hold timing passes.

This is useful engineering evidence, not a failed simulation baseline. The next work should separate basic board bring-up from timing-closure redesign.
