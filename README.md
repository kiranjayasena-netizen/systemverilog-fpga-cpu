# systemverilog-fpga-cpu

SystemVerilog FPGA soft-core CPU project targeting the Digilent Basys 3 board.

## Project Aim

This repository builds a simple custom FPGA CPU from small verified RTL blocks, then follows the design through simulation, FPGA implementation, timing closure, board bring-up and hardware performance measurement.

Final milestone: Phase 17E physically measured approximately 100 MIPS on the Basys 3 by running the original Phase 13 forward-timing CPU from an MMCM-generated 115 MHz clock. The 7-segment display showed `0100` in MIPS mode.

## Current Best Results

| Category | Result |
| --- | ---: |
| Best physical FPGA-measured MIPS | Phase 17E, approximately 100 MIPS at 115.000 MHz |
| Best 100 MHz board-measured MIPS | Phase 13, approximately 87 MIPS |
| Phase 14G board-measured MIPS at 100 MHz | approximately 63 MIPS |
| Phase 14G timing-estimated peak practical MIPS | approximately 101.8 MIPS |
| Phase 17E 7-seg measured value | `0100` |
| Target FPGA board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |

Phase 17E physically verified the high-frequency Phase 13 forward-timing CPU on the Basys 3. The design used an MMCM-generated 115 MHz CPU clock and a MIPS counter calibrated to a 115,000,000-cycle one-second measurement window. The seven-segment display showed `0100`, corresponding to approximately 100 MIPS.

The Phase 17E result is the best real board-measured result. Phase 14G remains the strongest timing-estimated result at approximately 101.8 MIPS, but that value has not been physically measured at 166.667 MHz.

## Architecture Summary

The project uses a compact custom 32-bit ISA with:

- Arithmetic/logical instructions: NOP, ADD, SUB, AND, OR, XOR, ADDI
- Memory instructions: LOAD, STORE
- Control-flow instructions: BEQ, JUMP
- Signed 13-bit immediates
- `x0` hardwired to zero
- Safe invalid-opcode handling

The final physically measured 100 MIPS result uses the Phase 13 five-stage forward-timing pipeline. The project also includes multi-cycle, BRAM-aware, prefetch, five-stage pipeline and six-stage pipeline variants for comparison.

## Hardware Platform

| Item | Value |
| --- | --- |
| Board | Digilent Basys 3 |
| FPGA | Artix-7 `xc7a35tcpg236-1` |
| Tool | Vivado 2026.1 |
| Main simulator | Vivado XSim |
| Language | SystemVerilog |
| Hardware UI | Switches, LEDs and 4-digit 7-segment display |

## Run Simulations

Open a Vivado-enabled PowerShell from the repository root and run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

The regression script runs the self-checking Vivado XSim testbenches used throughout the project.

## Build The Final Phase 17E Bitstream

The final high-frequency hardware MIPS wrapper is built with:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_mmcm_mips.tcl
```

The generated bitstream is written locally under:

```text
reports/phase17e_mmcm_mips_impl/bitstreams/fpga_top_pipeline_forwardtiming_mmcm_mips.bit
```

Generated implementation folders and bitstreams are intentionally ignored by Git.

## Key Documentation

| Document | Purpose |
| --- | --- |
| [docs/performance_results.md](docs/performance_results.md) | Main performance tables and comparison |
| [reports/final_project_summary.md](reports/final_project_summary.md) | Final book-ready project summary |
| [reports/phase17e_mmcm_high_frequency_mips_test.md](reports/phase17e_mmcm_high_frequency_mips_test.md) | Final 100 MIPS hardware result |
| [docs/hardware_evidence_checklist.md](docs/hardware_evidence_checklist.md) | Evidence checklist for board photos/videos |
| [docs/project_history.md](docs/project_history.md) | Full phase-by-phase development history |
| [docs/book_source_index.md](docs/book_source_index.md) | Source map for writing the project book |
| [docs/architecture.md](docs/architecture.md) | CPU architecture overview |
| [docs/isa.md](docs/isa.md) | Custom ISA reference |
| [docs/verification.md](docs/verification.md) | Simulation and hardware verification notes |

## Repository Structure

| Path | Purpose |
| --- | --- |
| `rtl/` | Synthesizable SystemVerilog RTL |
| `tb/` | Self-checking SystemVerilog testbenches |
| `programs/` | Hex memory images for CPU programs |
| `constraints/` | Basys 3 constraints |
| `scripts/` | Vivado/XSim helper scripts |
| `docs/` | Project notes, verification logs, architecture and book-planning docs |
| `docs/images/` | Selected screenshots and board evidence images |
| `reports/` | Human-written reports and selected summaries |

## Repository Status

- Main hardware milestone reached: approximately 100 MIPS physically measured on Basys 3 in Phase 17E.
- Generated Vivado outputs, bitstreams, checkpoints and implementation folders are not tracked.
- A license should be added before making the repository public.

See [docs/project_history.md](docs/project_history.md) for the full phase-by-phase development history.
