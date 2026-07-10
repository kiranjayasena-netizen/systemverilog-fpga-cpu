# Phase 11A BRAM-Aware Instruction Prefetch Prototype

## Purpose

Phase 11A investigates a small performance improvement for the separate BRAM-aware multi-cycle CPU path. Phase 10H showed that the BRAM-aware FPGA implementation is the strongest hardware path so far because it uses far fewer LUTs/FFs than earlier designs and meets the 100 MHz Basys 3 timing target. The remaining weakness is CPI rather than timing.

This phase adds a separate experimental CPU variant with a simple instruction prefetch buffer. It does not replace the verified CPU baselines.

## Starting Point

Phase 10H BRAM-aware FPGA result:

| Metric | Result |
| --- | ---: |
| LUTs | 937 |
| FFs | 1,211 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| WNS | +3.172 ns |
| TNS | 0.000 ns |
| Estimated Fmax | ~146.5 MHz |
| 100 MHz timing | Passed |

Phase 10G BRAM-aware full-program simulation result:

| Metric | Result |
| --- | ---: |
| Cycles | 271 |
| Instructions | 58 |
| CPI | 4.672 |
| Estimated MIPS at 100 MHz | 21.402 |

## New Prototype

New module:

- `rtl/cpu_core_multicycle_bram_prefetch.sv`

The module is based on the verified BRAM-aware CPU behaviour, but it is kept as a separate implementation path. The existing `rtl/cpu_core_multicycle_bram.sv`, `rtl/cpu_core_multicycle.sv` and original `rtl/cpu_core.sv` files were not modified.

The prototype adds these prefetch-related debug signals:

- `prefetch_valid`
- `prefetch_pc`
- `prefetch_instruction`

The prefetch buffer is used only for safe sequential next-PC flow. Taken BEQ and JUMP instructions invalidate or discard the sequential prefetch so that the CPU does not execute a wrong-path instruction. BEQ not-taken flow may use the sequential prefetch when it matches the next PC.

## FSM Behaviour

The BRAM-aware prefetch variant keeps the same broad FSM structure as the Phase 10F/10G BRAM-aware CPU:

- `FETCH_ADDR`
- `FETCH_CAPTURE`
- `DECODE`
- `EXECUTE`
- `MEMORY_ADDR`
- `MEMORY_CAPTURE`
- `WRITEBACK`

For sequential code, the CPU can consume a matching prefetched instruction and enter `DECODE` directly instead of performing a full explicit fetch sequence for every instruction. LOAD and STORE still preserve synchronous BRAM data-memory timing. Branch and jump targets still use:

```text
instruction_pc + (imm_ext << 2)
```

## Basic Test Coverage

New testbench:

- `tb/tb_cpu_core_multicycle_bram_prefetch_basic.sv`

Coverage:

- Reset state and `prefetch_valid` reset behaviour.
- Sequential arithmetic execution.
- LOAD/STORE execution with BRAM data-memory latency.
- Taken BEQ wrong-path prefetch invalidation.
- JUMP wrong-path prefetch invalidation.
- BEQ not-taken fall-through behaviour.
- `x0` write protection.
- Invalid opcode safety.
- `reg_write` only during `WRITEBACK`.
- `mem_write` only during STORE `MEMORY_ADDR`.

## Simulation Result

Vivado XSim regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase11a_xsim_regression_20260710_113107.txt`

Phase 11A console summary:

```text
Tests run:    52
Tests failed: 0
PHASE 11A BRAM PREFETCH BASIC TEST PASSED
```

The known `xelab` object-directory cleanup warning appeared after the snapshot was built. This was non-blocking: `xsim` ran and the self-checking testbench reported PASS.

## CPI Comparison

The Phase 11A testbench includes a sequential arithmetic benchmark so the prefetch effect can be compared with the equivalent Phase 10G BRAM-aware arithmetic edge result.

| Design | Benchmark | Cycles | Instructions | CPI | Estimated MIPS at 100 MHz |
| --- | --- | ---: | ---: | ---: | ---: |
| Phase 10G BRAM-aware baseline | Arithmetic edge | 48 | 10 | 4.800 | 20.833 |
| Phase 11A BRAM-aware prefetch prototype | Sequential arithmetic | 30 | 10 | 3.000 | 33.333 |

For this sequential arithmetic benchmark, the prefetch prototype reduced the cycle count by 18 cycles, a 37.5% reduction. Estimated throughput improved from 20.833 MIPS to 33.333 MIPS at 100 MHz.

This is an encouraging result, but it is only a basic benchmark. Full custom-ISA verification is still required before treating the prefetch CPU as a complete replacement candidate.

## Limitations

- Phase 11A is a basic prototype test, not full custom-ISA verification.
- The prefetch variant has not yet been synthesized or implemented.
- CPI improvement has only been measured on a small sequential arithmetic benchmark.
- Hardware validation remains pending until the Basys 3 board is available.
- The existing verified CPU baselines are preserved and remain the reference implementations.

## Recommended Next Phase

Phase 11B should run full custom-ISA program verification against `cpu_core_multicycle_bram_prefetch.sv`, reusing the Phase 10G style of coverage:

- arithmetic edge cases
- memory offsets
- BEQ taken and not taken
- JUMP forward and backward
- simple loop execution
- invalid opcode safety
- CPI/MIPS comparison across the full program set

If Phase 11B passes, a later Phase 11C can synthesize and implement a separate FPGA top for the prefetch CPU and compare timing/resource results against Phase 10H.
