# Phase 13A Jump Target Request

## Purpose

Phase 13A tests a timing-safe optimisation for the separate Phase 12 pipelined CPU. The goal is to reduce unconditional `JUMP` penalty without replacing the verified Phase 12 baseline or changing the custom ISA.

The existing Phase 12 core already detects `JUMP` in ID and calculates:

```text
id_jump_target = if_id_pc + (imm_ext << 2)
```

Phase 12 still sent that ID-stage decision through the registered `redirect_pending_valid` request-launch path. That kept timing clean, but added a request cycle before the target instruction BRAM address was issued.

## Baseline

Phase 12 baseline:

| Metric | Phase 12 value |
| --- | ---: |
| Aggregate cycles | 457 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.433 |
| MIPS at 100 MHz | 69.803 |
| Post-route WNS | +0.185 ns |
| Post-route TNS | 0.000 ns |
| Estimated Fmax | ~101.9 MHz |
| Practical estimated MIPS | ~71.1 |
| LUTs | 1,146 |
| FFs | 1,473 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |

## Architecture Change

New separate files were added for the Phase 13A path:

- `rtl/cpu_core_pipeline_jumpfast.sv`
- `rtl/fpga_top_pipeline_jumpfast.sv`
- `tb/tb_cpu_core_pipeline_jumpfast.sv`
- `scripts/run_vivado_synth_pipeline_jumpfast.tcl`
- `scripts/run_vivado_impl_pipeline_jumpfast.tcl`

The original Phase 12 files remain available.

Phase 13A adds direct fast request state:

```text
jump_response_pending
jump_response_pc
```

When an ID-stage `JUMP` is detected, the target address is driven directly to instruction BRAM and the target response PC is saved. On the next usable enabled cycle, the returned BRAM instruction is paired with `jump_response_pc` and enters IF/ID.

The JUMP instruction itself still retires exactly once. The target request optimisation does not convert the JUMP into a non-retiring bubble.

## Timing-Safe Priority

The implementation separates the raw target address request from the architectural redirect commit:

- `id_jump_fast_request` may drive the instruction BRAM address using only ID-stage information.
- `id_jump_redirect` commits the fast redirect only if no older EX-stage redirect wins.

This avoids putting the forwarded BEQ comparison result directly on the instruction-BRAM address path.

If an older taken BEQ exists while a younger wrong-path JUMP is in ID, the speculative JUMP target request is discarded. The younger JUMP does not retire and does not increment the JUMP counter.

BEQ remains functionally unchanged:

- BEQ is resolved in EX.
- BEQ uses the existing forwarding paths.
- Taken BEQ uses the registered redirect path.
- Wrong-path IF/ID, pending request and fetch-buffer state are invalidated.

## Stale Response Handling

On a fast JUMP request:

- the old sequential response is invalidated;
- the fetch buffer is cleared;
- younger wrong-path IF state is cleared;
- target response metadata is saved in `jump_response_pc`;
- the next sequential fetch PC is set to `target + 4`.

During pause (`enable == 0`), `jump_response_pending` and `jump_response_pc` are held. No retirement, register write or memory write occurs while paused. After re-enable, the target response is accepted once.

## Focused Simulation

Focused command:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv rtl/bram_instr_mem.sv rtl/bram_data_mem.sv rtl/cpu_core_pipeline_jumpfast.sv tb/tb_cpu_core_pipeline_jumpfast.sv
xelab tb_cpu_core_pipeline_jumpfast -s tb_cpu_core_pipeline_jumpfast_final
xsim tb_cpu_core_pipeline_jumpfast_final -runall
```

Focused transcript:

- `reports/simulation_transcripts/phase13a_jumpfast_focused_final_20260711_193050.txt`

Focused result:

| Metric | Value |
| --- | ---: |
| Checks run | 3,232 |
| Checks failed | 0 |
| Result | `PHASE 13A JUMPFAST PIPELINE TEST PASSED` |

Focused tests covered:

- single forward JUMP;
- consecutive JUMPs;
- backward JUMP loop;
- pause after fast JUMP target request;
- older taken BEQ overriding younger wrong-path JUMP;
- JUMP near a load-use/fetch-buffer condition;
- wrong-path STORE protection;
- no duplicate retirement and no skipped architectural target instruction.

Measured focused JUMP target timing:

| Focused case | ID JUMP to target IF/ID | ID JUMP to target retire |
| --- | ---: | ---: |
| Single forward JUMP | 2 sampled cycles | 6 sampled cycles |
| Consecutive JUMPs | 2 sampled cycles | 6 sampled cycles |
| Backward JUMP loop | 2 sampled cycles | 1 sampled cycle |

The sampled IF/ID latency reflects the testbench's negedge observation convention around synchronous BRAM response timing. The architectural benchmark comparison below shows the expected one-cycle reduction for directly requested JUMP targets.

## Full Regression

Full regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Full regression transcript:

- `reports/simulation_transcripts/phase13a_xsim_regression_final_20260711_193104.txt`

Result:

- Full XSim regression passed.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds.
- XSim ran the snapshots and all self-checking tests passed.

## Benchmark Comparison

The Phase 13A testbench uses the same benchmark instruction mix as the Phase 12 pipeline comparison.

| Benchmark | Phase 12 cycles | Phase 13A cycles | Retired | Phase 12 CPI | Phase 13A CPI |
| --- | ---: | ---: | ---: | ---: | ---: |
| Independent arithmetic | 86 | 86 | 81 | 1.062 | 1.062 |
| Dependency arithmetic | 16 | 16 | 11 | 1.455 | 1.455 |
| Memory offset | 15 | 15 | 9 | 1.667 | 1.667 |
| Load-use dependency | 14 | 14 | 8 | 1.750 | 1.750 |
| Branch control | 18 | 18 | 10 | 1.800 | 1.800 |
| Jump control | 16 | 14 | 7 | 2.286 | 2.000 |
| Simple loop | 70 | 61 | 44 | 1.591 | 1.386 |
| Invalid opcode safety | 11 | 11 | 4 | 2.750 | 2.750 |
| Mixed custom ISA | 211 | 192 | 145 | 1.455 | 1.324 |
| Aggregate | 457 | 427 | 319 | 1.433 | 1.339 |

Phase 13A aggregate simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 427 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Aggregate MIPS at 100 MHz | 74.707 |
| Load-use stalls in mixed benchmark | 20 |
| Control flushes in mixed benchmark | 20 |
| Jumps in mixed benchmark | 19 |
| Wrong-path flushed in mixed benchmark | 21 |

The aggregate cycle count improves by 30 cycles, a 6.56% cycle reduction versus Phase 12.

## Vivado Implementation

Implementation command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_jumpfast.tcl
```

Generated reports:

- `reports/phase13a/utilisation/fpga_top_pipeline_jumpfast_impl_utilization.rpt`
- `reports/phase13a/timing/fpga_top_pipeline_jumpfast_impl_timing_summary.rpt`
- `reports/phase13a/timing/fpga_top_pipeline_jumpfast_impl_worst_paths.rpt`
- `reports/phase13a/route/fpga_top_pipeline_jumpfast_route_status.rpt`
- `reports/phase13a/power/fpga_top_pipeline_jumpfast_impl_power.rpt`

Bitstream generated:

- `reports/phase13a/bitstreams/fpga_top_pipeline_jumpfast.bit`

Post-route result:

| Metric | Phase 13A value |
| --- | ---: |
| LUTs | 1,233 / 20,800, 5.93% |
| FFs | 1,507 / 41,600, 3.62% |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 / 90 |
| WNS | +0.182 ns |
| TNS | 0.000 ns |
| WHS | +0.034 ns |
| THS | 0.000 ns |
| Total on-chip power | 0.090 W |
| Power confidence | Medium |
| Route errors | 0 |
| Bitstream | Generated successfully |

Worst setup path:

- Source: `cpu_inst/data_mem_inst/mem_reg/CLKBWRCLK`
- Destination: `cpu_inst/if_id_reg_reg[pc][14]/R`
- Data path delay: 9.170 ns
- Logic levels: 8
- Route delay share: 56.456%

The direct JUMP target address path did not become the failing critical path. Timing meets the 100 MHz Basys 3 constraint.

## Practical Estimated MIPS

Using:

```text
Practical estimated MIPS = post-route estimated Fmax in MHz / measured CPI
```

Phase 13A:

```text
Estimated Fmax = 1000 / (10.000 ns - 0.182 ns)
               = approximately 101.9 MHz

Practical estimated MIPS = 101.9 / 1.339
                         = approximately 76.1 MIPS
```

Comparison:

| Architecture | CPI | Estimated Fmax | Practical estimated MIPS | LUTs | FFs | BRAM | WNS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 12 pipeline | 1.433 | ~101.9 MHz | ~71.1 | 1,146 | 1,473 | 1 tile / 2 RAMB18 | +0.185 ns |
| Phase 13A jumpfast pipeline | 1.339 | ~101.9 MHz | ~76.1 | 1,233 | 1,507 | 1 tile / 2 RAMB18 | +0.182 ns |

Phase 13A improves practical estimated MIPS by about 7.0% versus Phase 12. It does not reach the 90 MIPS primary target.

## Warnings

Important non-blocking warnings:

- `xelab` can return an object-directory cleanup warning after building a snapshot. XSim still ran and all self-checking tests passed.
- Vivado reports unused low address bits on BRAM address ports. This is expected because instruction and data memories are word-addressed internally using byte address bits above `[1:0]`.
- Vivado notes that optional BRAM output registers were not merged. This is useful future timing information, not a Phase 13A blocker.

## Conclusion

Phase 13A should be retained as a measured improvement over Phase 12:

- Correctness regression passed.
- 100 MHz post-route timing passed.
- BRAM inference was retained.
- Practical estimated MIPS improved from about 71.1 to about 76.1.

The result is useful but still below the 90 MIPS target.

## Recommended Phase 13B

Phase 13B should target the remaining control-flow and memory penalties without lengthening the instruction-BRAM address path. Practical options:

- reduce taken BEQ penalty while keeping branch comparison off the BRAM address critical path;
- investigate a small redirect response buffer or epoch tag cleanup if it reduces wrong-path flush cost;
- profile load-use stalls and consider whether memory-result forwarding can reduce any remaining bubble;
- preserve Phase 12 and Phase 13A as separate baselines for comparison.
