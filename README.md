# systemverilog-fpga-cpu

SystemVerilog FPGA soft-core CPU project targeting the Digilent Basys 3 board.

## Book Edition

This repository is the source companion to the eProjectCPU teaching book.

| Item | Publication value |
| --- | --- |
| Book-compatible release | `book-v1.0` |
| Authoritative source commit | `d7a18dff029060ebdc1cd2616d327796523e75e3` |
| Vivado version | 2026.1 |
| Target board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |

The `book-v1.0` release preserves the source snapshot used by the printed
edition. Later work on `main` may contain additional experiments.

## Project Aim

This repository builds a simple custom FPGA CPU from small verified RTL blocks, then follows the design through simulation, FPGA implementation, timing closure, board bring-up and hardware performance measurement.

Final milestone: Phase 20E physically measured approximately 104 MIPS on the Basys 3 by running the original Phase 13 forward-timing CPU from an MMCM-generated 119 MHz clock. The 7-segment display showed `0104` in MIPS mode.

## Current Best Results

| Category | Result |
| --- | ---: |
| Best physical FPGA-measured MIPS | Phase 20E, approximately 104 MIPS at 119.000 MHz |
| Best 100 MHz board-measured MIPS | Phase 13, approximately 87 MIPS |
| Phase 14G board-measured MIPS at 100 MHz | approximately 63 MIPS |
| Phase 14G high-frequency board-measured MIPS | Phase 19B, approximately 101 MIPS at 160.000 MHz |
| Phase 14G timing-estimated peak practical MIPS | approximately 101.8 MIPS |
| Phase 20E 7-seg measured value | `0104` |
| Phase 19A 7-seg measured value | `0102` |
| Phase 19B 7-seg measured value | `0101` |
| Phase 17E 7-seg measured value | `0100` |
| Target FPGA board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |

Phase 20E physically verified the high-frequency Phase 13 forward-timing CPU on the Basys 3 at 119 MHz. The design used an MMCM-generated CPU clock and a MIPS counter calibrated to a 119,000,000-cycle one-second measurement window. The seven-segment display showed `0104`, corresponding to approximately 104 MIPS.

The Phase 20E result is the best real board-measured result. Phase 19B also physically measured the Phase 14G six-stage CPU at approximately 101 MIPS using a 160 MHz generated clock. Phase 14G's 166.667 MHz / approximately 101.8 MIPS value remains timing-estimated only because the Phase 19B 166.667 MHz hardware-measurement wrapper did not meet setup timing.

Phase 18 adds a benchmark-aligned flow using the same `programs/final_benchmark.mem` image in XSim and on the FPGA. The aligned simulation predicts approximately 93.0 MIPS at 115 MHz for that benchmark; the Phase 18 board test displayed `0093`, confirming close simulation-to-hardware agreement for the shared workload.

## Architecture Summary

The project uses a compact custom 32-bit ISA with:

- Arithmetic/logical instructions: NOP, ADD, SUB, AND, OR, XOR, ADDI
- Phase 12 AI extension: signed INT8 `MAC8` with a 32-bit accumulator
- Memory instructions: LOAD, STORE
- Control-flow instructions: BEQ, JUMP
- Signed 13-bit immediates
- `x0` hardwired to zero
- Safe invalid-opcode handling

`MAC8` is currently implemented only in the Phase 12 five-stage core. The
historical single-cycle, multicycle and later experimental pipeline variants
remain unchanged and reject its opcode. See
[docs/ai_optimization_plan.md](docs/ai_optimization_plan.md) for the encoding,
measured dot-product comparison and staged AI roadmap.

The final physically measured 104 MIPS result uses the Phase 13 five-stage forward-timing pipeline at 119 MHz. The project also includes multi-cycle, BRAM-aware, prefetch, five-stage pipeline and six-stage pipeline variants for comparison.

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

## Reproduce the Published Result

For the shortest book-aligned route through the repository:

1. Install AMD Vivado 2026.1 with support for the Artix-7 device family.
2. Download the `book-v1.0` release or check out its tagged commit.
3. Open a Vivado-enabled PowerShell in the repository root.
4. Run the XSim regression:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
   ```

5. Build the confirmed Phase 20E 119 MHz design:

   ```powershell
   vivado -mode batch -source scripts/run_vivado_impl_phase20_phase19a_119p0.tcl
   ```

6. Confirm that the timing summary has non-negative setup slack and no
   relevant unconstrained paths before using the bitstream.
7. Program the Basys 3 and select MIPS display mode. The retained physical
   result displayed `0104`, corresponding to approximately 104 MIPS on the
   project benchmark.

See [Reproducing the Book Results](docs/reproducing-the-book-results.md) for
the full procedure, expected evidence and limitations.

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

## Phase 20 Performance Improvement Work

Phase 20 starts the next performance-improvement pass after the confirmed Phase 19A result. It keeps the proven Phase 13 and Phase 14G CPU RTL files untouched and uses copied experimental paths.

The first copied Phase 13-derived CPU adds conservative static backward-BEQ prediction and passes focused XSim correctness testing. On the aligned `programs/final_benchmark.mem` workload, however, CPI remains unchanged at `1.236552`, so that copied CPU is not accepted as a performance improvement. The original-CPU Phase 20E frequency extension physically displayed `0103` at 118.5 MHz and `0104` at 119.0 MHz.

## Phase 21 CPI-Focused Work

Phase 21 repeats the CPI-focused branch-prediction experiment in a separate copied Phase 13-derived CPU path and keeps the original Phase 13 and Phase 14G CPU RTL untouched. The copied Phase 21 CPU passes focused XSim correctness testing, but the aligned benchmark CPI remains `1.236552`.

That means the Phase 21 copied CPU predicts the same aligned-benchmark throughput as Phase 18: approximately 93.001 MIPS at 115 MHz and 96.235 MIPS at 119 MHz. Phase 20E remains the best confirmed physical FPGA result at approximately 104 MIPS.

## Phase 22 Frontend CPI Experiment

Phase 22 targets the actual aligned-benchmark hot path with a copied CPU that adds a one-entry unconditional JUMP target cache. Focused XSim correctness passed, and the aligned benchmark CPI improved from `1.236552` to `1.181963`, predicting approximately 100.680 MIPS at 119 MHz.

The 119 MHz Vivado implementation failed setup timing with WNS `-1.258 ns`, so Phase 22 is not a valid hardware result yet. Phase 20E remains the best confirmed physical board measurement.

## Phase 23 Retimed JUMP-Cache Experiment

Phase 23 creates another copied CPU to retime the Phase 22 JUMP target-cache lookup. It registers predictor hit/target metadata before using it for the frontend request path.

Focused XSim correctness passed with 29 checks and 0 failures. The aligned benchmark CPI stayed at `1.181963`, so the simulation still predicts approximately 100.680 MIPS at 119 MHz. Vivado timing improved versus Phase 22 at 119 MHz, from WNS `-1.258 ns` to `-0.981 ns`, but 119, 117 and 115 MHz still failed setup timing. No Phase 23 bitstream was generated and no Phase 23 board result is claimed. Phase 20E remains the best confirmed physical result.

## Phase 24 Frontend-Split Experiment

Phase 24 creates a copied CPU with a more conservative registered frontend request path. Focused XSim correctness passed with 29 checks and 0 failures, but the aligned benchmark CPI regressed to `1.508978`.

Vivado closed timing at 100 and 105 MHz, but 110 MHz failed setup timing. Because the CPI regression dominates, Phase 24 is not a performance replacement and no Phase 24 board result is claimed. Phase 20E remains the best confirmed physical FPGA result at approximately 104 MIPS.

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
| [reports/phase20_cpi_improvement_analysis.md](reports/phase20_cpi_improvement_analysis.md) | Phase 20 CPI bottleneck analysis |
| [reports/phase20_forwardtiming_optimisation.md](reports/phase20_forwardtiming_optimisation.md) | Phase 20 copied-CPU optimisation result |
| [reports/phase20_phase19a_frequency_extension.md](reports/phase20_phase19a_frequency_extension.md) | Phase 20E 119 MHz / 104 MIPS original-CPU result |
| [reports/phase20_phase19b_166mhz_timing_analysis.md](reports/phase20_phase19b_166mhz_timing_analysis.md) | Phase 20 six-stage 166 MHz timing-failure analysis |
| [reports/phase21_cpi_branch_prediction.md](reports/phase21_cpi_branch_prediction.md) | Phase 21 branch-prediction CPI experiment |
| [reports/phase21_forwardtiming_benchmark_results.md](reports/phase21_forwardtiming_benchmark_results.md) | Phase 21 aligned benchmark XSim result |
| [reports/phase21_frequency_extension_after_104mips.md](reports/phase21_frequency_extension_after_104mips.md) | Phase 21 prepared frequency-extension candidates |
| [reports/phase21_phase19b_166mhz_timing_followup.md](reports/phase21_phase19b_166mhz_timing_followup.md) | Phase 21 six-stage timing follow-up |
| [reports/phase22_frontend_control_analysis.md](reports/phase22_frontend_control_analysis.md) | Phase 22 frontend/control-flow bottleneck analysis |
| [reports/phase22_forwardtiming_optimisation.md](reports/phase22_forwardtiming_optimisation.md) | Phase 22 JUMP target-cache optimisation result |
| [reports/phase22_aligned_benchmark_results.md](reports/phase22_aligned_benchmark_results.md) | Phase 22 aligned benchmark CPI comparison |
| [reports/phase22_phase20e_frequency_extension_followup.md](reports/phase22_phase20e_frequency_extension_followup.md) | Phase 22 optional MHz-only follow-up notes |
| [reports/phase23_timing_closure_analysis.md](reports/phase23_timing_closure_analysis.md) | Phase 23 retimed JUMP-cache timing-closure analysis |
| [reports/phase23_forwardtiming_optimisation.md](reports/phase23_forwardtiming_optimisation.md) | Phase 23 copied-CPU retiming result |
| [reports/phase23_aligned_benchmark_results.md](reports/phase23_aligned_benchmark_results.md) | Phase 23 aligned benchmark CPI comparison |
| [reports/phase23_fpga_timing_results.md](reports/phase23_fpga_timing_results.md) | Phase 23 FPGA timing results |
| [reports/phase24_frontend_split_analysis.md](reports/phase24_frontend_split_analysis.md) | Phase 24 frontend-split timing/CPI analysis |
| [reports/phase24_forwardtiming_optimisation.md](reports/phase24_forwardtiming_optimisation.md) | Phase 24 copied-CPU optimisation result |
| [reports/phase24_aligned_benchmark_results.md](reports/phase24_aligned_benchmark_results.md) | Phase 24 aligned benchmark CPI comparison |
| [reports/phase24_fpga_timing_results.md](reports/phase24_fpga_timing_results.md) | Phase 24 FPGA timing results |
| [docs/hardware_evidence_checklist.md](docs/hardware_evidence_checklist.md) | Evidence checklist for board photos/videos |
| [docs/project_history.md](docs/project_history.md) | Full phase-by-phase development history |
| [docs/book_source_index.md](docs/book_source_index.md) | Source map for writing the project book |
| [docs/architecture.md](docs/architecture.md) | CPU architecture overview |
| [docs/isa.md](docs/isa.md) | Custom ISA reference |
| [docs/verification.md](docs/verification.md) | Simulation and hardware verification notes |
| [docs/ai_optimization_plan.md](docs/ai_optimization_plan.md) | INT8 inference architecture plan and Phase 1/2 results |

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

- Main hardware milestone reached: approximately 104 MIPS physically measured on Basys 3 in Phase 20E.
- Generated Vivado outputs, bitstreams, checkpoints and implementation folders are not tracked.
- The repository is public.
- Source files are released under the MIT License; book text and illustrations
  retain their separately stated copyright.
- Phase 21-24 directories are retained as experimental evidence and do not
  replace the confirmed Phase 20E result.

See [docs/project_history.md](docs/project_history.md) for the full phase-by-phase development history.

## Licence and Citation

The SystemVerilog, testbenches, scripts, constraints and supporting project
files are available under the [MIT License](LICENSE). The published book text
and its illustrations are not licensed by this repository licence.

Citation metadata is provided in [`CITATION.cff`](CITATION.cff).
