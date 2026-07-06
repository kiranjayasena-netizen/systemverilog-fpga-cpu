# Instruction Set Architecture

This project uses a small custom 32-bit instruction format. The goal is to keep the instruction set easy to inspect in simulation while the CPU datapath is being built up from simple verified RTL blocks.

## Instruction Format

Every instruction is 32 bits wide.

| Bits | Field | Description |
| --- | --- | --- |
| `[31:28]` | `opcode` | 4-bit operation code |
| `[27:23]` | `rd` | 5-bit destination register |
| `[22:18]` | `rs1` | 5-bit source register 1 |
| `[17:13]` | `rs2` | 5-bit source register 2 |
| `[12:0]` | `imm13` | 13-bit immediate |

The register fields address the 32-register file, so register indexes run from `x0` to `x31`. Register `x0` is hardwired to zero by the register file.

## Opcode Map

| Opcode | Mnemonic | Behaviour |
| --- | --- | --- |
| `4'h0` | NOP | No operation |
| `4'h1` | ADD | `rd = rs1 + rs2` |
| `4'h2` | SUB | `rd = rs1 - rs2` |
| `4'h3` | AND | `rd = rs1 & rs2` |
| `4'h4` | OR | `rd = rs1 | rs2` |
| `4'h5` | XOR | `rd = rs1 ^ rs2` |
| `4'h6` | ADDI | `rd = rs1 + imm_ext` |
| `4'h7` | LOAD | `rd = data_memory[rs1 + imm_ext]` |
| `4'h8` | STORE | `data_memory[rs1 + imm_ext] = rs2` |
| `4'h9` | BEQ | Branch if `rs1 == rs2` |
| `4'ha` | JUMP | Unconditional PC-relative jump |

Invalid opcodes are marked invalid by the control unit. They do not write the register file or data memory.

## Immediate Sign Extension

The immediate field is `imm13`, a signed 13-bit value in `instruction[12:0]`. The decoder sign-extends this field to 32 bits as `imm_ext`:

```systemverilog
imm_ext = {{19{imm13[12]}}, imm13};
```

If `imm13[12]` is `0`, the value is positive. For example, `13'h0005` becomes `32'h0000_0005`.

If `imm13[12]` is `1`, the value is negative. For example, `13'h1fff` represents `-1` and becomes `32'hffff_ffff`.

## Branch And Jump Targets

BEQ and JUMP use signed PC-relative word offsets. The immediate counts instruction words, not bytes, so the CPU shifts the sign-extended immediate left by 2 bits before adding it to the current PC:

```text
pc_target = pc + (imm_ext << 2)
```

Examples:

- `imm13 = 13'd2` means jump forward by two instruction words, or 8 bytes.
- `imm13 = 13'h1fff` means jump backward by one instruction word, or 4 bytes.

BEQ takes the target only when the selected registers compare equal. JUMP always takes the target when the instruction is valid.

## Program Examples

The `programs/` directory contains hex files that can be loaded into instruction memory through `IMEM_INIT_FILE`.

### `programs/load_store_test.mem`

This program exercises the LOAD and STORE path:

```text
60800040  ADDI  x1, x0, 64
6100007B  ADDI  x2, x0, 123
80044000  STORE x2, [x1 + 0]
71840000  LOAD  x3, [x1 + 0]
62000044  ADDI  x4, x0, 68
72901FFC  LOAD  x5, [x4 - 4]
80046004  STORE x3, [x1 + 4]
73040004  LOAD  x6, [x1 + 4]
00000000  NOP
```

The matching testbench is `tb/cpu_core_program_tb.sv`.

### `programs/branch_jump_test.mem`

This program exercises taken BEQ, JUMP, and not-taken BEQ behaviour:

```text
60800005  ADDI x1, x0, 5
61000005  ADDI x2, x0, 5
90044002  BEQ  x1, x2, +2
61800063  ADDI x3, x0, 99
6180002A  ADDI x3, x0, 42
A0000002  JUMP +2
62000063  ADDI x4, x0, 99
6200004D  ADDI x4, x0, 77
00000000  NOP
62800001  ADDI x5, x0, 1
63000002  ADDI x6, x0, 2
9014C002  BEQ  x5, x6, +2
63800037  ADDI x7, x0, 55
00000000  NOP
```

The matching testbench is `tb/cpu_core_branch_program_tb.sv`.
