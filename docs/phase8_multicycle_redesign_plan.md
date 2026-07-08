# Phase 8 Multi-Cycle Redesign Plan

## Purpose Of Phase 8

Phase 8 plans a future redesign of the CPU from the current simple single-cycle-style implementation into a multi-cycle implementation. The goal is to keep the existing custom ISA and verified program behaviour, while shortening the combinational path that caused the Phase 7D post-route timing miss.

Phase 8A is documentation-only. It does not change RTL, testbenches, program files or instruction encodings.

## Why A Multi-Cycle Redesign Is Needed

The Phase 7 baseline is functionally useful and has strong simulation coverage through Phase 6F, but the implemented FPGA design does not meet the 100 MHz Basys 3 setup timing target. The current CPU tries to complete fetch, decode, register read, execute, memory selection and writeback in one clock cycle.

A multi-cycle design splits one instruction across several shorter clock cycles. This should reduce the amount of combinational logic between registers in each cycle, improving the chance of meeting timing without changing the instruction set.

## Phase 7D Timing Problem Summary

Phase 7D recorded the following post-route timing result:

- Target board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Target clock: 10.000 ns, 100 MHz
- WNS: -1.551 ns
- TNS: -5707.315 ns
- Hold timing: met
- Estimated maximum frequency from worst slack: approximately 86.6 MHz
- Worst path: `cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C` to `cpu_inst/reg_file_inst/regs_reg[2][12]/D`
- Critical-path classification: single-cycle-style PC/fetch/decode/execute/writeback path

The design fits in FPGA resources, so the main problem is timing closure, not device capacity.

## Current Single-Cycle-Style Critical Path

The current integrated CPU structure lets one instruction influence the datapath and writeback destination within a single clock period. The worst path begins in the program counter, passes through instruction fetch/decode/control and datapath selection logic, and ends at a register-file write destination.

This is expected for an educational single-cycle-style CPU. It is easy to understand and verify, but it creates a long path that must settle inside one 10 ns clock period. The Phase 7D report shows that this path is too long after placement and routing.

## Proposed Multi-Cycle Architecture

The proposed Phase 8 architecture should execute each instruction across a small finite-state machine. Each state performs one part of instruction execution and stores intermediate results in internal registers.

High-level datapath idea:

1. Fetch instruction and capture it in an instruction register.
2. Decode opcode, register fields and immediate into stable internal registers.
3. Read register operands and capture them.
4. Execute ALU, branch or jump operation.
5. Access data memory when needed.
6. Write back to the register file when needed.

The custom ISA should remain unchanged. Only the internal timing of instruction execution changes.

## Proposed FSM States

| State | Purpose |
| --- | --- |
| `FETCH` | Use the current PC to read instruction memory, capture the instruction, and capture the instruction PC for branch/jump target calculation. |
| `DECODE` | Decode opcode, register indexes and sign-extended immediate. Read source registers and capture operand values. |
| `EXECUTE` | Perform ALU operation, address calculation, branch comparison or jump target calculation. |
| `MEMORY` | Perform LOAD read or STORE write when the instruction requires data memory. |
| `WRITEBACK` | Write ALU or memory result to the register file when the instruction requires register writeback. |

Implementation detail to decide in Phase 8B: the PC may be updated in `FETCH` for the default `pc + 4` path, or later after `EXECUTE`. If the default PC is updated early, the design must keep an `instruction_pc` register so BEQ and JUMP still use the current instruction PC for:

```text
pc_target = instruction_pc + (imm_ext << 2)
```

## Instruction State Sequences

The table below shows the expected control flow for each instruction. It is a planning target, not an RTL implementation yet.

| Instruction | State sequence | Main action |
| --- | --- | --- |
| NOP | `FETCH -> DECODE -> FETCH` | Recognise a valid no-op and perform no register or memory write. |
| ADD | `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH` | Add `rs1` and `rs2`; write result to `rd`. |
| SUB | `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH` | Subtract `rs2` from `rs1`; write result to `rd`. |
| AND | `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH` | Bitwise AND `rs1` and `rs2`; write result to `rd`. |
| OR | `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH` | Bitwise OR `rs1` and `rs2`; write result to `rd`. |
| XOR | `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH` | Bitwise XOR `rs1` and `rs2`; write result to `rd`. |
| ADDI | `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH` | Add `rs1` and sign-extended `imm13`; write result to `rd`. |
| LOAD | `FETCH -> DECODE -> EXECUTE -> MEMORY -> WRITEBACK -> FETCH` | Calculate address, read data memory, write loaded value to `rd`. |
| STORE | `FETCH -> DECODE -> EXECUTE -> MEMORY -> FETCH` | Calculate address and write `rs2` data to data memory. |
| BEQ | `FETCH -> DECODE -> EXECUTE -> FETCH` | Compare `rs1` and `rs2`; update PC to target only if equal. |
| JUMP | `FETCH -> DECODE -> EXECUTE -> FETCH` | Unconditionally update PC to the PC-relative target. |
| Invalid opcode | `FETCH -> DECODE -> FETCH` | Mark invalid and prevent register or data-memory writes. |

An implementation could use a fixed five-cycle sequence for every instruction to simplify testing, but the preferred design should allow shorter paths for NOP, branch, jump and store if it remains clear and verifiable.

## Required Internal Registers

The multi-cycle CPU will need internal state that the current single-cycle-style path does not require:

- `state`: current FSM state.
- `next_state`: next FSM state.
- `instruction_reg`: instruction captured during `FETCH`.
- `instruction_pc`: PC value for the instruction currently being executed.
- `opcode_reg`: decoded opcode.
- `rd_reg`: decoded destination register index.
- `rs1_reg`: decoded source register 1 index.
- `rs2_reg`: decoded source register 2 index.
- `imm13_reg`: decoded immediate field.
- `imm_ext_reg`: sign-extended immediate.
- `operand_a_reg`: captured `rs1` data.
- `operand_b_reg`: captured `rs2` data.
- `alu_result_reg`: registered ALU result or calculated address.
- `mem_read_data_reg`: captured LOAD data.
- `valid_instr_reg`: decoded instruction validity.
- Control registers or one-cycle control enables for register write, memory read/write, memory-to-register selection, branch and jump.

The exact register names can change during implementation, but these roles should be present to break the long Phase 7 critical path.

## Compatibility Requirements

The multi-cycle redesign must preserve:

- Custom 32-bit instruction format:
  - `instruction[31:28] = opcode`
  - `instruction[27:23] = rd`
  - `instruction[22:18] = rs1`
  - `instruction[17:13] = rs2`
  - `instruction[12:0] = imm13`
- Existing opcode map:
  - `4'h0 = NOP`
  - `4'h1 = ADD`
  - `4'h2 = SUB`
  - `4'h3 = AND`
  - `4'h4 = OR`
  - `4'h5 = XOR`
  - `4'h6 = ADDI`
  - `4'h7 = LOAD`
  - `4'h8 = STORE`
  - `4'h9 = BEQ`
  - `4'ha = JUMP`
- ALU opcode behaviour used by the existing control unit.
- Register `x0` write protection.
- Signed `imm13` sign extension.
- Branch and jump word-offset convention:

```text
pc_target = current_instruction_pc + (imm_ext << 2)
```

- Existing `.mem` program format and hex instruction words.
- Invalid opcode safety:
  - no register-file write
  - no data-memory write
  - no unintended state corruption

## Verification Plan

The Phase 8 verification strategy should compare final architectural state against the verified Phase 6 baseline.

Planned approach:

- Reuse Phase 6 program files where possible.
- Keep final register and data-memory expected values identical to Phase 6.
- Update testbench cycle expectations because each instruction now takes multiple cycles.
- Avoid fixed small cycle counts where possible; use generous maximum cycle counts or done/trace conditions.
- Add state/FSM tests to verify legal state transitions.
- Add tests for reset from each major state if practical.
- Check that invalid opcodes still suppress register and memory writes.
- Check that `x0` remains zero across arithmetic, memory and invalid-opcode programs.
- Check that branch and jump targets are still calculated from the current instruction PC, not accidentally from `pc + 4`.
- Keep waveform evidence for at least one arithmetic, one memory and one control-flow program.

Recommended reused programs:

- `programs/arithmetic_edge_test.mem`
- `programs/memory_offset_test.mem`
- `programs/branch_taken_not_taken_test.mem`
- `programs/jump_test.mem`
- `programs/simple_loop_test.mem`
- `programs/invalid_opcode_test.mem`

## FPGA And Timing Comparison Plan

Phase 8 should compare the old Phase 7 baseline against the new multi-cycle implementation.

Baseline to preserve:

- Phase 7C implementation result:
  - LUTs: 2,983
  - FFs: 8,314
  - WNS: -1.551 ns
  - TNS: -5707.315 ns
  - Estimated maximum frequency: approximately 86.6 MHz

Comparison flow:

1. Re-run or reference the Phase 7 single-cycle-style synthesis and implementation reports.
2. Synthesize the Phase 8 multi-cycle design for `xc7a35tcpg236-1`.
3. Implement the Phase 8 design for the same Basys 3 constraints.
4. Compare LUT usage.
5. Compare FF usage.
6. Compare BRAM and DSP usage.
7. Compare WNS and TNS.
8. Estimate maximum frequency from worst slack.
9. Compare worst path source, destination and classification.
10. Document whether timing closure improved and what resource cost was paid.

Expected tradeoff: the multi-cycle design will probably use more registers and control logic, but should shorten the main combinational path.

## Risks

- Control FSM bugs causing instructions to skip states or repeat states.
- PC update mistakes, especially around default `pc + 4` versus branch/jump target updates.
- LOAD timing changes if memory read data is captured in a different cycle.
- STORE timing changes if write address/data/control are not stable in the `MEMORY` state.
- Branch and jump timing changes if target calculation uses the wrong PC value.
- Invalid opcodes accidentally writing registers or memory.
- Testbench cycle-count assumptions failing because instructions no longer complete in one cycle.
- Debug LED behaviour changing because the visible state advances by instruction phases rather than one full instruction per old CPU enable.
- FPGA resource usage increasing due to additional internal registers and FSM control.

## Phase 8A Acceptance Criteria

Phase 8A is complete when:

- This planning document exists.
- The Phase 7D timing problem is summarised clearly.
- The proposed multi-cycle FSM states are defined.
- Instruction-by-instruction state sequences are documented.
- Compatibility requirements are listed.
- Verification and FPGA comparison plans are documented.
- No RTL, testbench, program file or instruction encoding is changed.

## Suggested Later Subphases

### Phase 8B: Skeleton

- Create a separate multi-cycle CPU module or branch of the core.
- Add FSM state register and instruction register.
- Fetch and decode NOP safely.
- Add a minimal self-checking FSM/reset testbench.

### Phase 8C: Arithmetic

- Implement ADD, SUB, AND, OR, XOR and ADDI.
- Verify final register results against Phase 6A arithmetic expectations.
- Confirm `x0` write protection still works.

### Phase 8D: Memory

- Implement LOAD and STORE over `EXECUTE`, `MEMORY` and `WRITEBACK`.
- Verify base-plus-offset memory programs against Phase 6B.
- Check data memory timing carefully.

### Phase 8E: Control Flow

- Implement BEQ and JUMP.
- Verify branch taken, branch not taken, jump and simple loop programs against Phase 6C, Phase 6D and Phase 6E.
- Pay special attention to branch/jump PC target calculation.

### Phase 8F: Full Verification

- Run the complete reused Phase 6 program suite on the multi-cycle CPU.
- Add focused FSM transition tests.
- Save transcripts and waveform evidence.
- Update verification documentation with pass/fail results.

### Phase 8G: Synthesis And Timing Comparison

- Synthesize and implement the multi-cycle design for the Basys 3.
- Compare against the Phase 7 baseline.
- Document resource usage, timing, worst path and estimated maximum frequency.
- Decide whether the multi-cycle design is the preferred FPGA implementation path.
