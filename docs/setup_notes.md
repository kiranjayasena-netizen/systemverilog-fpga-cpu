# Setup Notes

## Tool Setup

- Vivado version: 2026.1
- Licence: Vivado Basic
- Main simulator: Vivado XSim
- Repository path: `C:/FPGA/systemverilog-fpga-cpu`
- Development assistance: Codex CLI and ChatGPT
- GitHub integration: connected to ChatGPT

## Current Status

The repository has been set up for the SystemVerilog FPGA CPU summer project. The first RTL module, `rtl/alu.sv`, has a matching self-checking testbench, `tb/alu_tb.sv`.

The ALU has simulated successfully in Vivado XSim, and a waveform has been generated and viewed.

## Simulator Notes

Vivado Simulator is the main simulator for now.

Verilator full simulation currently has a linker issue, so Verilator should be treated as optional until that issue is fixed. It may still be useful later for linting or faster simulation once the build flow is repaired.

## Repository Notes

Generated files and build outputs should not be committed. This includes Vivado generated directories, simulator databases, VCD/WDB waveform files, `obj_dir/`, compiled executables and bitstreams.
