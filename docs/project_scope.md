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

The project is currently at the Week 1 baseline:

- Repository structure has been created.
- Vivado 2026.1 with Vivado Basic is available.
- `rtl/alu.sv` implements the first combinational ALU module.
- `tb/alu_tb.sv` verifies ADD, SUB, AND, OR, XOR and invalid/default opcode behaviour.
- ALU simulation has passed in Vivado XSim.
- A waveform has been generated and viewed.

## Planned CPU Building Blocks

- ALU
- Register file
- Program counter
- Instruction memory or ROM
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
