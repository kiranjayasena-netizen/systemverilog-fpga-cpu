# AGENTS.md

## Project Context

This repository is a SystemVerilog FPGA CPU summer project. The goal is to build a simple soft-core processor from small verified RTL modules, implement it on an FPGA flow, and analyse timing closure, resource usage and maximum clock frequency.

The current project baseline is Week 1 setup and ALU bring-up. The ALU module and ALU testbench exist, the Vivado XSim simulation has passed, and a waveform has been generated and viewed.

## Tools

- Main FPGA tool: Vivado 2026.1
- Licence: Vivado Basic
- Main simulator: Vivado XSim
- Language: SystemVerilog
- Version control: Git and GitHub
- Development assistance: Codex CLI and ChatGPT
- Optional tools: Icarus Verilog, GTKWave and Verilator

Vivado XSim is the main simulator for now. Verilator full simulation currently has a linker issue, so do not treat Verilator as the primary regression path until that is fixed.

## Repository Structure

- `rtl/` contains synthesizable SystemVerilog modules.
- `tb/` contains self-checking testbenches.
- `docs/` contains project notes, setup notes, verification logs and planning documents.
- `docs/images/` contains documentation screenshots, including waveform screenshots.
- `constraints/` contains FPGA board constraint files.
- `programs/` contains CPU test programs.
- `reports/` contains timing, utilisation and power reports.
- `scripts/` contains helper scripts.
- `vivado/` contains Vivado project files. Generated Vivado output folders should not be edited manually or committed.

## Coding Rules

- Keep RTL synthesizable.
- Use `always_comb` for combinational logic.
- Use `always_ff` for clocked sequential logic.
- Prefer explicit widths for signals and constants.
- Use clear module, port and signal names.
- Keep module interfaces stable once testbenches and documentation depend on them.
- Do not modify `rtl/alu.sv` unless there is a real functional or synthesis issue.
- Do not modify Vivado-generated files.
- Do not commit generated simulation, synthesis or implementation outputs.
- Every RTL module should have a matching self-checking testbench.

## Verification Rules

For each module:

1. Define the expected interface and behaviour before writing the testbench.
2. Write a self-checking testbench with a reference model or explicit expected results.
3. Include directed edge cases and invalid/default cases where relevant.
4. Run simulation in Vivado XSim.
5. Generate and inspect a waveform.
6. Record the result in `docs/verification.md`.
7. Save useful waveform screenshots under `docs/images/`.

Testbenches should use `$fatal` or another non-success exit mechanism when checks fail, so failures are visible in simulator and CI logs.

## Current Next Steps

Week 1 is complete enough to move forward: repository setup, ALU RTL, ALU testbench, Vivado simulation and initial documentation are in place.

Week 2 should focus on the register file:

1. Decide the register file interface.
2. Implement `rtl/register_file.sv`.
3. Implement `tb/register_file_tb.sv`.
4. Run Vivado XSim.
5. Capture a waveform screenshot.
6. Update verification documentation.
7. Commit and push the Week 2 work.

Before large architecture changes, first explain the proposed interface, assumptions and test plan.
