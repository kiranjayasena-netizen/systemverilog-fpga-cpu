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

## Phase 6B Test: Memory Offset Program

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

## Phase 6C Test: Branch Taken/Not-Taken Program

File: `programs/branch_taken_not_taken_test.mem`

Status: added and passed in Vivado XSim.

The Phase 6C program focuses on BEQ control-flow behaviour:

```text
ADDI x1, x0, 5        ; x1 = 5
ADDI x2, x0, 5        ; x2 = 5
BEQ  x1, x2, +2       ; taken, skips the next instruction
ADDI x3, x0, 99       ; skipped
ADDI x3, x0, 42       ; x3 = 42
ADDI x4, x0, 1        ; x4 = 1
ADDI x5, x0, 2        ; x5 = 2
BEQ  x4, x5, +2       ; not taken
ADDI x6, x0, 77       ; x6 = 77
ADDI x7, x0, 88       ; x7 = 88
NOP
```

Encoded program words:

```text
60800005
61000005
90044002
61800063
6180002A
62000001
62800002
9010A002
6300004D
63800058
00000000
```

Expected final state:

- `x0 = 32'd0`
- `x1 = 32'd5`
- `x2 = 32'd5`
- `x3 = 32'd42`
- `x4 = 32'd1`
- `x5 = 32'd2`
- `x6 = 32'd77`
- `x7 = 32'd88`
- `x3 != 32'd99`

Testbench: `tb/tb_phase6_branch_control.sv`

The testbench instantiates `cpu_top` with:

```systemverilog
.PROGRAM_FILE("programs/branch_taken_not_taken_test.mem")
```

It resets the CPU, runs the program, checks the final register values, explicitly checks that the skipped `x3 = 99` write did not remain, generates `tb_phase6_branch_control.vcd`, and calls `$fatal` if any check fails.

## Phase 6D Test: Jump Control Program

File: `programs/jump_test.mem`

Status: added and passed in Vivado XSim.

The Phase 6D program focuses on unconditional JUMP control-flow behaviour:

```text
ADDI x1, x0, 11       ; x1 = 11
JUMP +2               ; skips the next instruction
ADDI x2, x0, 99       ; skipped
ADDI x2, x0, 22       ; x2 = 22
ADDI x3, x0, 33       ; x3 = 33
JUMP +2               ; skips the next instruction
ADDI x4, x0, 99       ; skipped
ADDI x4, x0, 44       ; x4 = 44
NOP
```

Encoded program words:

```text
6080000B
A0000002
61000063
61000016
61800021
A0000002
62000063
6200002C
00000000
```

Expected final state:

- `x0 = 32'd0`
- `x1 = 32'd11`
- `x2 = 32'd22`
- `x3 = 32'd33`
- `x4 = 32'd44`
- `x2 != 32'd99`
- `x4 != 32'd99`

Testbench: `tb/tb_phase6_jump_control.sv`

The testbench instantiates `cpu_top` with:

```systemverilog
.PROGRAM_FILE("programs/jump_test.mem")
```

It resets the CPU, runs the program, checks the final register values, explicitly checks that the skipped `x2 = 99` and `x4 = 99` writes did not remain, generates `tb_phase6_jump_control.vcd`, and calls `$fatal` if any check fails.

## Phase 6E Test: Simple Loop Program

File: `programs/simple_loop_test.mem`

Status: added and passed in Vivado XSim.

The Phase 6E program verifies a small loop using ADDI, ADD, SUB, BEQ, JUMP, STORE and NOP:

```text
ADDI x1, x0, 0        ; accumulator x1 = 0
ADDI x2, x0, 3        ; loop counter x2 = 3
ADDI x3, x0, 1        ; loop step x3 = 1
ADD  x1, x1, x3       ; x1 = x1 + 1
SUB  x2, x2, x3       ; x2 = x2 - 1
BEQ  x2, x0, +2       ; exit when x2 == 0
JUMP -3               ; return to ADD instruction
STORE x1, [x0 + 0]    ; data memory word 0 = 3
NOP
```

Encoded program words:

```text
60800000
61000003
61800001
10846000
21086000
90080002
A0001FFD
80002000
00000000
```

Offset notes:

- The BEQ at word 5 uses `+2`, so when `x2 == 0` the PC targets word 7 and skips the loop-back JUMP.
- The JUMP at word 6 uses `13'h1ffd`, which sign-extends to `-3`, so the PC returns to word 3.

Expected final state:

- `x0 = 32'd0`
- `x1 = 32'd3`
- `x2 = 32'd0`
- `x3 = 32'd1`
- `data_mem_inst.mem[0] = 32'd3`

Testbench: `tb/tb_phase6_simple_loop.sv`

The testbench instantiates `cpu_top` with:

```systemverilog
.PROGRAM_FILE("programs/simple_loop_test.mem")
```

It resets the CPU, runs with a fixed maximum cycle count so a bad loop cannot hang simulation, checks the final register and data memory values, generates `tb_phase6_simple_loop.vcd`, and calls `$fatal` if any check fails.

## Phase 6F Test: Invalid Opcode Safety Program

File: `programs/invalid_opcode_test.mem`

Status: added and passed in Vivado XSim.

The Phase 6F program verifies that invalid opcodes are safely ignored at program level. Valid instructions before and after the invalid instructions must still execute:

```text
ADDI    x1, x0, 10       ; valid setup before invalid opcode
INVALID opcode 0xb       ; attempts to target x10
ADDI    x2, x0, 20       ; valid instruction after invalid opcode
INVALID opcode 0xf       ; attempts to target x11
STORE   x2, [x0 + 0]     ; data memory word 0 = 20
INVALID opcode 0xb       ; attempts to target x12
NOP
```

Encoded program words:

```text
6080000A
B5002000
61000014
F5844000
80004000
B6004004
00000000
```

Expected final state:

- `x0 = 32'd0`
- `x1 = 32'd10`
- `x2 = 32'd20`
- `x10 = 32'd0`
- `x11 = 32'd0`
- `x12 = 32'd0`
- `data_mem_inst.mem[0] = 32'd20`
- `data_mem_inst.mem[1] = 32'd0`
- `data_mem_inst.mem[5] = 32'd0`

Testbench: `tb/tb_phase6_invalid_opcode.sv`

The testbench instantiates `cpu_top` with:

```systemverilog
.PROGRAM_FILE("programs/invalid_opcode_test.mem")
```

It resets the CPU, runs the file-loaded program, checks that invalid opcodes do not write their target registers or corrupt checked data memory words, generates `tb_phase6_invalid_opcode.vcd`, and calls `$fatal` if any check fails.
