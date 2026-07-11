# Phase 12B Pipeline Skeleton Report

## Purpose

Phase 12B creates the first RTL skeleton for a separate pipelined CPU implementation. The goal is to prove instruction fetch timing, IF/ID valid-bit handling and safe NOP/invalid-opcode flow before adding arithmetic, memory, hazards, forwarding or branch redirection.

This phase does not replace any existing CPU implementation and does not change the custom ISA encoding.

## Files Added Or Changed

Added:

- `rtl/cpu_core_pipeline.sv`
- `tb/tb_cpu_core_pipeline_skeleton.sv`
- `reports/phase12b_pipeline_skeleton.md`

Changed:

- `rtl/cpu_defs_pkg.sv`
- `scripts/run_xsim_regression.ps1`
- `README.md`
- `docs/verification.md`

## Fetch Request And Response Timing

The new `cpu_core_pipeline` instantiates `bram_instr_mem`, which has synchronous read behaviour. The instruction output is therefore the response to an address sampled on the previous clock edge.

The skeleton tracks explicit request metadata:

- `fetch_pc` is the next sequential PC to request.
- `fetch_request_pc` is the PC associated with the outstanding BRAM response.
- `fetch_request_valid` marks whether the outstanding response should be accepted.
- `instruction_addr` drives the BRAM address.

When enabled, the core accepts the previous BRAM response into IF/ID using `fetch_request_pc`, then launches the next sequential request and advances `fetch_pc` by four bytes. The first stale BRAM output after reset is ignored because `fetch_request_valid` is cleared.

When paused, the core holds the outstanding request metadata and drives the BRAM with the outstanding request PC so the returned instruction remains paired with the correct PC when execution resumes.

## IF/ID Register Behaviour

The IF/ID pipeline register contains:

- `valid`
- `pc`
- `instruction`

Semantics:

- `valid = 1`: the register contains a real fetched instruction.
- `valid = 0`: the register is a hardware bubble.

Instruction bits in a bubble are ignored for retirement and architectural side effects.

## Valid Bits And Bubbles

Invalid opcodes are converted into bubbles by clearing `if_id_valid`. The returned instruction bits remain visible through `if_id_instruction` for debug, but `decoded_valid` is low and the entry cannot retire.

This keeps software NOP and hardware bubbles distinct:

- Software NOP: `valid = 1`, opcode `OP_NOP`, may retire.
- Hardware bubble: `valid = 0`, no retirement.

## Reset Behaviour

Reset clears:

- fetch PC
- fetch request PC
- fetch request valid
- IF/ID valid
- retirement valid

The initial or stale BRAM output after reset is not accepted as a valid instruction.

## Enable Behaviour

When `enable == 0`:

- `fetch_pc` is held.
- `fetch_request_pc` and `fetch_request_valid` are held.
- IF/ID contents are held.
- `retire_valid` is deasserted so no duplicate retirement event occurs while paused.

When `enable` is reasserted, the held BRAM response is accepted with its saved request PC and sequential fetching continues.

## NOP Behaviour

Phase 12B fetches NOP instructions normally. A valid NOP:

- enters IF/ID with `if_id_valid = 1`;
- decodes as `OP_NOP`;
- produces no register write, memory write or PC redirect;
- produces one retirement event with the correct PC and opcode.

## Invalid-Opcode Behaviour

An invalid opcode:

- is detected using the shared opcode helpers in `cpu_defs_pkg.sv`;
- becomes a hardware bubble with `if_id_valid = 0`;
- does not retire;
- does not assert register write, memory write or PC redirect;
- does not stop later instructions from being fetched and retired.

## Retirement Interface

The Phase 12B retirement/debug interface is:

- `retire_valid`
- `retire_pc`
- `retire_opcode`

`retire_valid` is a one-cycle pulse generated only for valid software NOP instructions. Bubbles, invalid opcodes and non-NOP valid opcodes do not retire in Phase 12B.

## Tests Performed

Focused testbench:

- `tb/tb_cpu_core_pipeline_skeleton.sv`

Coverage:

- reset state;
- stale BRAM response rejection;
- sequential fetch requests at `0, 4, 8, 12, 16`;
- BRAM response pairing with the saved request PC;
- IF/ID valid, PC and instruction contents;
- software NOP retirement exactly once;
- invalid opcode conversion to a bubble;
- later NOPs continuing after an invalid opcode;
- no duplicated or skipped NOP retirement in the directed sequence;
- enable/pause holding fetch and IF/ID state;
- resume without PC/request duplication;
- word alignment checks;
- known valid-control state checks.

Focused result:

- Tests run: 278
- Tests failed: 0
- Pass message: `PHASE 12B PIPELINE SKELETON TEST PASSED`

## Regression Result

Full local Vivado XSim regression was run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Result:

- Full regression completed successfully.
- The Phase 12B test was included in the regression.
- Transcript: `reports/simulation_transcripts/phase12b_xsim_regression_20260711_132223.txt`

Known warning:

- Vivado `xelab` reported the known object-directory cleanup warning after snapshots were built.
- `xsim` ran successfully and the self-checking testbenches reported PASS.

## Known Limitations

Phase 12B intentionally does not implement:

- ADD, SUB, AND, OR or XOR execution;
- ADDI execution;
- register-file writeback;
- data memory;
- LOAD or STORE execution;
- BEQ or JUMP redirection;
- dependency stalls;
- forwarding;
- branch prediction;
- an FPGA top-level;
- synthesis or timing optimisation.

Non-NOP valid opcodes may be fetched and decoded, but they do not retire or perform architectural work in this phase.

## Acceptance Criteria

Phase 12B acceptance criteria are met:

- `rtl/cpu_core_pipeline.sv` exists as a separate implementation path.
- Synchronous instruction-BRAM latency is handled explicitly.
- Returned instructions are paired with their saved request PCs.
- The PC advances sequentially by four only when enabled.
- Reset clears valid pipeline state.
- Disable safely freezes fetch and IF/ID state.
- IF/ID contains valid, PC and instruction state.
- Hardware bubbles use `valid = 0`.
- NOP flows safely and retires once.
- Invalid opcodes become safe bubbles and do not retire.
- Following instructions continue after an invalid opcode.
- The focused self-checking testbench exists and passes.
- The new test is included in the full regression script.
- Existing regression tests pass.

## Recommended Next Phase

Phase 12C should add arithmetic pipeline execution in a controlled way:

- add register-file read state/path for the pipeline;
- add ID/EX and EX/WB-style registers as needed;
- support ADD, SUB, AND, OR, XOR and ADDI;
- preserve x0 protection;
- keep invalid-opcode and bubble safety;
- add conservative stalls before attempting forwarding.
