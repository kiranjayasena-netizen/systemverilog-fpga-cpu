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
- `rtl/cpu_defs_pkg.sv` defines shared opcode and ALU operation constants without changing the instruction encodings.
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
- `rtl/data_memory.sv` contains the standalone data memory block used by the CPU core for LOAD and STORE support.
- `tb/data_memory_tb.sv` contains a self-checking data memory testbench.
- The data memory simulation has passed in Vivado XSim.
- `rtl/fetch_unit.sv` integrates the program counter and parameterised instruction memory.
- `tb/fetch_unit_tb.sv` contains a self-checking fetch unit testbench.
- The fetch unit simulation has passed in Vivado XSim.
- `rtl/instruction_decoder.sv` decodes the 32-bit instruction fields for opcode, register indexes and signed immediate values.
- `tb/instruction_decoder_tb.sv` contains a self-checking instruction decoder testbench.
- The instruction decoder simulation has passed in Vivado XSim.
- `rtl/control_unit.sv` maps decoded instruction opcodes to register write, immediate select, ALU operation, memory access, branch, jump and validity control signals.
- `tb/control_unit_tb.sv` contains a self-checking control unit testbench.
- The control unit simulation has passed in Vivado XSim.
- `rtl/cpu_core.sv` integrates fetch, decode, control, register file, ALU and data memory blocks into the first simple CPU core, with instruction memory depth and init-file parameters exposed for program loading.
- `tb/cpu_core_tb.sv` contains a strengthened self-checking CPU core integration testbench.
- The CPU core simulation has passed in Vivado XSim, including LOAD, STORE, BEQ and JUMP integration.
- `programs/load_store_test.mem` contains a file-loadable LOAD/STORE CPU test program.
- `tb/cpu_core_program_tb.sv` contains a self-checking CPU core testbench that loads `programs/load_store_test.mem` through the instruction memory `INIT_FILE` path.
- The file-loaded CPU core program simulation has passed in Vivado XSim.
- `programs/branch_jump_test.mem` contains a file-loadable BEQ/JUMP CPU test program.
- `tb/cpu_core_branch_tb.sv` and `tb/cpu_core_branch_program_tb.sv` contain self-checking branch/jump CPU core testbenches.
- The branch/jump CPU core simulations have passed in Vivado XSim.
- `rtl/fpga_top.sv` provides the first FPGA-facing wrapper around `cpu_core`.
- `programs/fpga_led_demo.mem` contains a small instruction program for LED debug bring-up.
- Phase 3A targets the Digilent Basys 3 board with FPGA part `xc7a35tcpg236-1`.
- `constraints/basys3.xdc` maps the current wrapper ports to the Basys 3 clock, reset button, enable switch and LEDs.
- `tb/fpga_top_tb.sv` contains a self-checking simulation for the FPGA wrapper LED debug outputs.
- `scripts/run_vivado_synth.tcl` and `scripts/run_vivado_impl.tcl` provide baseline Vivado build scripts for the Basys 3 target.
- ALU, register file, program counter, instruction memory, fetch unit, instruction decoder and control unit waveform images have been generated.
- Documentation scaffolding has been added under `docs/`.

## Documentation

- [ISA reference](docs/isa.md) documents the custom 32-bit instruction format, opcode map, immediate sign extension and branch/jump target calculation.
- [Architecture overview](docs/architecture.md) explains the CPU datapath at a beginner-friendly level.
- [Architecture notes](docs/architecture_notes.md) track lower-level design notes as the implementation evolves.
- [FPGA implementation plan](docs/fpga_implementation_plan.md) explains the Phase 3A FPGA wrapper, LED debug mapping and Vivado build scripts.
- [Verification notes](docs/verification.md) record XSim results and coverage points.

## How To Run Regression Tests

Open a Vivado-enabled PowerShell from the repository root and run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

The script runs the current Vivado XSim testbenches for the RTL modules and CPU integration programs. It is intended for local developer use; CI is not assumed yet.

## Phase 3A FPGA Baseline Build

Phase 3A adds a simple FPGA top-level wrapper and baseline Vivado scripts for the Digilent Basys 3 without changing CPU behaviour.

- `rtl/fpga_top.sv` instantiates `cpu_core` and maps PC, opcode, control and ALU debug signals onto `led[15:0]`.
- `programs/fpga_led_demo.mem` provides a small looping demo program for LED bring-up.
- `constraints/basys3.xdc` targets the Basys 3 100 MHz clock, one reset button, one enable switch and all 16 LEDs.
- `tb/fpga_top_tb.sv` checks that the wrapper exposes changing CPU debug state on the LEDs.
- `scripts/run_vivado_synth.tcl` runs synthesis for `xc7a35tcpg236-1`.
- `scripts/run_vivado_impl.tcl` runs implementation and writes a bitstream only after the Basys 3 constraints are checked.
- `reports/phase3a_timing_analysis.md` records the baseline post-synthesis timing miss and critical-path analysis.
- `rtl/slow_tick_generator.sv` adds slow LED-visible CPU stepping while keeping the Basys 3 100 MHz clock as the only clock.
- `reports/phase3b_slow_tick_synthesis_summary.md` records the slow-tick wrapper synthesis result.

See [FPGA implementation plan](docs/fpga_implementation_plan.md) for the detailed Phase 3A checklist and acceptance criteria.

## Planned Modules

- ALU
- Register file
- Program counter
- Instruction memory or ROM
- Fetch unit
- Basys 3 synthesis, implementation and hardware LED bring-up
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
