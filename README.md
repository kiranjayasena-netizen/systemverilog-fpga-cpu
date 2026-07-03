# systemverilog-fpga-cpu

SystemVerilog FPGA soft-core processor summer project.

## Project Aim

The aim of this repository is to build a simple FPGA soft-core processor in SystemVerilog and use it as a practical study of digital design, verification, FPGA implementation, timing closure, resource usage and maximum clock frequency.

The project starts with small, verified RTL blocks and builds toward an integrated CPU core that can be simulated, synthesized and analysed in Vivado.

## Current Status

- Vivado 2026.1 is installed and licensed with Vivado Basic.
- Vivado XSim is the main simulator.
- GitHub is connected to ChatGPT.
- Codex CLI is installed.
- `rtl/alu.sv` contains the first RTL module: a parameterised combinational ALU that defaults to the 32-bit CPU datapath width.
- `tb/alu_tb.sv` contains a self-checking 32-bit ALU testbench.
- The parameterised 32-bit ALU simulation has passed in Vivado XSim.
- `rtl/register_file.sv` contains a 32-register, 32-bit register file.
- `tb/register_file_tb.sv` contains a self-checking register file testbench.
- The register file simulation has passed in Vivado XSim.
- `rtl/program_counter.sv` contains the 32-bit program counter.
- `tb/program_counter_tb.sv` contains a self-checking program counter testbench.
- The program counter simulation has passed in Vivado XSim.
- `rtl/instruction_memory.sv` contains the combinational instruction memory.
- `tb/instruction_memory_tb.sv` contains a self-checking instruction memory testbench.
- The instruction memory simulation has passed in Vivado XSim.
- `rtl/fetch_unit.sv` integrates the program counter and instruction memory.
- `tb/fetch_unit_tb.sv` contains a self-checking fetch unit testbench.
- The fetch unit simulation has passed in Vivado XSim.
- ALU, register file, program counter, instruction memory and fetch unit waveform images have been generated.
- Documentation scaffolding has been added under `docs/`.

## Planned Modules

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
- Constraint files for the target FPGA board
- Small assembly or machine-code test programs

## Repository Structure

- `rtl/` - synthesizable SystemVerilog RTL modules.
- `tb/` - self-checking SystemVerilog testbenches.
- `docs/` - project notes, setup notes, verification logs and planning documents.
- `docs/images/` - screenshots and waveform images used by the documentation.
- `constraints/` - FPGA board constraint files.
- `programs/` - CPU test programs.
- `reports/` - timing, utilisation and power reports.
- `scripts/` - helper scripts for simulation, synthesis or report generation.
- `vivado/` - Vivado project files. Generated Vivado outputs should not be committed.

## Tools

- Vivado 2026.1
- Vivado Basic licence
- Vivado XSim for simulation
- SystemVerilog for RTL and testbenches
- Git and GitHub for version control
- Codex CLI and ChatGPT for assisted development and documentation

## Verification Approach

Each RTL block should have a matching self-checking testbench. Simulation results, major test coverage points and waveform notes should be recorded in `docs/verification.md`.

Generated files such as `.vcd`, `.wdb`, `.sim`, `.cache`, `obj_dir/` and executables should be ignored and not committed.
