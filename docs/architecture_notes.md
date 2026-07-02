# Architecture Notes

## Current Architecture Status

The architecture is still in the early module-building phase. The completed RTL blocks are the ALU, register file and program counter.

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

## Open Architecture Decisions

- Instruction width.
- Data width.
- Instruction encoding.
- Memory map.
- Single-cycle versus multi-cycle CPU structure.
- Whether status flags are needed.
- Target FPGA board and clock frequency target.
