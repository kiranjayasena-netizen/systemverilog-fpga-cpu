# Phase 12A Pipelined CPU Architecture Plan

## Purpose

Phase 12A plans a future pipelined CPU implementation for the custom SystemVerilog FPGA CPU project.

This phase is documentation-only. It does not change RTL, testbenches, program files, Vivado scripts, instruction encodings or existing implementation results.

## Why Pipelining Is The Next Performance Step

The project has already explored several implementation paths:

- The original single-cycle-style CPU was simple, but did not meet the 100 MHz Basys 3 post-route timing target.
- The separate multi-cycle CPU improved timing closure.
- The BRAM-aware multi-cycle CPU inferred FPGA block RAM and met timing.
- The BRAM-aware prefetch CPU improved CPI while still meeting timing.
- The control-flow-optimised prefetch CPU gave the best estimated throughput so far.

The current remaining performance limit is no longer basic timing closure. The best current design already meets 100 MHz, but its CPI is still above 1 because each instruction uses several FSM states. A pipeline is the next architectural step because it can overlap instruction fetch, decode, execute, memory and writeback work.

The long-term target is not to replace the verified baseline immediately. The goal is to create a separate pipelined implementation path that can be verified and compared against the existing Phase 11E result.

## Current Best Baseline

Current best estimated-throughput implementation path:

- Phase: Phase 11E control-flow-optimised BRAM prefetch CPU.
- BRAM inferred: 1 Block RAM Tile / 2 RAMB18.
- 100 MHz timing: passed.
- Post-route WNS: +1.128 ns.
- Estimated Fmax: about 112.7 MHz.
- Simulation CPI: 2.983.
- Practical estimated MIPS: about 37.8.

This is the baseline that a future pipeline should beat on practical estimated throughput while preserving correctness and reasonable FPGA resource use.

## Proposed 5-Stage Pipeline

The first pipelined design should use a conventional five-stage structure:

| Stage | Name | Purpose |
| --- | --- | --- |
| IF | Instruction fetch | Read instruction memory and track the instruction PC. |
| ID | Decode/register read | Decode fields, sign-extend `imm13`, read source registers and generate control. |
| EX | Execute/branch target | Run ALU operations, calculate LOAD/STORE addresses and calculate branch/jump targets. |
| MEM | Data memory access | Perform LOAD reads and STORE writes. |
| WB | Register writeback | Write ALU or LOAD results to the register file. |

The pipeline should remain custom-ISA compatible. It should not change instruction encodings, opcode values, register numbering, `x0` behaviour or branch/jump offset conventions.

## Proposed Pipeline Registers

The pipeline should use four major pipeline register groups:

- `IF/ID`
- `ID/EX`
- `EX/MEM`
- `MEM/WB`

### IF/ID Contents

Suggested fields:

- `valid`
- `instruction`
- `instruction_pc`
- optional predicted/sequential next PC metadata

### ID/EX Contents

Suggested fields:

- `valid`
- `instruction_pc`
- `opcode`
- `rd`
- `rs1`
- `rs2`
- `imm13`
- `imm_ext`
- `operand_a`
- `operand_b`
- decoded control signals:
  - `reg_write`
  - `mem_read`
  - `mem_write`
  - `mem_to_reg`
  - `alu_op`
  - `use_imm`
  - `branch`
  - `jump`
  - `valid_instr`

### EX/MEM Contents

Suggested fields:

- `valid`
- `instruction_pc`
- `opcode`
- `rd`
- `rs2`
- `alu_result`
- `store_data`
- `branch_taken`
- `pc_target`
- control signals needed by MEM and WB:
  - `reg_write`
  - `mem_read`
  - `mem_write`
  - `mem_to_reg`
  - `valid_instr`

### MEM/WB Contents

Suggested fields:

- `valid`
- `opcode`
- `rd`
- `alu_result`
- `memory_read_data`
- `writeback_data`
- `reg_write`
- `mem_to_reg`
- `valid_instr`

## Instruction Flow

### NOP

1. IF fetches the instruction.
2. ID decodes opcode `4'h0`.
3. EX does no state-changing work.
4. MEM does no memory access.
5. WB does no register write.

NOP may be allowed to move through all stages as a safe bubble, or it may be converted into a bubble during decode.

### ADD, SUB, AND, OR, XOR

1. IF fetches the instruction.
2. ID reads `rs1` and `rs2`.
3. EX performs the ALU operation.
4. MEM passes the ALU result forward.
5. WB writes the result to `rd`, unless `rd == x0`.

### ADDI

1. IF fetches the instruction.
2. ID reads `rs1` and sign-extends `imm13`.
3. EX calculates `rs1 + imm_ext`.
4. MEM passes the ALU result forward.
5. WB writes the result to `rd`, unless `rd == x0`.

### LOAD

1. IF fetches the instruction.
2. ID reads base register `rs1` and sign-extends `imm13`.
3. EX calculates the byte address `rs1 + imm_ext`.
4. MEM reads data memory.
5. WB writes memory data to `rd`, unless `rd == x0`.

Because BRAM reads are synchronous, the exact LOAD timing may require either a registered MEM result or an additional memory capture mechanism.

### STORE

1. IF fetches the instruction.
2. ID reads base register `rs1`, store register `rs2` and sign-extends `imm13`.
3. EX calculates the byte address `rs1 + imm_ext`.
4. MEM writes `rs2` data to data memory.
5. WB performs no register write.

### BEQ

1. IF fetches the instruction.
2. ID reads `rs1`, `rs2` and sign-extends `imm13`.
3. EX compares operands and calculates `instruction_pc + (imm_ext << 2)`.
4. If taken, the PC is redirected and wrongly fetched sequential instructions are flushed.
5. MEM and WB perform no state-changing work.

The initial design should resolve BEQ in EX for simplicity.

### JUMP

1. IF fetches the instruction.
2. ID sign-extends `imm13`.
3. EX calculates `instruction_pc + (imm_ext << 2)`.
4. The PC is redirected and wrongly fetched sequential instructions are flushed.
5. MEM and WB perform no state-changing work.

### Invalid Opcode

1. IF fetches the instruction.
2. ID marks the instruction invalid.
3. Later stages treat it as a safe bubble.
4. No register write occurs.
5. No memory write occurs.
6. Control-flow side effects are blocked.

## Hazard Plan

### Data Hazards

Data hazards occur when an instruction consumes a register that an earlier instruction has not written back yet.

Initial approach:

- Detect RAW hazards in ID.
- Stall until the producing instruction reaches a safe forwarding or writeback point.
- Preserve `x0` behaviour by ignoring hazards where the producer writes `rd == 0`.

### Load-Use Hazards

LOAD results are available later than ALU results, especially with synchronous BRAM data memory.

Initial approach:

- Stall one or more cycles when the instruction after a LOAD uses the loaded register.
- Later add forwarding from the memory result path when timing and correctness are clear.

### Control Hazards

BEQ and JUMP change the PC after the next sequential instruction may already be in the pipeline.

Initial approach:

- Resolve BEQ and JUMP in EX.
- Flush IF/ID and ID/EX when a taken BEQ or JUMP redirects the PC.
- Do not execute wrongly fetched sequential instructions after a taken control-flow instruction.

### Structural Hazards

The project already separates instruction and data memory in the BRAM-aware path, which reduces structural conflicts between instruction fetch and data memory access.

Initial approach:

- Use separate instruction BRAM and data BRAM paths.
- Avoid a shared single memory port for instruction and data accesses in the first pipelined design.

## Initial Hazard Strategy

The first pipelined implementation should prioritise correctness over peak CPI:

- Use stalls first.
- Add forwarding later.
- Flush on taken BEQ/JUMP.
- Treat invalid opcodes as bubbles.
- Keep STORE writes and register writes guarded by valid pipeline control.

This reduces the risk of subtle forwarding or flush bugs while establishing the base pipeline.

## Forwarding Plan For Later Work

Forwarding should be added after the stall-only pipeline passes basic tests.

Planned forwarding paths:

- `EX/MEM` to `EX` for ALU results needed by the following instruction.
- `MEM/WB` to `EX` for older ALU or LOAD results.
- STORE data forwarding if a STORE writes a value just produced by a prior instruction.

LOAD-use hazards still need special handling because the data may not be available early enough for the immediately following EX stage. A stall is expected when forwarding is not enough.

## Branch And Jump Handling

The branch and jump target convention must stay unchanged:

```text
branch_or_jump_target = instruction_pc + (imm_ext << 2)
```

Initial plan:

- Resolve BEQ in EX.
- Resolve JUMP in EX.
- Use the instruction's own `instruction_pc`, not an already incremented PC.
- Flush wrongly fetched sequential instructions on taken BEQ and JUMP.
- Allow not-taken BEQ to continue sequentially.

Future optimisation could move JUMP target calculation earlier, but only after the basic EX-stage redirect path is verified.

## BRAM Memory Considerations

The pipelined CPU should preserve the FPGA-friendly BRAM direction from Phase 10H and Phase 11E.

Instruction memory:

- Use synchronous instruction BRAM.
- Account for one-cycle read latency in IF.
- Keep instruction fetch independent from data memory access.

Data memory:

- Use synchronous data BRAM.
- STORE writes occur in MEM.
- LOAD data is captured for WB after the synchronous read latency.

The exact IF stage may need an internal fetch request/capture split, even if the external pipeline is described as IF/ID/EX/MEM/WB. This should be documented clearly when Phase 12B begins.

## Verification Roadmap

Recommended verification sequence:

1. Pipeline skeleton:
   - reset
   - PC sequencing
   - pipeline register valid bits
   - NOP/bubble flow
2. Arithmetic-only tests:
   - ADD, SUB, AND, OR, XOR, ADDI
   - `x0` protection
   - negative immediate sign extension
3. Memory tests:
   - LOAD
   - STORE
   - base + offset addressing
   - negative offset load
   - LOAD-use stall cases
4. Branch/jump tests:
   - BEQ taken
   - BEQ not taken
   - forward JUMP
   - backward JUMP loop
   - flush correctness
5. Hazard tests:
   - ALU-to-ALU dependencies
   - LOAD-to-ALU dependencies
   - LOAD-to-STORE dependencies
   - branch operand dependencies
6. Forwarding tests:
   - `EX/MEM` to `EX`
   - `MEM/WB` to `EX`
   - load-use stall with forwarding enabled
7. Full custom-ISA regression:
   - reuse Phase 6 and Phase 8/10/11 program patterns where practical
8. Performance benchmarking:
   - cycle count
   - completed instruction count
   - CPI
   - estimated MIPS

## Synthesis And Timing Comparison Plan

The pipeline should eventually be compared against Phase 11E:

| Metric | Compare against Phase 11E |
| --- | --- |
| LUTs | Check extra control, hazard and forwarding cost. |
| FFs | Pipeline registers will increase FF usage. |
| BRAM | Should remain at least instruction/data BRAM based. |
| DSP | Expected to remain 0 unless the ALU changes. |
| WNS | Must meet 100 MHz initially. |
| TNS | Should remain 0 for timing-clean implementation. |
| Estimated Fmax | Should improve or remain acceptable. |
| CPI | Should approach 1 on hazard-free sequential code. |
| Practical MIPS | Estimated Fmax divided by measured CPI. |

The pipeline is only worthwhile if improved CPI is not cancelled by lower Fmax or excessive resource growth.

## Risks

Key risks:

- Incorrect stalls causing instructions to execute twice or be skipped.
- Incorrect forwarding producing stale operand values.
- Wrong branch flush allowing a skipped instruction to commit.
- LOAD data being consumed before it is valid.
- Broken `x0` write protection through forwarding or writeback.
- Invalid opcode safety lost in later pipeline stages.
- STORE write enable asserted for flushed or invalid instructions.
- Increased timing pressure from hazard detection or forwarding muxes.
- Testbenches assuming fixed cycle counts from older CPU variants.

## Acceptance Criteria For Phase 12A

Phase 12A is complete when:

- This planning document exists.
- No RTL was changed.
- No testbenches were changed.
- No program files were changed.
- No instruction encodings were changed.
- The proposed pipeline stages and pipeline registers are documented.
- The hazard, forwarding, branch/jump, BRAM, verification and synthesis comparison plans are documented.
- There is a clear roadmap for Phase 12B onward.

## Suggested Later Subphases

- Phase 12B: pipeline skeleton with PC, IF/ID, valid bits and NOP/bubble flow.
- Phase 12C: arithmetic pipeline execution with conservative stalls.
- Phase 12D: LOAD/STORE pipeline execution with BRAM latency handling.
- Phase 12E: BEQ/JUMP control-flow handling and flush verification.
- Phase 12F: hazard detection and stall verification.
- Phase 12G: forwarding implementation and tests.
- Phase 12H: full custom-ISA pipelined regression.
- Phase 12I: pipelined synthesis, implementation and timing/resource/performance comparison.

## Recommended Next Phase

The recommended next phase is Phase 12B: create a separate pipelined CPU skeleton. It should not replace the Phase 11E implementation path. The first skeleton should focus on PC sequencing, pipeline register valid bits and safe NOP/invalid instruction handling before adding arithmetic or memory behaviour.
