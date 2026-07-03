# Architecture Notes

## Current Architecture Status

The architecture is still in the early module-building phase. The completed RTL blocks are the ALU, register file, program counter, instruction memory, data memory, fetch unit, instruction decoder, control unit and first simple CPU core.

## ALU

File: `rtl/alu.sv`

The ALU is a parameterised combinational block with two operands, a 3-bit opcode and one result. Its `WIDTH` parameter defaults to 32 bits, matching the register file and the current CPU datapath width.

Interface summary:

- `WIDTH`: data width parameter, defaulting to 32.
- `a`: `WIDTH`-bit operand A.
- `b`: `WIDTH`-bit operand B.
- `op`: 3-bit operation select.
- `y`: `WIDTH`-bit result.

| Opcode | Operation |
| --- | --- |
| `3'b000` | ADD |
| `3'b001` | SUB |
| `3'b010` | AND |
| `3'b011` | OR |
| `3'b100` | XOR |
| Other | `'0` default result |

The ALU currently does not expose flags such as carry, zero, negative or overflow. These can be added later if the CPU instruction set needs them.

## Planned CPU Direction

The first integrated CPU should stay simple. A likely starting point is a single-cycle or simple multi-cycle design with:

- A small register file.
- A program counter.
- Instruction memory.
- Basic arithmetic and logic instructions.
- Standalone data memory and initial LOAD/STORE support.
- Existing decoder and control unit blocks that start to drive the datapath.

## Register File

File: `rtl/register_file.sv`

The register file is a 32-register, 32-bit storage block intended to provide operands to the ALU and accept writeback data from the CPU datapath.

Interface summary:

- `clk`: clock input.
- `rst`: active-high reset.
- `we`: write enable.
- `waddr`: 5-bit write address.
- `wdata`: 32-bit write data.
- `raddr_a`: 5-bit read address for read port A.
- `raddr_b`: 5-bit read address for read port B.
- `rdata_a`: 32-bit read data from read port A.
- `rdata_b`: 32-bit read data from read port B.

Behaviour:

- 32 registers, addressed from `x0` to `x31`.
- 32-bit data width.
- Two asynchronous read ports.
- One synchronous write port.
- Register `x0` is hardwired to zero.
- Writes to `x0` are ignored.
- Reset clears the stored registers.

This interface matches a simple CPU datapath where two source registers can be read at the same time and one destination register can be written back on a clock edge.

## Program Counter

File: `rtl/program_counter.sv`

The program counter stores the address of the current instruction. It is a 32-bit synchronous state register with reset and enable control.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset.
- `enable`: allows the PC to update when high.
- `next_pc`: 32-bit next PC value.
- `pc`: 32-bit current PC output.

Behaviour:

- `RESET_ADDR` parameter defaults to `32'h0000_0000`.
- On a rising clock edge, if `rst` is high, `pc` is loaded with `RESET_ADDR`.
- Else if `enable` is high, `pc` is loaded with `next_pc`.
- Else the current `pc` value is held.

The PC does not calculate branch or increment addresses internally. The surrounding datapath/control logic will provide `next_pc`, allowing the same interface to support sequential execution, branches and jumps later.

## Instruction Memory

File: `rtl/instruction_memory.sv`

The instruction memory is a simple combinational-read ROM-style block for fetching 32-bit instructions from byte addresses.

Interface summary:

- `addr`: 32-bit byte address input.
- `instruction`: 32-bit instruction output.
- `DEPTH`: parameter for the number of 32-bit instruction words, defaulting to 256.
- `INIT_FILE`: optional hex file path used with `$readmemh`, defaulting to an empty string.

Behaviour:

- Internally stores instructions as `logic [31:0] mem [0:DEPTH-1]`.
- All instruction words initialise to `32'h0000_0000`.
- If `INIT_FILE` is not empty, memory contents are loaded with `$readmemh`.
- Uses `addr[31:2]` as the word address, so byte addresses `0`, `4`, `8` and `12` map to words `0`, `1`, `2` and `3`.
- Reads are combinational.
- Out-of-range addresses return `32'h0000_0000`.

This block connects naturally to the program counter output. The program counter supplies a byte address, and the instruction memory returns the 32-bit instruction at that word-aligned location.

## Data Memory

File: `rtl/data_memory.sv`

The data memory is a standalone 32-bit word memory block intended for future load/store support. It is not connected to the CPU core yet.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset.
- `mem_read`: enables combinational read data output.
- `mem_write`: enables synchronous write on the rising clock edge.
- `addr`: 32-bit byte address input.
- `write_data`: 32-bit write data input.
- `read_data`: 32-bit read data output.
- `DEPTH`: parameter for the number of 32-bit memory words, defaulting to 256.

Behaviour:

- Internally stores words as `logic [31:0] mem [0:DEPTH-1]`.
- Uses `addr[31:2]` as the word address, matching the instruction memory address convention.
- On reset, all memory words are cleared to `32'h0000_0000`.
- Writes are synchronous and only occur when `mem_write` is high and the word address is in range.
- Reads are combinational and return the selected word only when `mem_read` is high and the word address is in range.
- Disabled reads and out-of-range reads return `32'h0000_0000`.
- Out-of-range writes are ignored.

## Fetch Unit

File: `rtl/fetch_unit.sv`

The fetch unit integrates the existing program counter and instruction memory into a simple instruction-fetch stage.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset passed to the program counter.
- `enable`: allows the program counter to advance when high.
- `pc`: 32-bit current program counter output.
- `instruction`: 32-bit instruction fetched from instruction memory.

Behaviour:

- Internally creates `next_pc`.
- Computes `next_pc = pc + 32'd4`.
- Instantiates `program_counter` with `RESET_ADDR = 32'h0000_0000`.
- Instantiates `instruction_memory`.
- Connects `pc` directly to the instruction memory `addr` input.
- When enabled, the fetch stage advances by one 32-bit instruction word per clock.
- When disabled, the PC and fetched instruction hold their current values.

This is the first integrated datapath block in the project. It proves that the program counter and instruction memory interfaces work together before adding decode and execution logic.

## Instruction Decoder

File: `rtl/instruction_decoder.sv`

The instruction decoder is a purely combinational block that splits a 32-bit instruction into opcode, register index and immediate fields. The decoded opcode feeds the control unit.

Instruction format:

| Bits | Field | Description |
| --- | --- | --- |
| `[31:28]` | `opcode` | 4-bit operation code |
| `[27:23]` | `rd` | 5-bit destination register index |
| `[22:18]` | `rs1` | 5-bit source register 1 index |
| `[17:13]` | `rs2` | 5-bit source register 2 index |
| `[12:0]` | `imm13` | 13-bit immediate field |

Interface summary:

- `instruction`: 32-bit instruction input.
- `opcode`: decoded 4-bit opcode.
- `rd`: decoded 5-bit destination register.
- `rs1`: decoded 5-bit source register 1.
- `rs2`: decoded 5-bit source register 2.
- `imm13`: raw 13-bit immediate.
- `imm_ext`: `imm13` sign-extended to 32 bits.

Initial opcode map:

| Opcode | Operation |
| --- | --- |
| `4'h0` | NOP |
| `4'h1` | ADD |
| `4'h2` | SUB |
| `4'h3` | AND |
| `4'h4` | OR |
| `4'h5` | XOR |
| `4'h6` | ADDI |
| `4'h7` | LOAD |
| `4'h8` | STORE |

This decoder format keeps the fetched 32-bit instruction aligned with the 32-bit datapath and the 32-register register file. The signed immediate path supports immediate arithmetic such as ADDI and base-plus-offset addressing for LOAD and STORE.

## Control Unit

File: `rtl/control_unit.sv`

The control unit is a purely combinational block that maps the decoded 4-bit instruction opcode to datapath control signals. It does not handle branches or status flags yet.

Interface summary:

- `opcode`: 4-bit instruction opcode from the instruction decoder.
- `reg_write`: enables register file writeback.
- `use_imm`: selects the sign-extended immediate as the second ALU operand instead of `rs2` data.
- `alu_op`: 3-bit ALU operation code.
- `valid_instr`: marks recognised instruction opcodes.
- `mem_read`: enables data memory read for LOAD.
- `mem_write`: enables data memory write for STORE.
- `mem_to_reg`: selects data memory read data for register writeback.

Control signal table:

| Instruction | Opcode | `reg_write` | `use_imm` | `alu_op` | `mem_read` | `mem_write` | `mem_to_reg` | `valid_instr` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NOP | `4'h0` | `0` | `0` | `3'b000` ADD | `0` | `0` | `0` | `1` |
| ADD | `4'h1` | `1` | `0` | `3'b000` ADD | `0` | `0` | `0` | `1` |
| SUB | `4'h2` | `1` | `0` | `3'b001` SUB | `0` | `0` | `0` | `1` |
| AND | `4'h3` | `1` | `0` | `3'b010` AND | `0` | `0` | `0` | `1` |
| OR | `4'h4` | `1` | `0` | `3'b011` OR | `0` | `0` | `0` | `1` |
| XOR | `4'h5` | `1` | `0` | `3'b100` XOR | `0` | `0` | `0` | `1` |
| ADDI | `4'h6` | `1` | `1` | `3'b000` ADD | `0` | `0` | `0` | `1` |
| LOAD | `4'h7` | `1` | `1` | `3'b000` ADD | `1` | `0` | `1` | `1` |
| STORE | `4'h8` | `0` | `1` | `3'b000` ADD | `0` | `1` | `0` | `1` |
| Invalid | Other | `0` | `0` | `3'b000` ADD | `0` | `0` | `0` | `0` |

The default control outputs are safe for invalid instructions: register writeback and memory access are disabled, immediate selection is disabled, the ALU operation defaults to ADD and `valid_instr` is low.

## CPU Core

File: `rtl/cpu_core.sv`

The CPU core is the first integrated datapath. It connects the fetch unit, instruction decoder, control unit, register file, 32-bit ALU and data memory into a simple single-cycle execution path.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset passed to the fetch unit and register file.
- `enable`: enables instruction fetch and PC advance.
- `pc`: current 32-bit program counter debug output.
- `instruction`: fetched 32-bit instruction debug output.
- `opcode`, `rd`, `rs1`, `rs2`, `imm_ext`: decoded instruction debug outputs.
- `reg_write`, `use_imm`, `alu_op`, `valid_instr`: control debug outputs.
- `alu_result`: 32-bit ALU result debug output.

Datapath behaviour:

- `fetch_unit` supplies `pc` and `instruction`.
- `instruction_decoder` extracts opcode, register fields and sign-extended immediate.
- `control_unit` maps opcode to register write, immediate select, ALU operation and valid-instruction control signals.
- `register_file` reads `rs1` and `rs2`.
- ALU input A is register file read port A.
- ALU input B is either register file read port B or `imm_ext`, selected by `use_imm`.
- The ALU result is used directly for arithmetic/logical writeback and as the data memory address for LOAD and STORE.
- `data_memory` reads or writes using the ALU result address.
- STORE writes register file read port B data to data memory.
- LOAD selects data memory read data for register writeback through `mem_to_reg`.
- Non-memory ALU instructions select the ALU result for register writeback.
- Register file write enable is `reg_write && valid_instr`.

This first core supports NOP, ADD, SUB, AND, OR, XOR, ADDI, LOAD and STORE using the existing instruction format. Invalid opcodes are blocked from register and memory writeback by `valid_instr`, and writes to `x0` remain blocked inside the register file. The core does not include branching, hazards, stalls or pipelining yet.

## Open Architecture Decisions

- Memory map.
- Single-cycle versus multi-cycle CPU structure.
- Whether status flags are needed.
- Target FPGA board and clock frequency target.
