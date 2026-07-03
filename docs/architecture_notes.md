# Architecture Notes

## Current Architecture Status

The architecture is still in the early module-building phase. The completed RTL blocks are the ALU, register file, program counter, instruction memory and fetch unit.

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
- Load/store support if data memory is added early.
- A control unit or decoder that drives the datapath.

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

## Open Architecture Decisions

- Instruction width.
- Instruction encoding.
- Memory map.
- Single-cycle versus multi-cycle CPU structure.
- Whether status flags are needed.
- Target FPGA board and clock frequency target.
