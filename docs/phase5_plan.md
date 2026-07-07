# Phase 5 Plan: Memory System And Program Execution

## Goal

Phase 5 turns the integrated CPU design into a small runnable processor system in simulation. The target demonstration is a multi-instruction program that performs `5 + 7` and stores the result, `12`, into data memory word 0.

The project uses its existing custom instruction encoding, not RISC-V machine code.

## Instruction Memory

File: `rtl/instr_mem.sv`

The Phase 5 instruction memory is a simple 256-word, 32-bit-wide memory. It accepts a 32-bit byte address and uses `addr[9:2]` as the word index. This means byte addresses `0`, `4`, `8` and `12` select instruction words `0`, `1`, `2` and `3`.

The memory initialises to zero and uses `$readmemh` when an `INIT_FILE` parameter is provided. Out-of-range addresses return `32'h0000_0000`, which is also the custom `NOP` instruction.

## Data Memory

File: `rtl/data_mem.sv`

The Phase 5 data memory is a 256-word, 32-bit-wide memory with:

- 32-bit byte address input.
- 32-bit write data input.
- 32-bit read data output.
- Synchronous writes on the rising clock edge.
- Combinational reads when `mem_read` is high.
- Separate `mem_read` and `mem_write` control signals.

The memory clears to zero on reset. Out-of-range reads return zero and out-of-range writes are ignored.

## CPU Top-Level System

File: `rtl/cpu_top.sv`

The current `cpu_core` already integrates instruction fetch, instruction memory and data memory through the existing `fetch_unit` and `data_memory` path. To avoid a larger, unnecessary CPU interface rewrite, `cpu_top` wraps the existing integrated core and passes in a program file through the `IMEM_INIT_FILE` parameter.

This keeps the CPU core behaviour stable while providing a clean top-level module for Phase 5 program execution simulations.

## Test Program

File: `programs/add_test.mem`

The program uses the existing custom instruction format:

```text
instruction[31:28] = opcode
instruction[27:23] = rd
instruction[22:18] = rs1
instruction[17:13] = rs2
instruction[12:0]  = imm13
```

Program sequence:

| Address | Word | Meaning |
| --- | --- | --- |
| `0x00000000` | `60800005` | `ADDI x1, x0, 5` |
| `0x00000004` | `61000007` | `ADDI x2, x0, 7` |
| `0x00000008` | `11844000` | `ADD x3, x1, x2` |
| `0x0000000c` | `80006000` | `STORE x3, [x0 + 0]` |
| `0x00000010` | `00000000` | `NOP` |

Expected final state:

- `x1 = 5`
- `x2 = 7`
- `x3 = 12`
- data memory word 0 = `12`

## Testbenches

Phase 5 adds:

- `tb/tb_instr_mem.sv`: checks `$readmemh` program loading, byte-to-word addressing, unaligned addressing and out-of-range reads.
- `tb/tb_data_mem.sv`: checks reset, synchronous writes, combinational reads, read disable, unaligned addresses and out-of-range protection.
- `tb/tb_program_execution.sv`: runs the full program through `cpu_top` and checks the final register and data memory values.

## Pass/Fail Criteria

The Phase 5 program execution test passes when:

- The program runs for enough cycles to execute all five words.
- `x1`, `x2` and `x3` contain `5`, `7` and `12`.
- data memory word 0 contains `32'd12`.
- The testbench prints `PHASE 5 PROGRAM EXECUTION TEST PASSED`.
- No `$fatal` is triggered.

The test fails if any expected register or memory value is incorrect.

