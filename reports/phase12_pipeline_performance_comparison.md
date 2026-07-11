# Phase 12 Pipelined CPU Performance and Timing Comparison

## Purpose

Phase 12 implements a separate in-order pipelined CPU path and measures whether it can improve practical FPGA throughput over the Phase 11E control-flow-optimised BRAM prefetch CPU.

The performance metric used throughout this report is:

```text
Practical estimated MIPS = post-route estimated Fmax in MHz / measured CPI
```

The primary target was at least 90 practical estimated MIPS. The stretch target was at least 100 practical estimated MIPS. These targets are not claimed unless both simulation CPI and post-route Vivado timing support them.

## Implementation Summary

New Phase 12 pipeline files:

- `rtl/cpu_core_pipeline_full.sv`
- `rtl/fpga_top_pipeline.sv`
- `tb/tb_cpu_core_pipeline_full.sv`
- `scripts/run_vivado_synth_pipeline.tcl`
- `scripts/run_vivado_impl_pipeline.tcl`

The implementation is separate from the existing Phase 11E CPU baseline. The existing `cpu_core_multicycle_bram_prefetch_ctrlopt` path was not replaced.

## Pipeline Architecture

The Phase 12 CPU is an in-order five-stage-style pipeline:

- IF: issue instruction BRAM request and track request PC.
- ID: decode instruction, read operands and generate control.
- EX: ALU operation, branch comparison, branch target generation and forwarding selection.
- MEM: synchronous data BRAM access.
- WB: register writeback and architectural retirement.

The instruction and data memories use the existing synchronous BRAM-style modules:

- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`

The instruction fetch path keeps explicit request metadata so the returned BRAM instruction is paired with the PC that requested it. A one-entry fetch buffer is used when the decode stage stalls.

## Pipeline State

The pipeline uses explicit valid bits for architectural safety:

- IF request metadata
- IF/ID register
- ID/EX register
- EX/MEM register
- MEM/WB register

Invalid entries are hardware bubbles. Bubbles, flushed entries and invalid opcodes do not cause architectural side effects.

## Forwarding

Implemented forwarding paths:

- EX/MEM ALU result to EX operand A.
- EX/MEM ALU result to EX operand B.
- MEM/WB writeback result to EX operand A.
- MEM/WB writeback result to EX operand B.
- Forwarded store data.
- Forwarded BEQ comparison operands.
- Writeback bypass into decode operand reads.

Forwarding ignores invalid producers, non-writing producers and writes to `x0`. EX/MEM forwarding has priority over MEM/WB forwarding.

## Stalls and Flushes

The data BRAM has synchronous read latency, so the pipeline detects load-use hazards. On a load-use hazard:

- IF/ID is held.
- The fetch response is preserved in the one-entry buffer when needed.
- ID/EX receives a bubble.
- Older pipeline stages continue to progress.

Control flow uses predict-not-taken BEQ handling and registered redirects. Taken BEQ and JUMP redirects flush younger wrong-path work and invalidate outstanding wrong-path fetch responses. The registered redirect keeps the branch compare/forwarding path out of the instruction-BRAM address path, which was needed to meet 100 MHz timing.

## Retirement Interface

The CPU exposes a stable retirement interface:

- `retire_valid`
- `retire_pc`
- `retire_opcode`
- `retire_rd`
- `retire_reg_write`
- `retire_write_data`
- `retire_mem_write`
- `retire_mem_addr`
- `retire_mem_data`

Each valid architectural instruction retires once. Invalid opcodes are discarded safely and do not retire.

## Simulation Result

Simulator:

- Vivado XSim 2026.1

Regression transcript:

- `reports/simulation_transcripts/phase12_pipeline_regression_20260711_143721.txt`

Result:

- Full XSim regression completed successfully.
- Phase 12 full pipelined CPU test passed.
- Phase 12 testbench summary: 2,793 tests run, 0 failed.
- Known non-blocking `xelab` object-directory cleanup warnings appeared after successful snapshot builds.

### Benchmark Results

These CPI numbers come from the executed Phase 12 XSim testbench.

| Benchmark | Cycles | Retired instructions | CPI | MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Independent arithmetic | 86 | 81 | 1.062 | 94.186 |
| Dependency arithmetic | 16 | 11 | 1.455 | 68.750 |
| Memory offset | 15 | 9 | 1.667 | 60.000 |
| Load-use dependency | 14 | 8 | 1.750 | 57.143 |
| Branch control | 18 | 10 | 1.800 | 55.556 |
| Jump control | 16 | 7 | 2.286 | 43.750 |
| Simple loop | 70 | 44 | 1.591 | 62.857 |
| Invalid opcode safety | 11 | 4 | 2.750 | 36.364 |
| Mixed custom ISA | 211 | 145 | 1.455 | 68.720 |
| Aggregate | 457 | 319 | 1.433 | 69.803 |

The longer independent arithmetic benchmark shows the intended pipeline behaviour: after filling, it approaches one instruction per cycle. Dependency, memory and control-heavy programs still pay stall and flush penalties.

## Vivado Implementation Result

Vivado:

- Vivado 2026.1

Target:

- Board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top_pipeline`
- Constraint file: `constraints/basys3.xdc`
- Target clock: 10.000 ns / 100 MHz

Implementation command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_pipeline.tcl
```

Report outputs:

- `reports/phase12_pipeline/utilisation/fpga_top_pipeline_impl_utilization.rpt`
- `reports/phase12_pipeline/timing/fpga_top_pipeline_impl_timing_summary.rpt`
- `reports/phase12_pipeline/timing/fpga_top_pipeline_impl_worst_paths.rpt`
- `reports/phase12_pipeline/route/fpga_top_pipeline_route_status.rpt`
- `reports/phase12_pipeline/power/fpga_top_pipeline_impl_power.rpt`
- `reports/phase12_pipeline/bitstreams/fpga_top_pipeline.bit`

Post-route result:

| Metric | Phase 12 pipeline result |
| --- | ---: |
| LUTs | 1,146 / 20,800, 5.51% |
| FFs | 1,473 / 41,600, 3.54% |
| Block RAM Tile | 1 / 50, 2.00% |
| RAMB18 | 2 / 100, 2.00% |
| DSP | 0 / 90, 0.00% |
| WNS | +0.185 ns |
| TNS | 0.000 ns |
| WHS | +0.055 ns |
| THS | 0.000 ns |
| 100 MHz timing | Passed |
| Bitstream generation | Passed |
| Total on-chip power | 0.089 W, medium confidence |

Route status:

- 2,192 routable nets.
- 2,192 fully routed nets.
- 0 nets with routing errors.

Estimated Fmax from the post-route timing result:

```text
Estimated Fmax = 1000 / (10.000 ns - 0.185 ns)
               = approximately 101.9 MHz
```

## Worst Path

Post-route worst setup path:

- Slack: +0.185 ns, timing met.
- Source: `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`.
- Destination: `cpu_inst/if_id_reg_reg[instruction][23]/R`.
- Requirement: 10.000 ns.
- Data path delay: 9.171 ns.
- Logic delay: 4.279 ns, 46.657%.
- Route delay: 4.892 ns, 53.343%.
- Logic levels: 9.

Classification:

- Memory/forwarding/control path into IF/ID update and flush control.
- This is much shorter than the earlier single-cycle-style PC/fetch/decode/writeback path, but control and forwarding logic still limit timing margin.

## Practical Estimated MIPS

Aggregate measured CPI:

```text
CPI = 457 cycles / 319 retired instructions = 1.433
```

Practical estimated throughput:

```text
Practical estimated MIPS = 101.9 MHz / 1.433
                         = approximately 71.1 MIPS
```

This is a measured simulation-plus-post-route estimate. It does not claim hardware-measured performance.

## Comparison Against Phase 11E

| Architecture | CPI | Estimated Fmax | Practical estimated MIPS | LUTs | FFs | BRAM | WNS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 11E ctrlopt prefetch | 2.983 | ~112.7 MHz | ~37.8 | 1,173 | 1,341 | 1 tile / 2 RAMB18 | +1.128 ns |
| Phase 12 pipeline | 1.433 | ~101.9 MHz | ~71.1 | 1,146 | 1,473 | 1 tile / 2 RAMB18 | +0.185 ns |

Estimated speedup over Phase 11E:

```text
71.1 / 37.8 = approximately 1.88x
```

The pipeline gives a large CPI improvement, while the extra forwarding, hazard and flush logic reduces timing margin compared with Phase 11E.

## Target Classification

Using the project classification:

- Below 65 MIPS: pipeline works, investigate major stalls/timing.
- 65-79.9 MIPS: useful performance improvement.
- 80-89.9 MIPS: strong result, close to target.
- 90-99.9 MIPS: primary target achieved.
- 100+ MIPS: stretch target achieved.

Measured Phase 12 result:

- Practical estimated MIPS: ~71.1.
- Classification: useful performance improvement.
- Primary 90 MIPS target: not achieved.
- Stretch 100 MIPS target: not achieved.
- Mandatory 100 MHz timing target: achieved.

## Remaining Bottlenecks

The main remaining throughput limits are:

- Control-flow penalty from registered redirects and wrong-path fetch invalidation.
- Load-use stalls from synchronous data BRAM latency.
- Timing margin limited by memory/forwarding/control logic, so aggressive control-flow optimisation risks failing timing.

The independent arithmetic benchmark shows that hazard-free sequential code can approach one instruction per cycle. The aggregate workload is limited by branch/jump and memory behaviour.

## Recommended Next Optimisation

The next optimisation should target control-flow penalty without putting branch comparison back on the instruction-BRAM address path.

Recommended direction:

1. Add a small, timing-safe branch/jump target request stage or target fetch buffer.
2. Keep redirect decisions registered.
3. Preserve wrong-path response invalidation.
4. Rerun the full custom-ISA regression.
5. Rerun Vivado implementation and compare practical MIPS, not only CPI.

If timing margin drops below zero, reject the optimisation even if simulation CPI improves.

## Limitations

- CPI is simulation-measured, not hardware-measured.
- Estimated Fmax comes from Vivado post-route timing, not physical board frequency measurement.
- Hardware validation is still pending until the Basys 3 board is available.
- The 90-100 MIPS target remains a future optimisation target.

## Conclusion

The Phase 12 pipelined CPU is functionally correct in the full XSim regression and meets the Basys 3 100 MHz post-route timing constraint. It improves practical estimated throughput from about 37.8 MIPS in Phase 11E to about 71.1 MIPS, a roughly 1.88x improvement.

The result is a useful performance improvement, but it does not achieve the 90 MIPS primary target or the 100 MIPS stretch target. Further optimisation should focus on reducing control-flow penalty while preserving the clean 100 MHz timing result.
