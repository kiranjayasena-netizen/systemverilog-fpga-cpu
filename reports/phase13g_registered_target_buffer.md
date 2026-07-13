# Phase 13G Registered Target-Buffer Experiment

## Purpose

Phase 13G tested whether a timing-safe registered control-flow target buffer could recover some of the Phase 13F CPI improvement without repeating the Phase 13F same-cycle target-buffer hit path that failed timing.

The experiment keeps Phase 13E and Phase 13F available as separate comparison baselines.

## Baseline

Current preferred baseline before this phase: Phase 13E forwarding-path timing pipeline.

| Metric | Phase 13E |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| Best verified period | 8.900 ns |
| Verified Fmax | 112.360 MHz |
| Practical estimated MIPS | ~83.9 |
| LUTs | 1,359 |
| FFs | 1,510 |
| BRAM | 1 tile / 2 RAMB18 |
| WNS | +0.059 ns |
| TNS | 0.000 ns |

Phase 13F reduced aggregate cycles to 401, but its same-cycle target-buffer hit/instruction injection path failed timing at 8.900 ns with WNS -2.002 ns and TNS -13.822 ns. Phase 13F was therefore not accepted.

## Architecture

New separate implementation path:

- `rtl/cpu_core_pipeline_targetbuf_reg.sv`
- `rtl/fpga_top_pipeline_targetbuf_reg.sv`
- `tb/tb_cpu_core_pipeline_targetbuf_reg.sv`
- `scripts/run_vivado_impl_pipeline_targetbuf_reg.tcl`

Phase 13G uses a one-entry JUMP target buffer:

- `target_buffer_valid`
- `target_buffer_pc`
- `target_buffer_instruction`

It also adds registered lookup state:

- `targetbuf_lookup_valid`
- `targetbuf_lookup_hit`
- `targetbuf_lookup_pc`
- `targetbuf_lookup_instruction`

On an ID-stage JUMP redirect, the CPU compares the JUMP target against the target buffer and registers the hit/miss result. It does not inject the buffered instruction into IF/ID in the same cycle. On the following cycle, a registered hit can supply the target instruction; a miss follows the normal Phase 13E instruction-BRAM redirect path.

The first Phase 13G version is JUMP-only. BEQ target buffering is not used. This keeps the branch comparison path off the instruction-memory address path.

## Behaviour Preserved

Phase 13G preserves:

- Phase 13E forwarding behaviour and WB-to-ID bypass behaviour.
- LOAD/STORE behaviour and load-use stalls.
- STORE data forwarding.
- BEQ taken/not-taken behaviour.
- Fast ID-stage JUMP request behaviour.
- Invalid opcode safety.
- `x0` protection.
- Wrong-path register-write and STORE protection.
- Pause/resume and reset behaviour.
- Architectural retirement semantics.
- Synchronous instruction and data BRAM modules.

No instruction encoding, benchmark program, BRAM module or Phase 13E/13F source file was modified.

## Simulation Result

Focused Phase 13G test:

- Transcript: `reports/simulation_transcripts/phase13g_targetbuf_reg_focused_20260713_112502.txt`
- Tests run: 3,264
- Tests failed: 0
- Result: passed

The focused test covered JUMP misses, repeated JUMP target hits, a backward loop, BEQ behaviour, older BEQ flushing a younger JUMP, invalid/wrong-path safety through inherited checks, pause/resume around JUMP handling and no duplicate retirement.

Aggregate benchmark result:

| Metric | Phase 13G |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| MIPS at 100 MHz | 74.707 |
| Target-buffer hits | 18 |
| Target-buffer misses | 1 |

The registered target buffer records hits, but the added register stage means the aggregate CPI is the same as Phase 13E. The experiment did not recover the Phase 13F cycle reduction.

Full local regression was not rerun after the final Phase 13G change because the focused Phase 13G test passed and the variant did not improve the preferred design. The regression script has been updated to include Phase 13G for future full runs.

## Vivado Implementation

Target:

- Board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top_pipeline_targetbuf_reg`
- Vivado: 2026.1

Command:

```powershell
$env:PHASE13G_PERIOD='8.900'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_targetbuf_reg.tcl
```

Routed implementation result:

| Metric | Phase 13G |
| --- | ---: |
| Verified period | 8.900 ns |
| Verified Fmax | 112.360 MHz |
| WNS | +0.058 ns |
| TNS | 0.000 ns |
| WHS | +0.041 ns |
| THS | 0.000 ns |
| LUTs | 1,447 |
| FFs | 1,615 |
| BRAM | 1 tile / 2 RAMB18 |
| DSP | 0 |
| Power estimate | 0.092 W |
| Bitstream | generated |

Report paths:

- `reports/phase13g_timing/perf_directive_8p900ns/utilisation/fpga_top_pipeline_targetbuf_reg_impl_utilization.rpt`
- `reports/phase13g_timing/perf_directive_8p900ns/timing/fpga_top_pipeline_targetbuf_reg_impl_timing_summary.rpt`
- `reports/phase13g_timing/perf_directive_8p900ns/timing/fpga_top_pipeline_targetbuf_reg_impl_worst_paths.rpt`
- `reports/phase13g_timing/perf_directive_8p900ns/route/fpga_top_pipeline_targetbuf_reg_route_status.rpt`
- `reports/phase13g_timing/perf_directive_8p900ns/power/fpga_top_pipeline_targetbuf_reg_impl_power.rpt`

## Critical Path

At 8.900 ns, the worst setup path is timing-clean:

- Source: `cpu_inst/mem_wb_reg_reg[rd][4]_replica/C`
- Destination: `cpu_inst/targetbuf_lookup_instruction_reg[24]/R`
- WNS: +0.058 ns
- Data path delay: 8.330 ns
- Logic delay: 2.291 ns
- Route delay: 6.039 ns
- Logic levels: 9

This confirms that registering the target-buffer lookup avoids the severe Phase 13F same-cycle instruction-memory address/injection timing failure.

## Performance Comparison

Practical estimated MIPS is calculated as:

```text
post-route verified Fmax in MHz / measured aggregate CPI
```

| Architecture | CPI | Verified Fmax | Practical MIPS | LUTs | FFs | BRAM | Status |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Phase 13E forwardtiming | 1.339 | 112.360 MHz | ~83.9 | 1,359 | 1,510 | 1 tile / 2 RAMB18 | Preferred |
| Phase 13F target buffer | 1.257 | Not timing-clean at 8.900 ns | Not accepted | 1,625 | 1,587 | 1 tile / 2 RAMB18 | Failed timing |
| Phase 13G registered target buffer | 1.339 | 112.360 MHz | ~83.9 | 1,447 | 1,615 | 1 tile / 2 RAMB18 | Neutral experiment |

Phase 13G meets timing, but it does not improve practical estimated MIPS over Phase 13E. It also uses more LUTs and FFs than Phase 13E.

## Conclusion

Phase 13G is functionally correct in the focused test and timing-clean at 8.900 ns, but it should not replace Phase 13E. The registered target-buffer lookup removes the Phase 13F timing failure, but also removes the CPI benefit that made Phase 13F attractive.

Phase 13E remains the preferred measured implementation path at about 83.9 practical estimated MIPS.

## Recommended Next Step

Further Phase 13 work should not continue with this one-entry registered target buffer unless a different control-flow benchmark becomes the priority. The next useful optimisation should target either:

- a timing-safe way to reduce JUMP/branch penalty without adding a full extra lookup cycle, or
- the remaining route-heavy operand/forwarding paths while preserving Phase 13E CPI.
