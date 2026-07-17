# CPU Architecture

This CPU is a simple educational 32-bit soft-core written in SystemVerilog. It is currently a single-cycle-style design: for each instruction, the core fetches the instruction, decodes it, reads registers, performs the ALU or memory operation, selects writeback data, and chooses the next PC through one straightforward combinational datapath around synchronous state elements.

The design is intentionally small. It is meant to make the CPU datapath easy to understand before adding more advanced features such as pipelining, hazards, interrupts, caches, or a bus interface.

For the final measured FPGA result and the later pipeline variants, see `reports/final_project_summary.md` and `docs/performance_results.md`.

## Main Blocks

The CPU core is built from these RTL modules:

- `program_counter`: stores the current instruction address.
- `instruction_memory`: stores 32-bit instruction words and supports optional `$readmemh` loading.
- `fetch_unit`: combines the program counter and instruction memory.
- `instruction_decoder`: splits a 32-bit instruction into opcode, register fields, and sign-extended immediate.
- `control_unit`: turns the opcode into datapath control signals.
- `register_file`: stores 32 general-purpose 32-bit registers.
- `alu`: performs ADD, SUB, AND, OR, and XOR.
- `data_memory`: stores 32-bit data words for LOAD and STORE.
- `cpu_core`: wires the blocks together into the current integrated processor.

## Fetch

The fetch stage uses the current `pc` value as a byte address into instruction memory. Instruction memory uses `addr[31:2]` as the word address, so byte addresses `0`, `4`, `8`, and `12` access instruction words `0`, `1`, `2`, and `3`.

The CPU core calculates `next_pc` and passes it into the fetch unit. For normal sequential execution:

```text
next_pc = pc + 4
```

For a taken branch or jump, `next_pc` becomes the PC-relative target.

## Decode

The instruction decoder breaks the 32-bit instruction into fields:

```text
instruction[31:28] = opcode
instruction[27:23] = rd
instruction[22:18] = rs1
instruction[17:13] = rs2
instruction[12:0]  = imm13
```

It also sign-extends `imm13` to 32 bits as `imm_ext`. This lets ADDI, LOAD, STORE, BEQ, and JUMP use positive and negative immediate values.

## Control

The control unit reads the opcode and produces simple control signals:

- `reg_write`: enables register writeback.
- `use_imm`: selects `imm_ext` as ALU input B.
- `alu_op`: selects the ALU operation.
- `valid_instr`: marks recognised opcodes.
- `mem_read`: enables LOAD data memory reads.
- `mem_write`: enables STORE data memory writes.
- `mem_to_reg`: selects memory read data for writeback.
- `branch`: marks BEQ.
- `jump`: marks JUMP.

Invalid opcodes are safe: they do not write registers or memory and do not branch or jump.

## Register Read

The register file has two read ports. The CPU connects:

- `rs1` to read port A.
- `rs2` to read port B.
- `rd` to the write address.

Register `x0` is hardwired to zero. Writes to `x0` are ignored inside the register file.

## ALU Execution

ALU input A always comes from register read port A:

```text
alu_a = rdata_a
```

ALU input B is selected by `use_imm`:

```text
alu_b = use_imm ? imm_ext : rdata_b
```

For ADD, SUB, AND, OR, and XOR, the ALU result is the value written back to `rd`. For ADDI, LOAD, and STORE, the ALU uses ADD. In LOAD and STORE, the ALU result is the data memory byte address.

## Memory Access

Data memory is word-addressed using `addr[31:2]`, matching instruction memory. The ALU result drives the data memory address.

LOAD:

```text
address = rs1 + imm_ext
rd = data_memory[address]
```

STORE:

```text
address = rs1 + imm_ext
data_memory[address] = rs2
```

Data memory writes are synchronous. Data memory reads are combinational and enabled by `mem_read`.

## Writeback

The CPU has one register writeback path. The writeback data is selected by `mem_to_reg`:

```text
writeback_data = mem_to_reg ? data_mem_read_data : alu_result
```

The register file write enable remains protected by instruction validity:

```text
reg_file_we = reg_write && valid_instr
```

This prevents invalid opcodes from updating the register file.

## Branch And Jump

BEQ compares the two register operands:

```text
branch_taken = branch && valid_instr && (rdata_a == rdata_b)
```

BEQ and JUMP use the same target calculation:

```text
pc_target = pc + (imm_ext << 2)
```

The immediate is shifted left by two because it counts instruction words. One instruction word is 4 bytes.

The final next-PC selection is:

```text
next_pc = (branch_taken || (jump && valid_instr)) ? pc_target : pc_plus_4
```

This keeps control flow simple and visible in the waveform.

## Current Limits

The core is intentionally minimal:

- No pipeline yet.
- No hazard detection or forwarding.
- No interrupts or exceptions.
- No external bus interface yet.
- No status flags yet.
- No assembler yet; programs are currently hand-written as hex `.mem` files.

These limits are acceptable for the current phase because the main goal is to build and verify the datapath one piece at a time.
