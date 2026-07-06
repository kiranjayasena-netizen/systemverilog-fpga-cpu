# Phase 3A.1 Timing Analysis

## Baseline Result

The first Basys 3 synthesis baseline passed synthesis for:

- Target board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Target clock: 10.000 ns, 100 MHz

Post-synthesis timing was not met:

- Worst negative slack: -2.017 ns
- Total negative slack: -16592.328 ns
- Hold timing: met, worst hold slack 0.070 ns
- Setup failing endpoints: 8,256

Using the 10.000 ns target period and -2.017 ns WNS, the estimated maximum frequency is approximately:

```text
1000 / (10.000 + 2.017) = 83.22 MHz
```

This is a post-synthesis estimate. Final timing must still be checked after placement and routing.

## Worst Path Summary

The detailed timing report shows the worst path as:

- Startpoint: `cpu_inst/fetch_inst/pc_inst/pc_reg[11]/C`
- Endpoint: `cpu_inst/data_mem_inst/mem_reg[0][0]/CE`
- Path group: `sys_clk_pin`
- Requirement: 10.000 ns
- Data path delay: 11.635 ns
- Logic delay: 3.177 ns
- Route delay estimate: 8.458 ns
- Logic levels: 14

The same slack appears on several endpoints in `data_mem_inst.mem_reg[0][*]/CE`, so the issue is not one isolated bit. The path starts at the program counter, passes through synthesized combinational logic associated with instruction selection/decode, ALU address calculation and data memory write-enable generation, then ends at the data memory write enable.

This is best classified as a single-cycle instruction fetch/decode/execute/memory path, with the final failing endpoint in the data memory write path.

## Likely Cause

The current CPU is intentionally simple and single-cycle-style. In one clock period, the design may need to:

1. Use the current PC to select an instruction.
2. Decode the instruction fields.
3. Generate control signals.
4. Read register operands.
5. Calculate an ALU result or memory address.
6. Decide whether data memory should write.
7. Drive data memory write-enable logic.

That is a long combinational path for a 100 MHz Artix-7 target, especially with instruction memory and data memory currently inferred as distributed register/LUT logic rather than block RAM. The timing miss is therefore expected at this stage and does not mean the CPU is functionally broken.

The route estimate dominates the path delay in the post-synthesis report. This can change after implementation, but the amount of failing setup slack indicates that the architecture should be reviewed before claiming 100 MHz timing closure.

## Possible Fixes

- Run the first board LED demo with a slower effective CPU enable so visible hardware behaviour can be tested even if the CPU does not yet close at 100 MHz.
- Add a clock-enable divider in the FPGA wrapper for LED-visible execution while keeping the board clock at 100 MHz.
- Convert the CPU to a multi-cycle design later, so fetch, decode, execute, memory and writeback do not all have to complete in one cycle.
- Register instruction memory and data memory outputs later to break long combinational paths.
- Infer or instantiate block RAM for memories where appropriate.
- Add pipelining later as a larger architecture extension.

## Recommended Next Action

Keep the current result as the Phase 3A timing baseline. For immediate board bring-up, add a slow CPU enable path in the FPGA wrapper or drive `enable_sw` manually so the LED demo can be observed safely.

For the next architecture phase, decide whether the CPU should move toward a simple multi-cycle design before attempting full 100 MHz timing closure.
