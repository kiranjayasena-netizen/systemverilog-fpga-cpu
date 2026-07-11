# Phase 11D Control-Flow Prefetch Optimisation

## Purpose

Phase 11D adds a separate experimental BRAM-aware prefetch CPU variant that targets the remaining control-flow penalty in the Phase 11C prefetch path.

Phase 11C is currently the best estimated FPGA implementation path: it meets 100 MHz timing and improves practical estimated throughput compared with the non-prefetch BRAM-aware CPU. However, taken BEQ and JUMP instructions still discard the sequentially prefetched instruction. Phase 11D checks whether that redirect penalty can be reduced without replacing the verified Phase 11C baseline.

## Separate CPU Variant

New module:

- `rtl/cpu_core_multicycle_bram_prefetch_ctrlopt.sv`

The following baselines were not modified:

- `rtl/cpu_core.sv`
- `rtl/cpu_core_multicycle.sv`
- `rtl/cpu_core_multicycle_bram.sv`
- `rtl/cpu_core_multicycle_bram_prefetch.sv`

The custom instruction encoding and opcode map were unchanged.

## Optimisation

The Phase 11D variant keeps the Phase 11B/11C BRAM-aware prefetch architecture, but changes taken control-flow handling.

For taken BEQ and JUMP:

- The target address is still calculated as `instruction_pc + (imm_ext << 2)`.
- The wrong sequential prefetch is invalidated or discarded.
- The instruction memory address is redirected to the target during the EXECUTE state.
- The FSM moves directly to `FETCH_CAPTURE` so the target instruction can be captured on the next cycle.

For BEQ not taken:

- Sequential prefetch behaviour is preserved.
- The already correct sequential instruction can still be consumed when valid.

This is a controlled optimisation, not a pipeline. BEQ and JUMP still do not write registers or memory.

## Testbench

New testbench:

- `tb/tb_cpu_core_multicycle_bram_prefetch_ctrlopt.sv`

Coverage:

- Sequential arithmetic benchmark.
- LOAD/STORE memory offset benchmark.
- BEQ taken and BEQ not taken.
- Forward JUMP.
- Backward JUMP loop execution.
- Loop with final STORE result.
- Invalid opcode safety mixed with normal execution.
- Register `x0` protection.
- Final BRAM data memory checks.
- `reg_write` only during WRITEBACK.
- `mem_write` only during STORE `MEMORY_ADDR`.
- BEQ/JUMP never assert register or memory writes.

## Simulation Result

Status: passed.

Standalone command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram_prefetch_ctrlopt.sv tb\tb_cpu_core_multicycle_bram_prefetch_ctrlopt.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_prefetch_ctrlopt -s tb_cpu_core_multicycle_bram_prefetch_ctrlopt_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_prefetch_ctrlopt_sim -runall
```

Regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase11d_xsim_regression_20260711_113910.txt`

Console summary:

```text
Tests run:    135
Tests failed: 0
PHASE 11D BRAM PREFETCH CTRLOPT TEST PASSED
```

The known Vivado XSim `xelab` object-directory cleanup warning appeared after snapshots were built. It was non-blocking: snapshots were built, `xsim` ran, and the self-checking testbenches reported PASS.

## Benchmark Results

| Program | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Ctrlopt arithmetic edge | 30 | 10 | 3.000 | 33.333 |
| Ctrlopt memory offset | 33 | 9 | 3.667 | 27.273 |
| Ctrlopt branch control | 29 | 10 | 2.900 | 34.483 |
| Ctrlopt jump control | 21 | 7 | 3.000 | 33.333 |
| Ctrlopt simple loop | 46 | 16 | 2.875 | 34.783 |
| Ctrlopt invalid opcode safety | 14 | 6 | 2.333 | 42.857 |
| Aggregate | 173 | 58 | 2.983 | 33.526 |

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

## Comparison With Phase 11B

| Program | Phase 11B cycles | Phase 11D cycles | Change |
| --- | ---: | ---: | ---: |
| Arithmetic edge | 30 | 30 | 0 |
| Memory offset | 33 | 33 | 0 |
| Branch control | 30 | 29 | -1 |
| Jump control | 23 | 21 | -2 |
| Simple loop | 49 | 46 | -3 |
| Invalid opcode safety | 14 | 14 | 0 |
| Aggregate | 179 | 173 | -6 |

| Metric | Phase 11B prefetch CPU | Phase 11D ctrlopt prefetch CPU | Result |
| --- | ---: | ---: | --- |
| Cycles | 179 | 173 | Improved |
| Completed instructions | 58 | 58 | Same |
| CPI | 3.086 | 2.983 | Improved |
| Estimated MIPS at 100 MHz | 32.402 | 33.526 | Improved |

The control-flow optimisation reduced aggregate cycle count by 6 cycles, or approximately 3.4%, while executing the same 58 completed instructions. The improvement is concentrated in taken control-flow cases: branch control, jump control and the loop benchmark.

## Interpretation

The optimisation helps where expected:

- Taken BEQ saves one cycle in the branch benchmark.
- Two forward JUMP instructions save two cycles in the jump benchmark.
- The simple loop saves three cycles through repeated redirect handling.

Sequential arithmetic and memory benchmarks stay unchanged, which is the desired result. The optimisation improves aggregate CPI without changing the custom ISA or replacing the verified Phase 11C prefetch CPU baseline.

## Limitations

- This result is simulation-only.
- The Phase 11D control-flow-optimised variant has not yet been synthesized or implemented.
- Timing impact is unknown until Vivado is run.
- Hardware validation remains pending because the Basys 3 board is not available.
- This is not a full pipeline and does not attempt branch prediction.

## Recommended Next Phase

Phase 11E should create a separate FPGA wrapper and Vivado synthesis/implementation scripts for `cpu_core_multicycle_bram_prefetch_ctrlopt`, then compare it with Phase 11C:

- LUTs
- FFs
- BRAM usage
- WNS/TNS
- estimated Fmax
- 100 MHz timing status
- practical estimated MIPS using the Phase 11D CPI

If Phase 11E still meets 100 MHz timing with acceptable resource use, the control-flow-optimised prefetch CPU becomes the strongest estimated-performance path so far.
