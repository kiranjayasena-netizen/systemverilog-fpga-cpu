# Phase 14B Six-Stage Pipeline Skeleton

## Purpose

Phase 14B creates the first separate RTL skeleton for the planned deeper pipeline from Phase 14A. It proves the structural IF -> ID -> OP -> EX -> MEM -> WB pipeline shape, synchronous instruction-BRAM request/response tracking, valid-bit movement, reset behaviour, enable/pause behaviour and no-side-effect safety.

This phase does not claim a performance improvement. Phase 13E with the Phase 13I `fanout_opt` implementation strategy remains the preferred measured implementation at about 86.4 practical estimated MIPS.

## Files Added Or Changed

Added:

- `rtl/cpu_core_pipeline6.sv`
- `rtl/fpga_top_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_skeleton.sv`
- `reports/phase14b_pipeline6_skeleton.md`

Changed:

- `scripts/run_xsim_regression.ps1`
- `README.md`
- `docs/verification.md`

The Phase 13E/13I preferred RTL files were not modified.

## Pipeline Structure

```text
IF -> ID -> OP -> EX -> MEM -> WB
```

| Stage | Phase 14B role |
| --- | --- |
| IF | Issues sequential instruction addresses and tracks the request PC for synchronous BRAM response pairing. |
| ID | Receives a real fetched instruction in IF/ID and carries decoded metadata. |
| OP | Placeholder operand-preparation stage. |
| EX | Placeholder execute stage. |
| MEM | Placeholder memory stage. |
| WB | Placeholder retirement stage. |

## Fetch Request/Response Timing

`bram_instr_mem.sv` is synchronous, so the instruction output is not treated as belonging to the current PC in the same cycle. Phase 14B tracks:

- `fetch_request_valid`
- `fetch_request_pc`

When a BRAM response is accepted, the response instruction is paired with the saved request PC and inserted into IF/ID only if the opcode is valid. The first stale output after reset is ignored because `fetch_request_valid` is reset to zero.

During `enable == 0`, the core holds the fetch PC, request metadata and all pipeline registers. A small paused-response buffer preserves an already-returned BRAM instruction so pause/resume does not duplicate or lose a fetch response.

## Pipeline Register Summary

Each pipeline register carries:

- `valid`
- `pc`
- `instruction`
- `opcode`
- `rd`, `rs1`, `rs2`
- sign-extended `imm13`
- decoded validity and simple source/destination metadata

`valid = 1` means the stage contains a real fetched instruction. `valid = 0` means the stage contains a hardware bubble and must not cause architectural work.

## NOP And Invalid Opcode Behaviour

Software NOP is a real valid instruction:

- `valid = 1`
- `opcode = OP_NOP`
- it flows through the six stages
- it produces one placeholder retirement event
- it produces no register or memory side effects

Invalid opcodes are converted into hardware bubbles:

- `valid = 0`
- no retirement event
- no register write
- no memory write
- following instructions continue normally

Other valid non-NOP opcodes may flow through the skeleton as structural placeholders, but Phase 14B does not execute arithmetic, memory or control-flow behaviour yet.

## Debug Outputs

The skeleton exposes debug signals for:

- fetch PC and instruction-memory address
- fetch request validity and PC
- each stage valid bit
- each stage PC and instruction word
- each stage opcode and decoded-valid state
- placeholder retirement pulse, PC, opcode and count
- register-write and memory-write side-effect pulses, both held low in Phase 14B

## Focused XSim Result

Command:

```powershell
xvlog/xelab/xsim for rtl/cpu_defs_pkg.sv, rtl/bram_instr_mem.sv, rtl/cpu_core_pipeline6.sv and tb/tb_cpu_core_pipeline6_skeleton.sv
```

Transcript:

- `reports/simulation_transcripts/phase14b_pipeline6_skeleton_focused_20260713_192051.txt`

Result:

- Focused Phase 14B skeleton test passed.
- Checks run: 198
- Failures: 0

The focused test checks reset, sequential request PCs, IF/ID response PC pairing, stage movement, pause/resume, invalid opcode bubbling, NOP retirement, no duplicate retirement for the checked PCs and no register or memory side effects.

The known Vivado/XSim `xelab` object-directory cleanup warning appeared after the snapshot was built. XSim ran successfully and the self-checking testbench reported PASS.

## Full Regression Result

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase14b_full_xsim_regression_20260713_192118.txt`

Result:

- Full local XSim regression completed successfully.
- The Phase 14B skeleton test was included in the full regression and reported `tests_run=198 tests_failed=0`.
- The known `xelab` object-directory cleanup warning appeared for multiple tests after snapshot build, but XSim completed successfully.

## Known Limitations

Phase 14B is a skeleton only. It does not implement:

- register-file storage or writeback
- ADD/SUB/AND/OR/XOR/ADDI execution
- LOAD/STORE execution
- BEQ/JUMP redirection
- forwarding
- load-use hazard handling
- branch prediction, target buffers or caches
- FPGA implementation or timing measurement for the six-stage path

## Acceptance Criteria

Phase 14B meets its intended scope:

- `rtl/cpu_core_pipeline6.sv` exists as a separate implementation path.
- IF/ID, ID/OP, OP/EX, EX/MEM and MEM/WB valid registers exist.
- Synchronous instruction-BRAM responses are paired with saved request PCs.
- Reset clears valid state and counters.
- Enable/pause holds pipeline state without retirement or side effects.
- NOP flows safely and retires once in the focused test.
- Invalid opcode becomes a safe bubble and does not retire.
- No register or memory write side effects occur.
- Focused XSim and full local regression pass.

## Recommended Next Phase

Phase 14C should add arithmetic execution to the separate six-stage path:

- add a register file or internal register storage;
- implement ADD/SUB/AND/OR/XOR/ADDI;
- preserve x0 protection;
- add basic forwarding or conservative stalls as needed;
- keep Phase 13E/13I as the preferred measured implementation until the Phase 14 path is fully verified and timed.
