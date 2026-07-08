# Phase 6 Plan: Expanded ISA Verification And Program Test Suite

## Goal

Phase 6 expands verification beyond the Phase 5 single program execution test. The aim is to build a suite of small file-loaded custom-ISA programs that exercise different instruction behaviours through the same program-loading path used by `cpu_top`.

The CPU uses the project custom instruction format, not RISC-V. Phase 6 must not change instruction encodings or CPU behaviour unless a real bug is found.

## Planned Program Coverage

The wider Phase 6 suite should cover:

- Arithmetic edge cases.
- Negative immediates and `imm13` sign extension.
- Register `x0` write protection.
- LOAD and STORE offset behaviour.
- BEQ taken behaviour.
- BEQ not-taken behaviour.
- JUMP behaviour.
- Simple loop execution.
- Invalid opcode protection.

Each program should be small, readable and self-checking through a matching testbench. Program files should live in `programs/`, and testbenches should live in `tb/`.

## First Phase 6 Test: Arithmetic Edge Program

File: `programs/arithmetic_edge_test.mem`

The first Phase 6 program focuses on arithmetic behaviour and register-file edge cases:

```text
ADDI x1, x0, 10       ; x1 = 10
ADDI x2, x0, 20       ; x2 = 20
ADD  x3, x1, x2       ; x3 = 30
SUB  x4, x2, x1       ; x4 = 10
ADDI x5, x0, -1       ; x5 = 32'hFFFF_FFFF
ADD  x6, x5, x1       ; x6 = 9
SUB  x7, x0, x1       ; x7 = 32'hFFFF_FFF6
ADDI x0, x0, 123      ; x0 remains 0
ADD  x8, x0, x3       ; x8 = 30, proving x0 still reads as zero
NOP
```

Expected final state:

- `x0 = 32'h0000_0000`
- `x1 = 32'd10`
- `x2 = 32'd20`
- `x3 = 32'd30`
- `x4 = 32'd10`
- `x5 = 32'hFFFF_FFFF`
- `x6 = 32'd9`
- `x7 = 32'hFFFF_FFF6`
- `x8 = 32'd30`

## Testbench

File: `tb/tb_phase6_arithmetic_edge.sv`

The testbench instantiates `cpu_top` with:

```systemverilog
.PROGRAM_FILE("programs/arithmetic_edge_test.mem")
```

It resets the CPU, enables execution for enough cycles to run the program, checks the final register values through the existing testbench-visible hierarchy, and calls `$fatal` if any check fails.

## Pass/Fail Criteria

The arithmetic edge test passes when:

- The program loads from `programs/arithmetic_edge_test.mem`.
- The CPU executes the program without simulator errors.
- All expected register values match.
- `x0` remains zero after an attempted write.
- The testbench prints `PHASE 6 ARITHMETIC EDGE TEST PASSED`.

The test fails if any expected register value is wrong or if `$fatal` is reached.

## Second Phase 6 Test: Memory Offset Program

File: `programs/memory_offset_test.mem`

Status: added and passed in Vivado XSim.

The second Phase 6 program focuses on LOAD/STORE base-plus-offset addressing:

```text
ADDI  x1, x0, 64       ; x1 = 64, base byte address
ADDI  x2, x0, 123      ; x2 = 123, store data
STORE x2, [x1 + 0]     ; data memory word 16 = 123
LOAD  x3, [x1 + 0]     ; x3 = 123
STORE x3, [x1 + 4]     ; data memory word 17 = 123
LOAD  x4, [x1 + 4]     ; x4 = 123
ADDI  x5, x0, 68       ; x5 = 68
LOAD  x6, [x5 - 4]     ; x6 = 123 from byte address 64
NOP
```

Encoded program words:

```text
60800040
6100007B
80044000
71840000
80046004
72040004
62800044
73141FFC
00000000
```

Expected final state:

- `x1 = 32'd64`
- `x2 = 32'd123`
- `x3 = 32'd123`
- `x4 = 32'd123`
- `x5 = 32'd68`
- `x6 = 32'd123`
- `data_mem_inst.mem[16] = 32'd123`
- `data_mem_inst.mem[17] = 32'd123`

Testbench: `tb/tb_phase6_memory_offset.sv`

The testbench instantiates `cpu_top` with:

```systemverilog
.PROGRAM_FILE("programs/memory_offset_test.mem")
```

It resets the CPU, runs the nine-instruction program, checks the final register and memory values, generates `tb_phase6_memory_offset.vcd`, and calls `$fatal` if any check fails.
