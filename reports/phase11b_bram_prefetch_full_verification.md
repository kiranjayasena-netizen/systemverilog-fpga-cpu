# Phase 11B BRAM-Aware Prefetch Full Verification

## Purpose

Phase 11B fully verifies the separate BRAM-aware instruction-prefetch CPU variant against the custom ISA program suite.

Phase 11A proved the basic prefetch mechanism with a focused test. Phase 11B extends that work to the same full-program style used for the Phase 10G BRAM-aware CPU baseline, then compares aggregate CPI and estimated MIPS.

This phase does not replace any existing CPU baseline.

## Context

Phase 10G BRAM-aware CPU simulation baseline:

| Metric | Phase 10G BRAM-aware baseline |
| --- | ---: |
| Cycles | 271 |
| Completed instructions | 58 |
| CPI | 4.672 |
| Estimated MIPS at 100 MHz | 21.402 |

Phase 10H BRAM-aware FPGA implementation result:

| Metric | Phase 10H result |
| --- | ---: |
| LUTs | 937 |
| FFs | 1,211 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| WNS | +3.172 ns |
| TNS | 0.000 ns |
| Estimated Fmax | ~146.5 MHz |
| 100 MHz timing | Passed |

Phase 11A showed that prefetch reduced the sequential arithmetic benchmark from 48 cycles to 30 cycles.

## CPU Variant Under Test

Module tested:

- `rtl/cpu_core_multicycle_bram_prefetch.sv`

The verified baseline modules were not modified:

- `rtl/cpu_core.sv`
- `rtl/cpu_core_multicycle.sv`
- `rtl/cpu_core_multicycle_bram.sv`

The instruction encoding and opcode map were unchanged.

## Testbench

New testbench:

- `tb/tb_cpu_core_multicycle_bram_prefetch_full_programs.sv`

The testbench instantiates `cpu_core_multicycle_bram_prefetch`, preloads the instruction BRAM through hierarchical testbench access, and checks final architectural state after each program.

Coverage:

- Arithmetic edge cases.
- Negative immediate sign extension.
- ADD wraparound and SUB underflow behaviour.
- Register `x0` protection.
- LOAD/STORE base-plus-offset behaviour.
- LOAD with negative offset.
- BEQ taken.
- BEQ not taken.
- Forward JUMP.
- Backward JUMP loop execution.
- Invalid opcode safety.
- Final BRAM data-memory contents.
- `reg_write` only during WRITEBACK.
- `mem_write` only during STORE `MEMORY_ADDR`.
- BEQ/JUMP never assert register or memory writes.

## Prefetch Control-Flow Correctness

The prefetch buffer is used only when the next instruction is safe sequential flow.

The test checks control-flow correctness by verifying the architectural consequences:

- Taken BEQ discards or invalidates the wrong sequential prefetch, so the skipped `x3 = 99` instruction does not execute.
- JUMP discards or invalidates the wrong sequential prefetch, so skipped `x2 = 99` and `x4 = 99` instructions do not execute.
- BEQ not taken continues through the sequential path and executes the fall-through instruction.
- Backward JUMP in the simple loop returns to the correct loop-body target.

## Simulation Result

Vivado XSim regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase11b_xsim_regression_20260710_120845.txt`

Console summary:

```text
Tests run:    135
Tests failed: 0
PHASE 11B BRAM PREFETCH FULL-PROGRAM TEST PASSED
```

The known `xelab` object-directory cleanup warning appeared after snapshots were built. This was non-blocking: snapshots were built, `xsim` ran, and the self-checking testbenches reported PASS.

## Benchmark Results

| Program | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Prefetch arithmetic edge | 30 | 10 | 3.000 | 33.333 |
| Prefetch memory offset | 33 | 9 | 3.667 | 27.273 |
| Prefetch branch control | 30 | 10 | 3.000 | 33.333 |
| Prefetch jump control | 23 | 7 | 3.286 | 30.435 |
| Prefetch simple loop | 49 | 16 | 3.062 | 32.653 |
| Prefetch invalid opcode safety | 14 | 6 | 2.333 | 42.857 |
| Aggregate | 179 | 58 | 3.086 | 32.402 |

Instruction mix:

| Instruction class | Count |
| --- | ---: |
| Arithmetic/ADDI | 34 |
| LOAD | 3 |
| STORE | 4 |
| BEQ | 5 |
| JUMP | 4 |
| NOP | 6 |
| Invalid | 2 |

## Comparison With Phase 10G

| Program | Phase 10G cycles | Phase 11B cycles | Cycle reduction |
| --- | ---: | ---: | ---: |
| Arithmetic edge | 48 | 30 | 18 |
| Memory offset | 49 | 33 | 16 |
| Branch control | 46 | 30 | 16 |
| Jump control | 31 | 23 | 8 |
| Simple loop | 73 | 49 | 24 |
| Invalid opcode safety | 24 | 14 | 10 |
| Aggregate | 271 | 179 | 92 |

| Metric | Phase 10G BRAM-aware baseline | Phase 11B prefetch CPU | Change |
| --- | ---: | ---: | ---: |
| Cycles | 271 | 179 | -92 |
| Completed instructions | 58 | 58 | 0 |
| CPI | 4.672 | 3.086 | Improved |
| Estimated MIPS at 100 MHz | 21.402 | 32.402 | Improved |

The prefetch CPU reduced aggregate cycle count by 92 cycles, or approximately 33.9%, while executing the same 58 completed instructions. Estimated 100 MHz throughput improved from 21.402 MIPS to 32.402 MIPS, approximately a 51.4% increase.

## Interpretation

The prefetch buffer reduces the fetch overhead introduced by synchronous BRAM instruction memory. Sequential programs benefit because the next instruction can often be ready when the current instruction completes.

Control-flow instructions still require care. Taken BEQ and JUMP can make the prefetched sequential instruction wrong, so the CPU must discard or invalidate it. The Phase 11B branch, jump and loop tests show that this mechanism works in simulation for the current custom ISA programs.

## Limitations

- This result is simulation-only.
- The prefetch CPU has not yet been synthesized or implemented.
- Timing and resource impact of the prefetch logic are unknown until Vivado is run.
- Hardware validation is still pending because the Basys 3 board is not available.
- The existing Phase 10G/10H BRAM-aware CPU remains the proven FPGA implementation path until the prefetch path has synthesis and implementation evidence.

## Recommended Next Phase

Phase 11C should create a separate FPGA top-level wrapper and Vivado synthesis/implementation scripts for `cpu_core_multicycle_bram_prefetch`, then compare against Phase 10H:

- LUTs
- FFs
- BRAM usage
- WNS/TNS
- estimated Fmax
- 100 MHz timing status
- CPI/MIPS trade-off

If Phase 11C meets timing with acceptable resource use, the prefetch CPU becomes the strongest candidate for future hardware bring-up and final-year extension work.
