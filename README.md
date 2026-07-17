# systemverilog-fpga-cpu

SystemVerilog FPGA soft-core CPU project targeting the Digilent Basys 3 board.

## Project Aim

This repository builds a simple custom FPGA CPU from small verified RTL blocks, then follows the design through simulation, FPGA implementation, timing closure, board bring-up and hardware performance measurement.

Final milestone: Phase 19A physically measured approximately 102 MIPS on the Basys 3 by running the original Phase 13 forward-timing CPU from an MMCM-generated 117 MHz clock. The 7-segment display showed `0102` in MIPS mode.

## Current Best Results

| Category | Result |
| --- | ---: |
| Best physical FPGA-measured MIPS | Phase 19A, approximately 102 MIPS at 117.000 MHz |
| Best 100 MHz board-measured MIPS | Phase 13, approximately 87 MIPS |
| Phase 14G board-measured MIPS at 100 MHz | approximately 63 MIPS |
| Phase 14G high-frequency board-measured MIPS | Phase 19B, approximately 101 MIPS at 160.000 MHz |
| Phase 14G timing-estimated peak practical MIPS | approximately 101.8 MIPS |
| Phase 19A 7-seg measured value | `0102` |
| Phase 19B 7-seg measured value | `0101` |
| Phase 17E 7-seg measured value | `0100` |
| Target FPGA board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |

Phase 19A physically verified the high-frequency Phase 13 forward-timing CPU on the Basys 3 at 117 MHz. The design used an MMCM-generated CPU clock and a MIPS counter calibrated to a 117,000,000-cycle one-second measurement window. The seven-segment display showed `0102`, corresponding to approximately 102 MIPS.

The Phase 19A result is the best real board-measured result. Phase 19B also physically measured the Phase 14G six-stage CPU at approximately 101 MIPS using a 160 MHz generated clock. Phase 14G's 166.667 MHz / approximately 101.8 MIPS value remains timing-estimated only because the Phase 19B 166.667 MHz hardware-measurement wrapper did not meet setup timing.

Phase 18 adds a benchmark-aligned flow using the same `programs/final_benchmark.mem` image in XSim and on the FPGA. The aligned simulation predicts approximately 93.0 MIPS at 115 MHz for that benchmark; the Phase 18 board test displayed `0093`, confirming close simulation-to-hardware agreement for the shared workload.

## Architecture Summary

The project uses a compact custom 32-bit ISA with:

- Arithmetic/logical instructions: NOP, ADD, SUB, AND, OR, XOR, ADDI
- Memory instructions: LOAD, STORE
- Control-flow instructions: BEQ, JUMP
- Signed 13-bit immediates
- `x0` hardwired to zero
- Safe invalid-opcode handling

The final physically measured 102 MIPS result uses the Phase 13 five-stage forward-timing pipeline at 117 MHz. The project also includes multi-cycle, BRAM-aware, prefetch, five-stage pipeline and six-stage pipeline variants for comparison.

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

## Build the Phase 17E 100 MIPS Baseline

The earlier 115 MHz / 100 MIPS baseline wrapper is built with:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_mmcm_mips.tcl
```

The generated bitstream is written locally under:

```text
reports/phase17e_mmcm_mips_impl/bitstreams/fpga_top_pipeline_forwardtiming_mmcm_mips.bit
```

Generated implementation folders and bitstreams are intentionally ignored by Git.

## Run The Phase 18 Aligned Benchmark

The simulation-to-FPGA aligned benchmark uses the same program image in XSim and in the 115 MHz FPGA wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_phase18_final_benchmark.ps1
vivado -mode batch -source scripts/run_vivado_impl_phase18_forwardtiming_mmcm_benchmark.tcl
```

The Phase 18 bitstream is written locally under:

```text
reports/phase18_benchmark_aligned_impl/bitstreams/fpga_top_phase18_forwardtiming_mmcm_benchmark.bit
```

## Phase 19 Past-100-MIPS Results

Phase 19 creates separate high-frequency board-test wrappers. The 117 MHz Phase 19A bitstream and 160 MHz Phase 19B bitstream have now been physically tested on the Basys 3.

```powershell
vivado -mode batch -source scripts/run_vivado_impl_phase19a_forwardtiming_mmcm_117p0.tcl
vivado -mode batch -source scripts/run_vivado_impl_phase19b_pipeline6_mmcm_160.tcl
```

Useful bitstreams:

```text
reports/phase19a_frequency_sweep_impl/117p0/bitstreams/fpga_top_phase19a_forwardtiming_mmcm_117p0.bit
reports/phase19b_pipeline6_mmcm_impl/160/bitstreams/fpga_top_phase19b_pipeline6_mmcm_160.bit
```

Phase 19A closed timing for the original Phase 13 CPU up to 117.000 MHz and displayed `0102`, approximately 102 MIPS. Phase 19B closed timing for the Phase 14G six-stage CPU up to 160.000 MHz and displayed `0101`, approximately 101 MIPS. The 166.667 MHz Phase 19B wrapper missed setup timing and is not valid board evidence.

## Key Documentation

| Document | Purpose |
| --- | --- |
| [docs/performance_results.md](docs/performance_results.md) | Main performance tables and comparison |
| [reports/final_project_summary.md](reports/final_project_summary.md) | Final book-ready project summary |
| [reports/phase17e_mmcm_high_frequency_mips_test.md](reports/phase17e_mmcm_high_frequency_mips_test.md) | Final 100 MIPS hardware result |
| [reports/phase18_sim_fpga_benchmark_alignment.md](reports/phase18_sim_fpga_benchmark_alignment.md) | Shared simulation/FPGA benchmark alignment |
| [reports/phase19a_phase17e_frequency_sweep.md](reports/phase19a_phase17e_frequency_sweep.md) | Phase 19A 117 MHz / 102 MIPS hardware result |
| [reports/phase19b_phase14g_high_frequency_hardware_mips.md](reports/phase19b_phase14g_high_frequency_hardware_mips.md) | Phase 19B 160 MHz / 101 MIPS six-stage hardware result |
| [reports/phase19_past_100mips_plan.md](reports/phase19_past_100mips_plan.md) | Honest plan for pushing beyond 100 MIPS |
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

- Main hardware milestone reached: approximately 102 MIPS physically measured on Basys 3 in Phase 19A.
- Generated Vivado outputs, bitstreams, checkpoints and implementation folders are not tracked.
- A license should be added before making the repository public.

See [docs/project_history.md](docs/project_history.md) for the full phase-by-phase development history.
