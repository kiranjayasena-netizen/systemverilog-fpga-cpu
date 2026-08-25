# Instruction Set Architecture

This project uses a small custom 32-bit instruction format. The goal is to keep the instruction set easy to inspect in simulation while the CPU datapath is being built up from simple verified RTL blocks.

The final project summary and performance comparison are recorded in `reports/final_project_summary.md` and `docs/performance_results.md`; the instruction encodings below remain unchanged throughout the CPU variants.

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
| `4'hb` | MAC8 | Phase 12 core only: `rd = rd + signed8(rs1[7:0]) * signed8(rs2[7:0])` |
| `4'hc` | DOT4ACC | Stage D experimental core only: four packed signed-INT8 products accumulated into `rd` |

Opcodes `4'hd` through `4'hf` remain unassigned and invalid. Opcode `4'hc` is
executable only in `cpu_core_pipeline_dot4acc_wb`; every historical CPU core
still treats it as invalid and side-effect free. The Stage C
`cpu_core_pipeline_dot4acc_issue` core observes arithmetic completions but has
no architectural DOT writeback or retirement. Historical cores that do not implement the
Phase 12 AI extension also continue to treat `4'hb` as invalid; this prevents
them from silently executing unsupported AI instructions.

## MAC8 Encoding And Arithmetic

Canonical assembly syntax:

```text
MAC8 rd, rs1, rs2
```

Encoding:

| Bits | MAC8 meaning |
| --- | --- |
| `[31:28]` | `4'hb` |
| `[27:23]` | `rd`, both the accumulator source and destination |
| `[22:18]` | `rs1`, low byte is signed INT8 multiplicand A |
| `[17:13]` | `rs2`, low byte is signed INT8 multiplicand B |
| `[12:0]` | Reserved; canonical encoding is zero and hardware ignores it |

Arithmetic is precisely:

```text
a       = signed(rs1[7:0])                 // range -128 to +127
b       = signed(rs2[7:0])                 // range -128 to +127
product = signed16(a * b)                  // full, untruncated 16-bit product
result  = (rd_old + sign_extend(product)) mod 2^32
rd      = result
```

The upper 24 bits of each source register are ignored. The accumulator is the
full 32-bit old value of `rd`. There is no saturation, exception or overflow
flag; two's-complement overflow wraps modulo `2^32`, matching ADD/SUB behavior.
If `rd` is `x0`, its accumulator value is zero and the final write is ignored.

Example (`x3` initially contains 10):

```text
ADDI x1, x0, -3
ADDI x2, x0,  4
MAC8 x3, x1, x2       // x3 = 10 + (-3 * 4) = -2
```

## Experimental DOT4ACC Encoding And Arithmetic

`DOT4ACC rd, rs1, rs2` is architecturally executable only in the Stage D
experimental core `cpu_core_pipeline_dot4acc_wb`.

| Bits | DOT4ACC meaning |
| --- | --- |
| `[31:28]` | `4'hc` (`OP_DOT4ACC`) |
| `[27:23]` | `rd`, accumulator source and destination |
| `[22:18]` | `rs1`, packed signed INT8 source A |
| `[17:13]` | `rs2`, packed signed INT8 source B |
| `[12:0]` | reserved; canonical encoding must be zero |

The Stage A1 encoder always writes zero to `[12:0]`, and its reference checker
flags nonzero reserved bits as non-canonical. The Stage D core rejects a
non-canonical instruction with any nonzero reserved bit.

Arithmetic is precisely:

```text
dot = signed(rs1[7:0])   * signed(rs2[7:0])
    + signed(rs1[15:8])  * signed(rs2[15:8])
    + signed(rs1[23:16]) * signed(rs2[23:16])
    + signed(rs1[31:24]) * signed(rs2[31:24])
rd  = (rd_old + sign_extend(dot)) mod 2^32
```

The implementation uses signed 8-bit lanes, full signed 16-bit products,
signed 17-bit pair sums, a signed 18-bit dot sum, and explicit signed 32-bit
accumulation. There is no saturation or overflow flag. `DOT4ACC x0,...`
retires normally in the Stage D core but its register write is suppressed, so
`x0` remains zero. These semantics do not imply support in any historical CPU
variant.

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
