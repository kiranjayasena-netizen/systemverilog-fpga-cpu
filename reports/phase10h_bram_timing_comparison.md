# Phase 10H BRAM-Aware Synthesis And Timing Comparison

## Purpose

Phase 10H creates a separate FPGA implementation path for the BRAM-aware multi-cycle CPU and defines how it should be compared against the existing timing-clean Phase 8G multi-cycle baseline.

Phase 10G proved simulation correctness for the BRAM-aware CPU, including arithmetic, memory, branch, jump, loop and invalid-opcode behaviour. Simulation does not prove that Vivado inferred FPGA block RAMs or that the BRAM-aware top level meets timing after synthesis and implementation. Phase 10H addresses that gap.

## Separate BRAM-Aware FPGA Path

New Phase 10H files:

- `rtl/fpga_top_multicycle_bram.sv`
- `scripts/run_vivado_synth_multicycle_bram.tcl`
- `scripts/run_vivado_impl_multicycle_bram.tcl`

The new top level instantiates `cpu_core_multicycle_bram` and preserves the existing Basys 3 wrapper approach:

- The real Basys 3 100 MHz clock remains the only clock.
- `slow_tick_generator` creates a clock-enable pulse for LED-visible stepping.
- The CPU advances only when the enable switch is on and the slow tick fires.
- The wrapper uses the existing board constraint port names `rst_btn` and `enable_sw`, which correspond to the reset button and enable switch in `constraints/basys3.xdc`.

LED debug mapping:

| LED bits | Signal |
| --- | --- |
| `led[3:0]` | `pc[5:2]` |
| `led[7:4]` | `opcode_reg` |
| `led[8]` | `valid_instr` |
| `led[9]` | `reg_write` |
| `led[10]` | `mem_write` |
| `led[13:11]` | BRAM-aware FSM `state` |
| `led[15:14]` | `alu_result[1:0]` |

## Phase 8G Multi-Cycle FPGA Baseline

Existing timing-clean non-BRAM multi-cycle result:

| Metric | Phase 8G `fpga_top_multicycle` |
| --- | ---: |
| Target board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |
| Target clock | 10 ns / 100 MHz |
| LUTs | 3,027 |
| FFs | 8,654 |
| BRAM | 0 |
| DSP | 0 |
| WNS | +1.389 ns |
| TNS | 0.000 ns |
| Estimated Fmax | approximately 116.1 MHz |
| 100 MHz timing | Passed |

## Phase 10G BRAM-Aware Simulation Baseline

Phase 10G full custom-ISA simulation result:

| Metric | Phase 10G result |
| --- | ---: |
| Cycles | 271 |
| Completed instructions | 58 |
| CPI | 4.672 |
| Estimated MIPS at 100 MHz | 21.402 |
| Simulation status | Passed |

The BRAM-aware CPI is higher than the non-BRAM multi-cycle CPU because synchronous instruction fetch and data LOAD paths require additional capture states.

## Phase 10H Vivado Commands

Synthesis:

```powershell
vivado -mode batch -source scripts/run_vivado_synth_multicycle_bram.tcl
```

Implementation:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_multicycle_bram.tcl
```

Both scripts target:

- FPGA part: `xc7a35tcpg236-1`
- Constraints: `constraints/basys3.xdc`
- Top module: `fpga_top_multicycle_bram`
- Report root: `reports/phase10h/`

## Expected Report Outputs

Synthesis script outputs:

- `reports/phase10h/utilisation/fpga_top_multicycle_bram_synth_utilization.rpt`
- `reports/phase10h/timing/fpga_top_multicycle_bram_synth_timing_summary.rpt`
- `reports/phase10h/timing/fpga_top_multicycle_bram_synth_worst_paths.rpt`
- `reports/phase10h/power/fpga_top_multicycle_bram_synth_power.rpt`
- `reports/phase10h/checkpoints/fpga_top_multicycle_bram_synth.dcp`

Implementation script outputs:

- `reports/phase10h/utilisation/fpga_top_multicycle_bram_impl_utilization.rpt`
- `reports/phase10h/timing/fpga_top_multicycle_bram_impl_timing_summary.rpt`
- `reports/phase10h/timing/fpga_top_multicycle_bram_impl_worst_paths.rpt`
- `reports/phase10h/route/fpga_top_multicycle_bram_route_status.rpt`
- `reports/phase10h/power/fpga_top_multicycle_bram_impl_power.rpt`
- `reports/phase10h/checkpoints/fpga_top_multicycle_bram_impl.dcp`
- `reports/phase10h/bitstreams/fpga_top_multicycle_bram.bit`

Generated checkpoints and bitstreams should not be committed unless specifically required for an evidence hand-in.

## BRAM-Aware Vivado Result

Status: synthesis, implementation and bitstream generation passed.

Vivado version:

- Vivado 2026.1

Synthesis command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_synth_multicycle_bram.tcl
```

Implementation command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_multicycle_bram.tcl
```

| Metric | Synthesis result | Implementation result |
| --- | ---: | ---: |
| LUTs | 958 / 20,800, 4.61% | 937 / 20,800, 4.50% |
| FFs | 1,208 / 41,600, 2.90% | 1,211 / 41,600, 2.91% |
| Block RAM Tile | 1 / 50, 2.00% | 1 / 50, 2.00% |
| RAMB18 | 2 / 100, 2.00% | 2 / 100, 2.00% |
| DSP | 0 / 90, 0.00% | 0 / 90, 0.00% |
| WNS | +5.321 ns | +3.172 ns |
| TNS | 0.000 ns | 0.000 ns |
| WHS / hold result | +0.144 ns, hold met | +0.182 ns, hold met |
| THS | 0.000 ns | 0.000 ns |
| Estimated Fmax | approximately 213.7 MHz | approximately 146.5 MHz |
| 100 MHz timing | Passed | Passed |
| Bitstream status | Not applicable | Passed |

Bitstream generated:

- `reports/phase10h/bitstreams/fpga_top_multicycle_bram.bit`

Route status:

- 1,924 routable nets.
- 1,924 fully routed nets.
- 0 nets with routing errors.

Power estimate:

- Total on-chip power: 0.078 W.
- Dynamic power: 0.007 W.
- Device static power: 0.072 W.
- Confidence level: Medium.

## Worst Path Summary

Post-synthesis worst setup path:

- Source: `cpu_inst/operand_b_reg_reg[1]/C`
- Destination: `cpu_inst/alu_result_reg_reg[30]/D`
- Slack: +5.321 ns
- Data path delay: 4.528 ns
- Logic levels: 11
- Classification: execute-stage ALU result path

Post-route worst setup path:

- Source: `cpu_inst/instr_mem_inst/instruction_reg/CLKARDCLK`
- Destination: `cpu_inst/operand_b_reg_reg[5]/D`
- Slack: +3.172 ns
- Data path delay: 6.739 ns
- Logic delay: 1.476 ns, 21.901%
- Route delay: 5.263 ns, 78.099%
- Logic levels: 2
- Classification: BRAM instruction fetch/capture into decode operand-register path

The post-route critical path is consistent with the BRAM-aware architecture: instruction data is read from the inferred instruction memory block and then captured into decode-stage operand registers. The timing margin remains positive at the 100 MHz target.

## Warning Review

Vivado reported 0 errors and 0 critical warnings.

Non-blocking warnings:

- `regs_reg[0]` was removed. This is expected because register `x0` is hardwired to zero.
- `addr[1:0]` on the BRAM instruction and data memory modules has no load. This is expected because the memories are word-addressed from byte addresses using upper address bits such as `addr[9:2]`; the lowest two byte-offset bits are intentionally unused for word indexing.

No warning requires a design change for Phase 10H.

## Comparison Against Phase 8G

| Metric | Phase 8G non-BRAM multi-cycle | Phase 10H BRAM-aware multi-cycle |
| --- | ---: | ---: |
| LUTs | 3,027 | 937 |
| FFs | 8,654 | 1,211 |
| Block RAM Tile | 0 | 1 |
| DSP | 0 | 0 |
| WNS | +1.389 ns | +3.172 ns |
| TNS | 0.000 ns | 0.000 ns |
| Estimated Fmax | approximately 116.1 MHz | approximately 146.5 MHz |
| 100 MHz timing | Passed | Passed |
| CPI evidence | Phase 10A non-BRAM multi-cycle benchmarks | Phase 10G BRAM-aware aggregate CPI 4.672 |

The BRAM-aware top uses one block RAM tile and significantly reduces LUT and flip-flop usage compared with the Phase 8G non-BRAM multi-cycle FPGA top. It also improves post-route timing margin at 100 MHz. The trade-off is performance: the BRAM-aware CPU has higher CPI because synchronous BRAM reads add fetch and memory capture states.

## Interpretation Guide

Possible outcomes:

1. BRAM inferred and timing passes.
   - This is the preferred result. It would show that the BRAM-aware architecture keeps the functional benefits of Phase 10G while mapping memories to FPGA block RAM resources.

2. BRAM inferred but timing worsens.
   - This would still be useful engineering evidence. It may indicate that extra BRAM latency states were functionally correct but the wrapper, control logic, or memory placement now needs timing-focused optimisation.

3. BRAM not inferred.
   - This would mean the standalone BRAM-style modules or synthesis context need further study. The next action would be to inspect Vivado memory inference messages and adjust coding style without changing ISA behaviour.

## Limitations

- Hardware validation is still pending because the Basys 3 board is not available.
- Estimated Fmax comes from Vivado timing reports, not physical board measurement.
- CPI and MIPS are simulation-derived values from Phase 10G.
- The Phase 10H FPGA path is separate and experimental; it does not replace the existing verified CPU baselines.

## Recommended Next Work

Phase 10H shows that the BRAM-aware FPGA path is both resource-efficient and timing-clean at 100 MHz. The next phase should turn this into a concise supervisor-facing conclusion and decide whether the BRAM-aware multi-cycle path should become the preferred implementation candidate for future hardware bring-up and final-year work.
