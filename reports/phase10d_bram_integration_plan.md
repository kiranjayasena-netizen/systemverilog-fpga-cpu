# Phase 10D BRAM Integration Plan

## Purpose

Phase 10D defines a safe plan for integrating the Phase 10C BRAM-style instruction and data memories into a future multi-cycle CPU implementation.

This phase is planning-only. It does not modify CPU RTL, existing memory modules, instruction encodings or program files.

## Phase 10C Summary

Phase 10C added standalone BRAM-style memory prototypes:

- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `tb/tb_bram_instr_mem.sv`
- `tb/tb_bram_data_mem.sv`

Both standalone tests passed in Vivado XSim:

- BRAM instruction memory: 9 tests run, 0 failed.
- BRAM data memory: 13 tests run, 0 failed.

The full XSim regression also passed after adding the Phase 10C tests. These memories are standalone prototypes only and are not yet integrated into `cpu_core_multicycle`.

## Why This Is Not A Simple Module Swap

The existing verified CPU paths were built around memories that are effectively available without an extra read-capture cycle in the CPU interface.

The BRAM-style memories from Phase 10C use synchronous reads. That means:

- instruction fetch needs an address phase and a later capture phase,
- LOAD needs an address phase and a later capture phase,
- instruction and data outputs are not valid immediately after changing the address,
- existing testbench cycle expectations would need to change.

Replacing the current memories directly would risk stale instruction capture, off-by-one PC behaviour and LOAD writeback before memory data is valid.

## Proposed BRAM-Aware FSM States

A BRAM-aware multi-cycle CPU should use explicit memory latency states:

- `FETCH_ADDR`
- `FETCH_CAPTURE`
- `DECODE`
- `EXECUTE`
- `MEMORY_ADDR`
- `MEMORY_CAPTURE`
- `WRITEBACK`

The exact state names can change during implementation, but the timing separation should remain clear.

## Proposed Instruction State Sequences

| Instruction | Proposed state sequence |
| --- | --- |
| NOP | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> FETCH_ADDR` |
| ADD/SUB/AND/OR/XOR/ADDI | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> WRITEBACK -> FETCH_ADDR` |
| LOAD | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> MEMORY_ADDR -> MEMORY_CAPTURE -> WRITEBACK -> FETCH_ADDR` |
| STORE | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> MEMORY_ADDR -> FETCH_ADDR` |
| BEQ | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> FETCH_ADDR` |
| JUMP | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> FETCH_ADDR` |
| Invalid opcode | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> FETCH_ADDR` |

Invalid opcodes must remain safe: no register write, no memory write and no unintended PC target update.

## PC Handling

The BRAM-aware CPU should keep an `instruction_pc` register, as the current multi-cycle CPU already does.

Branch and jump targets must continue to use:

```text
instruction_pc + (imm_ext << 2)
```

For default sequential flow, the PC should advance by 4 only when the CPU has safely committed to fetching the next sequential instruction. A conservative approach is:

1. Use `pc` as the address presented during `FETCH_ADDR`.
2. Capture the returned instruction and the associated `instruction_pc` in `FETCH_CAPTURE`.
3. Update `pc` to `pc + 4` for default sequential flow after the fetch address has been accepted.
4. Override `pc` in `EXECUTE` for taken BEQ or JUMP using the saved `instruction_pc`.

The implementation must avoid using a PC value that has already advanced when calculating branch and jump targets.

## LOAD Handling

LOAD should be staged so memory data is only written back after it is valid:

1. `DECODE`: capture source register data and sign-extended immediate.
2. `EXECUTE`: calculate `effective_address = operand_a_reg + imm_ext_reg`.
3. `MEMORY_ADDR`: present the effective address to data BRAM and assert `mem_read`.
4. `MEMORY_CAPTURE`: capture the synchronous BRAM read data.
5. `WRITEBACK`: write the captured data to `rd` if `rd != x0`.

LOAD to `x0` must still leave `x0` unchanged.

## STORE Handling

STORE should be staged so address, data and write enable are aligned:

1. `DECODE`: capture base register data and store data from `rs2`.
2. `EXECUTE`: calculate `effective_address = operand_a_reg + imm_ext_reg`.
3. `MEMORY_ADDR` or a dedicated `MEMORY_WRITE`: present the effective address, store data and assert write enable for one clock edge.
4. Return to `FETCH_ADDR`.

STORE must not write the register file.

## CPI Impact

BRAM reads may add states compared with the current `cpu_core_multicycle` implementation.

Expected impact:

- NOP and invalid instructions may take more cycles because fetch is split.
- Arithmetic instructions may gain at least one extra fetch-related cycle.
- LOAD instructions may gain both fetch and data-memory capture overhead.
- STORE instructions may gain fetch overhead and possibly an explicit memory-write state.
- CPI may increase, reducing estimated MIPS.

The benefit is that BRAM usage should increase from the current 0 BRAM baseline, LUT-based memory usage may reduce, and timing/routing may become more predictable.

## Verification Plan

Future BRAM integration should be verified incrementally:

1. Focused FSM fetch test:
   - reset state,
   - `FETCH_ADDR`,
   - `FETCH_CAPTURE`,
   - instruction register capture,
   - sequential PC behaviour.
2. Arithmetic regression:
   - ADDI,
   - ADD/SUB/AND/OR/XOR,
   - negative immediate,
   - `x0` protection.
3. Memory regression:
   - STORE,
   - LOAD,
   - base + offset,
   - negative offset,
   - LOAD to `x0`.
4. Branch/jump regression:
   - BEQ taken,
   - BEQ not taken,
   - JUMP forward,
   - backward JUMP loop.
5. Full custom-ISA regression:
   - reuse Phase 8F-style program coverage.
6. Performance remeasurement:
   - repeat Phase 10A-style CPI and MIPS benchmarking with the BRAM-aware CPU.

## Implementation And Timing Comparison Plan

After functional simulation passes, create a separate FPGA top and Vivado scripts for the BRAM-aware path.

The comparison should include:

- LUTs,
- FFs,
- BRAM usage,
- DSP usage,
- WNS,
- TNS,
- estimated Fmax,
- CPI,
- estimated MIPS.

The key implementation check is confirming that Vivado infers BRAM resources from the new memory path.

## Risks

- Off-by-one fetch errors.
- Capturing a stale instruction.
- Updating `pc` too early for branch/jump target calculation.
- LOAD writeback before BRAM data is valid.
- STORE write enable asserted in the wrong state.
- STORE address or write data changing before the write edge.
- Increased CPI reducing estimated MIPS.
- Small memory sizes not inferring BRAM unless synthesis style or attributes are adjusted.

## Acceptance Criteria For Phase 10D

Phase 10D is complete when:

- this planning document exists,
- no CPU RTL has been changed,
- no instruction encodings have been changed,
- BRAM integration is clearly marked as future work,
- the next implementation phase has a clear state-machine and verification plan.

## Recommended Next Phase

The recommended next phase is Phase 10E: create a separate BRAM-aware multi-cycle CPU variant or wrapper.

That implementation should preserve the existing verified `cpu_core_multicycle` path and introduce BRAM integration behind a new module name, so the project can compare the current timing-clean multi-cycle implementation against a BRAM-backed implementation without risking the verified baseline.
