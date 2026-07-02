# AGENTS.md

## Project context

This is my Summer Project / Year 3 preparation project.

The project is a SystemVerilog FPGA soft-core processor project. The current goal is to build the project foundation over summer before Year 3 starts.

The final project direction is:

Design, verify and implement a simple FPGA soft-core processor, then analyse timing closure, resource usage and maximum clock frequency.

## Current setup

- Repository: systemverilog-fpga-cpu
- Main tool: Vivado 2026.1
- Licence: Vivado Basic
- Main simulator: Vivado XSim
- Optional simulators: Icarus Verilog, Verilator linting
- Language: SystemVerilog
- Current completed module: ALU

## Repository structure

- `rtl/` contains synthesizable SystemVerilog modules
- `tb/` contains testbenches
- `docs/` contains project notes and verification logs
- `constraints/` contains FPGA board constraint files
- `programs/` contains CPU test programs
- `reports/` contains timing, utilisation and power reports
- `scripts/` contains helper scripts

## Coding rules

- Keep RTL synthesizable.
- Use `always_comb` for combinational logic.
- Use `always_ff` for clocked logic.
- Use clear module and signal names.
- Do not modify generated Vivado files.
- Do not commit generated simulation outputs.
- Every RTL module should have a matching testbench.

## Verification rules

For each module:
1. Write a self-checking testbench.
2. Run simulation in Vivado.
3. Check the waveform.
4. Record the result in `docs/verification.md`.

## Current next steps

The ALU has been created and simulated successfully.

Next modules:
1. Register file
2. Memory
3. Program counter
4. Control unit
5. CPU core
6. FPGA top module

## Important instruction

Before writing code, Codex should first explain the proposed interface and test plan. Do not make large architecture changes without asking first.