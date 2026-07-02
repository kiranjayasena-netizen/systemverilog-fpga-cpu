# Architecture Notes

## Current Architecture Status

The architecture is still in the early module-building phase. The only completed RTL block is the ALU.

## ALU

File: `rtl/alu.sv`

The ALU is an 8-bit combinational block with two operands, a 3-bit opcode and one 8-bit result.

| Opcode | Operation |
| --- | --- |
| `3'b000` | ADD |
| `3'b001` | SUB |
| `3'b010` | AND |
| `3'b011` | OR |
| `3'b100` | XOR |
| Other | `8'h00` default result |

The ALU currently does not expose flags such as carry, zero, negative or overflow. These can be added later if the CPU instruction set needs them.

## Planned CPU Direction

The first integrated CPU should stay simple. A likely starting point is a single-cycle or simple multi-cycle design with:

- A small register file.
- A program counter.
- Instruction memory.
- Basic arithmetic and logic instructions.
- Load/store support if data memory is added early.
- A control unit or decoder that drives the datapath.

## Register File Notes

The next module should be the register file. The interface should be agreed before implementation. Typical decisions:

- Number of registers.
- Register width.
- Number of read ports.
- Number of write ports.
- Synchronous or asynchronous reads.
- Write-enable behaviour.
- Reset behaviour.
- Whether register zero is hardwired to zero.

## Open Architecture Decisions

- Instruction width.
- Data width.
- Register count.
- Instruction encoding.
- Memory map.
- Single-cycle versus multi-cycle CPU structure.
- Whether status flags are needed.
- Target FPGA board and clock frequency target.
