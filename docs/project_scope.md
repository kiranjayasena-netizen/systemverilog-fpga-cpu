# Project Scope

## Aim

Build a simple FPGA soft-core processor in SystemVerilog and use it to practise RTL design, functional verification, FPGA implementation and timing/resource analysis.

## Main Objectives

- Design the CPU from small synthesizable RTL modules.
- Verify each module with self-checking SystemVerilog testbenches.
- Integrate the modules into a complete CPU core.
- Run simulation in Vivado XSim.
- Synthesize and implement the design in Vivado.
- Analyse timing closure, resource usage and maximum clock frequency.

## Current Scope

The project has moved beyond the Week 1 baseline into early CPU building blocks:

- Repository structure has been created.
- Vivado 2026.1 with Vivado Basic is available.
- `rtl/alu.sv` implements the first combinational ALU module.
- `tb/alu_tb.sv` verifies ADD, SUB, AND, OR, XOR and invalid/default opcode behaviour.
- ALU simulation has passed in Vivado XSim.
- `rtl/register_file.sv` implements a 32-register, 32-bit register file.
- `tb/register_file_tb.sv` verifies register file reset, read, write, hold and `x0` behaviour.
- Register file simulation has passed in Vivado XSim.
- `rtl/program_counter.sv` implements a 32-bit program counter.
- `tb/program_counter_tb.sv` verifies reset, update, increment, hold and custom load behaviour.
- Program counter simulation has passed in Vivado XSim.
- `rtl/instruction_memory.sv` implements a combinational-read instruction memory.
- `tb/instruction_memory_tb.sv` verifies byte-address mapping, unaligned access behaviour, unwritten reads and out-of-range reads.
- Instruction memory simulation has passed in Vivado XSim.
- `rtl/fetch_unit.sv` integrates the program counter and instruction memory.
- `tb/fetch_unit_tb.sv` verifies reset, sequential fetch, enable hold and final reset behaviour.
- Fetch unit simulation has passed in Vivado XSim.
- Waveform images have been generated for the ALU, register file, program counter, instruction memory and fetch unit.

## Planned CPU Building Blocks

- ALU
- Register file
- Program counter
- Instruction memory or ROM
- Fetch unit
- Data memory or RAM interface
- Instruction decoder
- Control unit
- CPU core integration module
- FPGA top-level wrapper

## Analysis Deliverables

- Functional simulation results for each module.
- Waveform screenshots for important tests.
- Resource utilisation reports.
- Timing reports.
- Maximum clock frequency estimate.
- Notes on timing closure issues and design tradeoffs.

## Out of Scope for the Initial Version

- Complex pipelining.
- Caches.
- Interrupts.
- Operating system support.
- Advanced branch prediction.
- External memory controller integration unless needed later.
