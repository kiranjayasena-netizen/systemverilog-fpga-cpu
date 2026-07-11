# Phase 11E Control-Flow-Optimised Prefetch Timing Comparison

## Purpose

Phase 11E creates a separate FPGA implementation path for the Phase 11D control-flow-optimised BRAM-aware prefetch CPU and compares it against the Phase 11C prefetch baseline.

Phase 11D improved the simulation CPI by reducing wasted cycles around taken BEQ, JUMP and loop redirects. Phase 11E checks whether that extra control-flow logic still synthesizes, implements, infers BRAM and meets the Basys 3 100 MHz timing target.

## Separate FPGA Path

New Phase 11E files:

- `rtl/fpga_top_multicycle_bram_prefetch_ctrlopt.sv`
- `scripts/run_vivado_synth_multicycle_bram_prefetch_ctrlopt.tcl`
- `scripts/run_vivado_impl_multicycle_bram_prefetch_ctrlopt.tcl`

The top-level wrapper instantiates `cpu_core_multicycle_bram_prefetch_ctrlopt`. It keeps the existing Basys 3 clocking approach:

- The real 100 MHz board clock remains the only clock.
- `slow_tick_generator` creates a clock-enable pulse for LED-visible stepping.
- The CPU advances only when the enable switch is on and the slow tick fires.
- The wrapper uses the repo's existing constrained board port names `rst_btn` and `enable_sw`.

LED debug mapping:

| LED bits | Signal |
| --- | --- |
| `led[3:0]` | `pc[5:2]` |
| `led[7:4]` | `opcode_reg` |
| `led[8]` | `valid_instr` |
| `led[9]` | `reg_write` |
| `led[10]` | `mem_write` |
| `led[13:11]` | control-flow-optimised prefetch CPU FSM `state` |
| `led[14]` | `prefetch_valid` |
| `led[15]` | `alu_result[0]` |

## Baselines

### Phase 10H BRAM-Aware CPU

| Metric | Phase 10H BRAM-aware CPU |
| --- | ---: |
| LUTs | 937 |
| FFs | 1,211 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| WNS | +3.172 ns |
| Estimated Fmax | ~146.5 MHz |
| CPI | 4.672 |
| Practical estimated MIPS | ~31.4 |
| 100 MHz timing | Passed |

### Phase 11C Prefetch CPU

| Metric | Phase 11C prefetch CPU |
| --- | ---: |
| LUTs | 1,161 |
| FFs | 1,341 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| WNS | +1.247 ns |
| TNS | 0.000 ns |
| Estimated Fmax | ~114.2 MHz |
| CPI | 3.086 |
| Practical estimated MIPS | ~37.0 |
| 100 MHz timing | Passed |

### Phase 11D Control-Flow Simulation Result

| Metric | Phase 11D ctrlopt simulation |
| --- | ---: |
| Cycles | 173 |
| Completed instructions | 58 |
| CPI | 2.983 |
| Estimated MIPS at 100 MHz | 33.526 |

## Vivado Commands

Synthesis:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_synth_multicycle_bram_prefetch_ctrlopt.tcl
```

Implementation:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_multicycle_bram_prefetch_ctrlopt.tcl
```

Both scripts target:

- FPGA part: `xc7a35tcpg236-1`
- Constraints: `constraints/basys3.xdc`
- Top module: `fpga_top_multicycle_bram_prefetch_ctrlopt`
- Report root: `reports/phase11e/`

The first sandboxed synthesis launch failed before RTL analysis with a Vivado temporary-file access-denied error. The same command was rerun successfully using the local Vivado batch executable outside the sandbox.

## Expected Report Outputs

Synthesis script outputs:

- `reports/phase11e/utilisation/fpga_top_multicycle_bram_prefetch_ctrlopt_synth_utilization.rpt`
- `reports/phase11e/timing/fpga_top_multicycle_bram_prefetch_ctrlopt_synth_timing_summary.rpt`
- `reports/phase11e/timing/fpga_top_multicycle_bram_prefetch_ctrlopt_synth_worst_paths.rpt`
- `reports/phase11e/power/fpga_top_multicycle_bram_prefetch_ctrlopt_synth_power.rpt`
- `reports/phase11e/checkpoints/fpga_top_multicycle_bram_prefetch_ctrlopt_synth.dcp`

Implementation script outputs:

- `reports/phase11e/utilisation/fpga_top_multicycle_bram_prefetch_ctrlopt_impl_utilization.rpt`
- `reports/phase11e/timing/fpga_top_multicycle_bram_prefetch_ctrlopt_impl_timing_summary.rpt`
- `reports/phase11e/timing/fpga_top_multicycle_bram_prefetch_ctrlopt_impl_worst_paths.rpt`
- `reports/phase11e/route/fpga_top_multicycle_bram_prefetch_ctrlopt_route_status.rpt`
- `reports/phase11e/power/fpga_top_multicycle_bram_prefetch_ctrlopt_impl_power.rpt`
- `reports/phase11e/checkpoints/fpga_top_multicycle_bram_prefetch_ctrlopt_impl.dcp`
- `reports/phase11e/bitstreams/fpga_top_multicycle_bram_prefetch_ctrlopt.bit`

## Vivado Result

Status: synthesis, implementation and bitstream generation passed.

Vivado version:

- Vivado 2026.1

| Metric | Synthesis result | Implementation result |
| --- | ---: | ---: |
| LUTs | 1,185 / 20,800, 5.70% | 1,173 / 20,800, 5.64% |
| FFs | 1,336 / 41,600, 3.21% | 1,341 / 41,600, 3.22% |
| Block RAM Tile | 1 / 50, 2.00% | 1 / 50, 2.00% |
| RAMB18 | 2 / 100, 2.00% | 2 / 100, 2.00% |
| DSP | 0 / 90, 0.00% | 0 / 90, 0.00% |
| WNS | +0.869 ns | +1.128 ns |
| TNS | 0.000 ns | 0.000 ns |
| WHS / hold result | +0.134 ns, hold met | +0.129 ns, hold met |
| THS | 0.000 ns | 0.000 ns |
| Estimated Fmax | ~109.5 MHz | ~112.7 MHz |
| 100 MHz timing | Passed | Passed |
| Bitstream status | Not applicable | Passed |

Bitstream generated:

- `reports/phase11e/bitstreams/fpga_top_multicycle_bram_prefetch_ctrlopt.bit`

Route status:

- 2,197 routable nets.
- 2,197 fully routed nets.
- 0 nets with routing errors.

Power estimate:

- Total on-chip power: 0.078 W.
- Dynamic power: 0.007 W.
- Device static power: 0.072 W.
- Confidence level: Medium.

## Worst Path Summary

Post-synthesis worst path:

- Slack: +0.869 ns, timing met.
- Source: `cpu_inst/pc_reg[5]/C`.
- Destination: `cpu_inst/instr_mem_inst/instruction_reg/RSTRAMARSTRAM`.
- Requirement: 10.000 ns.
- Data path delay: 8.592 ns.
- Logic delay: 4.010 ns, 46.673%.
- Route delay: 4.582 ns, 53.327%.
- Logic levels: 16, including carry-chain and LUT logic.
- Classification: PC/prefetch address/control path into instruction BRAM control.

Post-route worst path:

- Slack: +1.128 ns, timing met.
- Source: `cpu_inst/prefetch_pc_reg[2]/C`.
- Destination: `cpu_inst/instr_mem_inst/instruction_reg/RSTRAMARSTRAM`.
- Requirement: 10.000 ns.
- Data path delay: 8.412 ns.
- Logic delay: 3.922 ns, 46.625%.
- Route delay: 4.490 ns, 53.375%.
- Logic levels: 16, including carry-chain and LUT logic.
- Classification: prefetch PC / target-address comparison path into instruction BRAM reset/control.

## Comparison Against Phase 11C

| Metric | Phase 11C prefetch CPU | Phase 11E ctrlopt prefetch CPU | Interpretation |
| --- | ---: | ---: | --- |
| LUTs | 1,161 | 1,173 | +12 LUTs |
| FFs | 1,341 | 1,341 | Same |
| Block RAM Tile | 1 | 1 | Same |
| RAMB18 | 2 | 2 | Same |
| DSP | 0 | 0 | Same |
| WNS | +1.247 ns | +1.128 ns | Slightly less slack |
| TNS | 0.000 ns | 0.000 ns | Same |
| Estimated Fmax | ~114.2 MHz | ~112.7 MHz | Slightly lower |
| CPI | 3.086 | 2.983 | Improved |
| Practical estimated MIPS | ~37.0 | ~37.8 | Slightly improved |
| 100 MHz timing | Passed | Passed | Same |

Practical estimated MIPS for the Phase 11E control-flow-optimised prefetch CPU:

```text
112.7 MHz / 2.983 = ~37.8 MIPS
```

For comparison, the Phase 11C prefetch CPU practical estimate is:

```text
114.2 MHz / 3.086 = ~37.0 MIPS
```

## Warning Review

Vivado reported 0 errors and 0 critical warnings.

Non-blocking warnings and notes:

- `regs_reg[0]` was removed. This is expected because register `x0` is forced to zero.
- `addr[1:0]` on the BRAM instruction and data memory modules has no load. This is expected because the memories are word-addressed from byte addresses; the lowest two byte-offset bits are intentionally unused.
- Synthesis warned that implementation-specific XDC constraints are ignored during synthesis and used during implementation. This is expected for the shared Basys 3 XDC.
- Vivado noted that the BRAM instruction memory timing might be improved by adding an optional output register. This is useful future optimisation guidance, not a Phase 11E blocker.
- Vivado noted that the synthesized cellview is not ideal for floorplanning. This is not blocking for the current small design.

## Interpretation

The Phase 11D control-flow optimisation is worth keeping as an experimental path:

- It preserves BRAM inference.
- It passes 100 MHz post-route timing.
- It keeps FF and BRAM usage unchanged compared with Phase 11C.
- It adds only a small LUT cost.
- It slightly reduces timing slack and estimated Fmax.
- The CPI improvement is enough to slightly improve practical estimated throughput.

The improvement over Phase 11C is modest rather than dramatic. Phase 11C remains the simpler prefetch implementation, while Phase 11E is the best estimated-performance implementation path so far.

## Limitations

- Estimated Fmax comes from Vivado timing reports, not hardware measurement.
- CPI comes from simulation, not hardware counters.
- Hardware validation remains pending because the Basys 3 board is not available.
- The Phase 11E bitstream has not been programmed onto a physical board.

## Recommended Next Work

The next step should be a supervisor-facing Phase 11 conclusion that compares:

- Phase 10H BRAM-aware CPU.
- Phase 11C prefetch CPU.
- Phase 11E control-flow-optimised prefetch CPU.

Further optimisation should be avoided unless a clear architectural benefit is identified. When the Basys 3 board arrives, hardware bring-up should use either the simpler Phase 11C prefetch bitstream or the slightly faster Phase 11E ctrlopt bitstream, depending on whether simplicity or estimated throughput is preferred for the first demonstration.
