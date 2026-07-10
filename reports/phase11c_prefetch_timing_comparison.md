# Phase 11C BRAM-Aware Prefetch Timing Comparison

## Purpose

Phase 11C creates a separate FPGA implementation path for the BRAM-aware instruction-prefetch CPU variant and compares it against the Phase 10H BRAM-aware CPU baseline.

Phase 11B proved simulation correctness and showed a CPI improvement for the prefetch CPU. Phase 11C checks the other side of the trade-off: whether the added prefetch logic still synthesizes, implements and meets timing on the Basys 3 target.

## Separate FPGA Path

New Phase 11C files:

- `rtl/fpga_top_multicycle_bram_prefetch.sv`
- `scripts/run_vivado_synth_multicycle_bram_prefetch.tcl`
- `scripts/run_vivado_impl_multicycle_bram_prefetch.tcl`

The top-level wrapper instantiates `cpu_core_multicycle_bram_prefetch`. It keeps the existing Basys 3 clocking approach:

- The real 100 MHz board clock remains the only clock.
- `slow_tick_generator` creates a clock-enable pulse for LED-visible stepping.
- The CPU advances only when the enable switch is on and the slow tick fires.
- The wrapper uses the repo's existing constrained board port names `rst_btn` and `enable_sw`, corresponding to reset and enable.

LED debug mapping:

| LED bits | Signal |
| --- | --- |
| `led[3:0]` | `pc[5:2]` |
| `led[7:4]` | `opcode_reg` |
| `led[8]` | `valid_instr` |
| `led[9]` | `reg_write` |
| `led[10]` | `mem_write` |
| `led[13:11]` | prefetch CPU FSM `state` |
| `led[14]` | `prefetch_valid` |
| `led[15]` | `alu_result[0]` |

## Phase 10H Baseline

Existing BRAM-aware CPU result:

| Metric | Phase 10H BRAM-aware CPU |
| --- | ---: |
| LUTs | 937 |
| FFs | 1,211 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| WNS | +3.172 ns |
| TNS | 0.000 ns |
| Estimated Fmax | ~146.5 MHz |
| 100 MHz timing | Passed |
| CPI | 4.672 |
| Estimated MIPS at 100 MHz | 21.402 |
| Practical estimated MIPS at Fmax | ~31.4 |

## Phase 11B Prefetch Simulation Baseline

| Metric | Phase 11B prefetch CPU |
| --- | ---: |
| Cycles | 179 |
| Completed instructions | 58 |
| CPI | 3.086 |
| Estimated MIPS at 100 MHz | 32.402 |

## Vivado Commands

Synthesis:

```powershell
vivado -mode batch -source scripts/run_vivado_synth_multicycle_bram_prefetch.tcl
```

Implementation:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_multicycle_bram_prefetch.tcl
```

Both scripts target:

- FPGA part: `xc7a35tcpg236-1`
- Constraints: `constraints/basys3.xdc`
- Top module: `fpga_top_multicycle_bram_prefetch`
- Report root: `reports/phase11c/`

## Expected Report Outputs

Synthesis script outputs:

- `reports/phase11c/utilisation/fpga_top_multicycle_bram_prefetch_synth_utilization.rpt`
- `reports/phase11c/timing/fpga_top_multicycle_bram_prefetch_synth_timing_summary.rpt`
- `reports/phase11c/timing/fpga_top_multicycle_bram_prefetch_synth_worst_paths.rpt`
- `reports/phase11c/power/fpga_top_multicycle_bram_prefetch_synth_power.rpt`
- `reports/phase11c/checkpoints/fpga_top_multicycle_bram_prefetch_synth.dcp`

Implementation script outputs:

- `reports/phase11c/utilisation/fpga_top_multicycle_bram_prefetch_impl_utilization.rpt`
- `reports/phase11c/timing/fpga_top_multicycle_bram_prefetch_impl_timing_summary.rpt`
- `reports/phase11c/timing/fpga_top_multicycle_bram_prefetch_impl_worst_paths.rpt`
- `reports/phase11c/route/fpga_top_multicycle_bram_prefetch_route_status.rpt`
- `reports/phase11c/power/fpga_top_multicycle_bram_prefetch_impl_power.rpt`
- `reports/phase11c/checkpoints/fpga_top_multicycle_bram_prefetch_impl.dcp`
- `reports/phase11c/bitstreams/fpga_top_multicycle_bram_prefetch.bit`

## Vivado Result

Status: synthesis, implementation and bitstream generation passed.

Vivado version:

- Vivado 2026.1

Synthesis command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_synth_multicycle_bram_prefetch.tcl
```

Implementation command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_multicycle_bram_prefetch.tcl
```

| Metric | Synthesis result | Implementation result |
| --- | ---: | ---: |
| LUTs | 1,165 / 20,800, 5.60% | 1,161 / 20,800, 5.58% |
| FFs | 1,336 / 41,600, 3.21% | 1,341 / 41,600, 3.22% |
| Block RAM Tile | 1 / 50, 2.00% | 1 / 50, 2.00% |
| RAMB18 | 2 / 100, 2.00% | 2 / 100, 2.00% |
| DSP | 0 / 90, 0.00% | 0 / 90, 0.00% |
| WNS | +1.174 ns | +1.247 ns |
| TNS | 0.000 ns | 0.000 ns |
| WHS / hold result | +0.134 ns, hold met | +0.123 ns, hold met |
| THS | 0.000 ns | 0.000 ns |
| Estimated Fmax | ~113.3 MHz | ~114.2 MHz |
| 100 MHz timing | Passed | Passed |
| Bitstream status | Not applicable | Passed |

Bitstream generated:

- `reports/phase11c/bitstreams/fpga_top_multicycle_bram_prefetch.bit`

Route status:

- 2,178 routable nets.
- 2,178 fully routed nets.
- 0 nets with routing errors.

Power estimate:

- Total on-chip power: 0.079 W.
- Dynamic power: 0.008 W.
- Device static power: 0.072 W.
- Confidence level: Medium.

## Worst Path Summary

Post-synthesis worst path:

- Slack: +1.174 ns, timing met
- Source: `cpu_inst/pc_reg[5]/C`
- Destination: `cpu_inst/instr_mem_inst/instruction_reg/RSTRAMARSTRAM`
- Requirement: 10.000 ns
- Data path delay: 8.287 ns
- Logic delay: 3.972 ns, 47.932%
- Route delay: 4.315 ns, 52.068%
- Logic levels: 15, including carry-chain and LUT logic
- Classification: PC/prefetch address/control path into instruction BRAM control

Post-route worst path:

- Slack: +1.247 ns, timing met
- Source: `cpu_inst/pc_reg[6]/C`
- Destination: `cpu_inst/instr_mem_inst/instruction_reg/RSTRAMB`
- Requirement: 10.000 ns
- Data path delay: 8.301 ns
- Logic delay: 3.603 ns, 43.406%
- Route delay: 4.698 ns, 56.594%
- Logic levels: 15, including carry-chain and LUT logic
- Classification: PC/prefetch address/control path into instruction BRAM reset/control

## Comparison Against Phase 10H

| Metric | Phase 10H BRAM-aware CPU | Phase 11C prefetch CPU |
| --- | ---: | ---: |
| LUTs | 937 | 1,161 |
| FFs | 1,211 | 1,341 |
| Block RAM Tile | 1 | 1 |
| DSP | 0 | 0 |
| WNS | +3.172 ns | +1.247 ns |
| TNS | 0.000 ns | 0.000 ns |
| Estimated Fmax | ~146.5 MHz | ~114.2 MHz |
| CPI | 4.672 | 3.086 |
| Practical estimated MIPS | ~31.4 | ~37.0 |
| 100 MHz timing | Passed | Passed |

Practical estimated MIPS for the prefetch CPU is calculated as:

```text
114.2 MHz / 3.086 = ~37.0 MIPS
```

For comparison, the Phase 10H BRAM-aware baseline practical estimate is:

```text
146.5 MHz / 4.672 = ~31.4 MIPS
```

The prefetch CPU has lower estimated Fmax than the Phase 10H baseline, but the CPI improvement is large enough that the practical estimated throughput still improves.

## Warning Review

Vivado reported 0 errors and 0 critical warnings.

Non-blocking warnings and notes:

- `regs_reg[0]` was removed. This is expected because register `x0` is forced to zero.
- `addr[1:0]` on the BRAM instruction and data memory modules has no load. This is expected because the memories are word-addressed from byte addresses; the lowest two byte-offset bits are intentionally unused.
- Synthesis warned that implementation-specific XDC constraints are ignored during synthesis and used during implementation. This is expected for the shared Basys 3 XDC.
- Vivado noted that the BRAM instruction memory timing might be improved by adding an optional output register. This is useful future optimisation guidance, not a Phase 11C blocker.
- Vivado noted that the synthesized cellview is not ideal for floorplanning. This is not blocking for the current small design.

## Interpretation Guide

The prefetch CPU is a stronger candidate only if the CPI gain survives the FPGA implementation trade-off.

Possible outcomes:

The actual result is between the first two expected outcomes:

- Prefetch timing passes at 100 MHz.
- Estimated Fmax drops from ~146.5 MHz to ~114.2 MHz.
- CPI improves from 4.672 to 3.086.
- Practical estimated MIPS improves from ~31.4 to ~37.0.

This means the prefetch CPU improves overall estimated performance despite reducing timing margin. Phase 10H remains the simpler and higher-slack BRAM-aware implementation, while Phase 11C is the higher-throughput BRAM-aware candidate.

## Limitations

- Estimated Fmax comes from Vivado timing reports, not board measurement.
- CPI comes from simulation, not hardware counters.
- Hardware validation remains pending because the Basys 3 board is not available.
- The prefetch path remains separate and does not replace existing CPU or FPGA baselines.

## Recommended Next Work

Phase 11C shows that the prefetch CPU is now the best estimated-performance path so far while still meeting the 100 MHz Basys 3 timing target. The next work should document a concise architecture-performance conclusion and, when the Basys 3 board is available, decide whether to bring up the Phase 10H simpler BRAM-aware bitstream first or the Phase 11C higher-throughput prefetch bitstream.
