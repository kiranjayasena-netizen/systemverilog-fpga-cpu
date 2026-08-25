# GPU Stage 5 — Programmable Vector Core

## Purpose

Stage 5 adds a small standalone sequencer around the verified Stage 4
instruction-controlled vector datapath. It executes straight-line programs
automatically; it is not connected to the frozen CPU.

## Architecture

```text
program load --> 16 x 16-bit combinational-read instruction memory
                               ^
                               | current_pc
                         PC / running / done
                               |
                               v
                  Stage 4 decoder + execution unit
                               |
                         vector registers
```

`vector_program_core` instantiates `vector_instruction_memory` and the
unchanged `vector_instruction_execution_unit`. Register loading and debug
readback are passed through from Stage 4.

## Instruction memory and timing

The memory contains 16 16-bit words (4-bit address). Program writes are
synchronous and use `prog_load_enable`, `prog_load_addr`, and
`prog_load_data`. Reads are combinational, selected for deterministic
single-step execution without a fetch bubble. This small memory is expected
to infer registers or distributed LUT memory rather than a BRAM-optimised
instruction store. Program writes while `running` are ignored.

## Sequencing semantics

`program_length` is 5 bits and represents 0–16 instructions. A nonzero
program executes addresses 0 through `program_length-1`; values above the
16-word memory depth complete immediately without issuing instructions.
The length is latched when a run starts, so changing the external input during
execution cannot alter the active program. `current_pc` resets
to zero, starts at zero, increments after each active step, and holds the
final instruction address after completion. Length zero completes immediately
without issuing an instruction. `start` is accepted only while idle; a start
while running is ignored. Completion sets `done=1` and `running=0`; a new
start clears `done`.

At each active clock edge, Stage 4 writes the instruction result while the
sequencer updates PC/status. Therefore the next instruction sees the prior
instruction's committed register state. Invalid stored instructions consume
one step, advance PC, and perform no writeback.

Register state priority remains `reset > vector load > instruction execution >
hold`. A vector load during execution wins over that step's writeback.

## Verification

`tb/vector_program_core_tb.sv` checks reset, program loading, zero-length and
one-instruction programs, PC progression, dependent instruction chains,
invalid instructions, restart, start-while-running, no execution after done,
load priority, ignored program writes while running, signed compare, and
arithmetic shift. Stage 1–4 regressions are rerun unchanged.

## Timing and limitations

The likely combinational path is `PC -> instruction memory -> decoder ->
register-file read -> vector ALU -> writeback`. Shifts and the four-lane ALU
remain likely timing candidates. No synthesis or frequency claim is made in
Stage 5. The core has one SIMD datapath, no branches, loops, scheduler,
pipeline, masks, memory operands, VMUL, or CPU interface.

## Next step

Choose between a VMUL/DSP extension and a vector data-memory extension after
evaluating their semantics, bandwidth, resource, and timing trade-offs.
