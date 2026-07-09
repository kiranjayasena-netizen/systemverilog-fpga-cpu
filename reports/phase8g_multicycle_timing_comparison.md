# Phase 8G Multi-Cycle Timing Comparison

## Purpose

Phase 8G creates a separate FPGA implementation path for the verified multi-cycle CPU and compares it with the Phase 7 single-cycle-style FPGA baseline.

This phase does not replace `rtl/cpu_core.sv`, `rtl/fpga_top.sv` or `rtl/cpu_top.sv`. It adds a separate top-level wrapper, `rtl/fpga_top_multicycle.sv`, and separate Vivado scripts for synthesis and implementation.

No CPU instruction encoding or Phase 6 program file was changed.

## Build Context

- Date/time: July 9, 2026, approximately 13:03
- Vivado version: Vivado 2026.1, build 6511674
- Target board: Digilent Basys 3
- Target FPGA part: `xc7a35tcpg236-1`
- Baseline top module: `fpga_top`
- Multi-cycle top module: `fpga_top_multicycle`
- Constraint file: `constraints/basys3.xdc`
- Target clock period: 10.000 ns
- Target clock frequency: 100.000 MHz

## Commands Run

Synthesis:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_synth_multicycle.tcl
```

Implementation and bitstream generation:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts\run_vivado_impl_multicycle.tcl
```

The first sandboxed synthesis attempt failed before RTL analysis because Vivado could not remove a temporary writeability-test file. The same command completed successfully when rerun with normal filesystem access. This was a tool/filesystem issue, not an RTL error.

## Generated Phase 8G Reports

- Synthesis utilisation: `reports/phase8g/utilisation/fpga_top_multicycle_synth_utilization.rpt`
- Synthesis timing summary: `reports/phase8g/timing/fpga_top_multicycle_synth_timing_summary.rpt`
- Synthesis worst paths: `reports/phase8g/timing/fpga_top_multicycle_synth_worst_paths.rpt`
- Synthesis power: `reports/phase8g/power/fpga_top_multicycle_synth_power.rpt`
- Synthesis checkpoint: `reports/phase8g/checkpoints/fpga_top_multicycle_synth.dcp`
- Implementation utilisation: `reports/phase8g/utilisation/fpga_top_multicycle_impl_utilization.rpt`
- Post-route timing summary: `reports/phase8g/timing/fpga_top_multicycle_impl_timing_summary.rpt`
- Post-route worst paths: `reports/phase8g/timing/fpga_top_multicycle_impl_worst_paths.rpt`
- Implementation power: `reports/phase8g/power/fpga_top_multicycle_impl_power.rpt`
- Implementation checkpoint: `reports/phase8g/checkpoints/fpga_top_multicycle_impl.dcp`
- Bitstream: `reports/phase8g/bitstreams/fpga_top_multicycle.bit`

The raw reports, checkpoints and bitstream are generated outputs. The summary report is the main file intended for version control.

## Phase 7 Baseline

The Phase 7C/7D baseline is the original `fpga_top` implementation using the single-cycle-style CPU core.

| Metric | Phase 7 baseline |
| --- | ---: |
| LUTs | 2,983 |
| FFs | 8,314 |
| BRAM | 0 |
| DSP | 0 |
| WNS | -1.551 ns |
| TNS | -5707.315 ns |
| WHS | 0.075 ns |
| Timing at 100 MHz | Not met |
| Estimated max frequency | Approximately 86.6 MHz |
| Worst path classification | Single-cycle-style PC/fetch/decode/execute/writeback path |

## Phase 8G Synthesis Result

Synthesis for `fpga_top_multicycle` completed successfully.

| Metric | Phase 8G synthesis |
| --- | ---: |
| LUTs | 3,044 |
| FFs | 8,647 |
| BRAM | 0 |
| DSP | 0 |
| WNS | 5.050 ns |
| TNS | 0.000 ns |
| WHS | 0.134 ns |
| Timing at 100 MHz | Met |

The synthesis estimate already showed a large timing improvement compared with the Phase 7 baseline, but the post-route result below is the more important FPGA timing result.

## Phase 8G Implementation Result

Implementation and bitstream generation for `fpga_top_multicycle` completed successfully.

| Step | Result |
| --- | --- |
| `synth_design` | Passed |
| `opt_design` | Passed |
| `place_design` | Passed |
| `route_design` | Passed |
| `write_bitstream` | Passed |

Post-route utilisation:

| Resource | Used | Available | Utilisation |
| --- | ---: | ---: | ---: |
| Slice LUTs | 3,027 | 20,800 | 14.55% |
| Slice registers | 8,654 | 41,600 | 20.80% |
| Block RAM tiles | 0 | 50 | 0.00% |
| DSPs | 0 | 90 | 0.00% |
| Bonded IOBs | 19 | 106 | 17.92% |

Post-route timing:

| Metric | Phase 8G post-route |
| --- | ---: |
| WNS | 1.389 ns |
| TNS | 0.000 ns |
| Setup failing endpoints | 0 |
| WHS | 0.038 ns |
| THS | 0.000 ns |
| Hold failing endpoints | 0 |
| Timing at 100 MHz | Met |

Using the post-route WNS as a simple estimate, the implied minimum period is approximately:

```text
10.000 ns - 1.389 ns = 8.611 ns
```

This gives an estimated maximum frequency of approximately:

```text
1000 / 8.611 ns = 116.1 MHz
```

This is a timing-report estimate, not a measured board frequency.

## Worst Path Summary

Worst post-route setup path:

- Slack: 1.389 ns, timing met
- Source: `cpu_inst/alu_result_reg_reg[6]/C`
- Destination: `cpu_inst/memory_read_data_reg_reg[22]/D`
- Requirement: 10.000 ns
- Data path delay: 8.701 ns
- Logic delay: 1.067 ns, 12.263%
- Route delay: 7.634 ns, 87.737%
- Logic levels: 3
- Logic elements: `LUT6=1 MUXF7=1 MUXF8=1`

The worst path is now classified as a multi-cycle memory-read path from the registered ALU/effective-address result into the registered memory-read-data path. It is no longer the full PC/fetch/decode/execute/writeback path seen in the Phase 7 baseline.

The route-delay share is high, so future work may still improve placement or memory implementation. However, the important Phase 8G result is that the path meets the 10 ns target after routing.

## Comparison With Phase 7 Baseline

| Metric | Phase 7 baseline | Phase 8G multi-cycle | Change |
| --- | ---: | ---: | ---: |
| LUTs | 2,983 | 3,027 | +44 |
| FFs | 8,314 | 8,654 | +340 |
| BRAM | 0 | 0 | 0 |
| DSP | 0 | 0 | 0 |
| WNS | -1.551 ns | 1.389 ns | +2.940 ns |
| TNS | -5707.315 ns | 0.000 ns | +5707.315 ns |
| WHS | 0.075 ns | 0.038 ns | -0.037 ns |
| 100 MHz setup timing | Not met | Met | Improved |
| Estimated max frequency | ~86.6 MHz | ~116.1 MHz | Improved |

The multi-cycle design uses slightly more LUTs and flip-flops, which is expected because it adds FSM/control state and intermediate registers. The resource increase is small relative to the Basys 3 capacity.

The timing result is a major improvement. The original single-cycle-style design failed 100 MHz setup timing, while the separate multi-cycle top meets the 100 MHz post-route constraint.

## Warning Review

Non-blocking warnings reviewed:

- `Synth 8-6014`: unused sequential element `regs_reg[0]` was removed. This is expected because register x0 is forced to zero and should not behave like a writable general-purpose register.
- `Project 1-236`: implementation-specific XDC commands are ignored during synthesis but used during implementation. This is the same warning style seen in previous flows.
- `Netlist 29-101`: the `cpu_core_multicycle` cellview contains many primitives and is not ideal for floorplanning. This is not blocking, but hierarchy preservation or memory-implementation cleanup could be considered later.

No warning blocked synthesis, implementation, routing or bitstream generation.

## Interpretation

Phase 8G provides strong evidence that the multi-cycle redesign direction addresses the Phase 7 timing problem. Splitting execution across FSM states reduces the long single-cycle path and gives the FPGA implementation enough timing margin at 100 MHz.

This does not replace the original CPU baseline yet. The original `fpga_top` remains available for Phase 7 comparison, while `fpga_top_multicycle` provides a separate implementation path for future timing-closure work.

## Recommended Next Action

The next engineering step is to review the generated Phase 8G reports and decide whether the multi-cycle CPU should become the preferred FPGA implementation path after supervisor review.

Suggested follow-up work:

1. Add a focused `fpga_top_multicycle` simulation testbench if board-facing LED behaviour needs to be checked before hardware use.
2. Consider a controlled board bring-up using `reports/phase8g/bitstreams/fpga_top_multicycle.bit` only after confirming the Basys 3 constraints.
3. Investigate memory implementation style, because the new worst paths still involve large memory mux/register structures and high route-delay share.
4. Keep the original Phase 7 baseline intact for comparison in the final report.

## Conclusion

Phase 8G synthesis, implementation and bitstream generation passed for the separate multi-cycle FPGA top. The multi-cycle design meets the 100 MHz post-route timing target on the Basys 3 part, with WNS = 1.389 ns and TNS = 0.000 ns.

The result supports the Phase 8 design direction: a modest resource increase buys a substantial timing improvement over the Phase 7 single-cycle-style baseline.
