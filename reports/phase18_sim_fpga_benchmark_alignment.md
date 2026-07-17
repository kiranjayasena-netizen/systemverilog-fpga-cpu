# Phase 18 Simulation-to-FPGA Benchmark Alignment

## Purpose

Phase 18 removes ambiguity between simulation CPI and FPGA board MIPS measurements by using the same benchmark program, same Phase 13 forward-timing CPU RTL, same instruction-memory image and same `retire_valid` definition.

The question is:

```text
When the exact same benchmark program is used in XSim and on the FPGA, how close are the simulated CPI/MIPS prediction and the physical board MIPS measurement?
```

## Benchmark

| Item | Value |
| --- | --- |
| Benchmark image | `programs/final_benchmark.mem` |
| Companion listing | `programs/final_benchmark.md` |
| CPU path | Original Phase 13 forward-timing five-stage pipeline |
| Instruction set used | NOP, ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ, JUMP |

The benchmark is deterministic. It initializes its data-memory locations before loading them, then repeats a loop containing arithmetic dependencies, store/load traffic, load-use dependencies, a taken `BEQ`, a not-taken `BEQ` and backward `JUMP` control flow.

## Simulation Method

| Item | Value |
| --- | --- |
| Testbench | `tb/tb_phase18_final_benchmark_forwardtiming.sv` |
| CPU RTL | `rtl/cpu_core_pipeline_forwardtiming.sv` |
| Instruction memory file | `programs/final_benchmark.mem` |
| Cycle definition | Enabled CPU cycles after reset release |
| Retirement definition | Same `retire_valid` signal used by FPGA MIPS counter |
| CPI formula | `enabled_cycles / retired_instructions` |
| MIPS formula | `clock_frequency_MHz / CPI` |

XSim command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase18_final_benchmark.ps1
```

The local Vivado/XSim run emitted the known Windows `xelab` object-directory cleanup warning after snapshot build. The PowerShell launcher treats that cleanup warning as non-fatal when the snapshot exists, and the snapshot then ran successfully.

## Simulation Result

| Metric | Value |
| --- | ---: |
| Enabled cycles | 20,000 |
| Retired instructions | 16,174 |
| CPI | 1.236552 |
| Predicted MIPS at 100 MHz | 80.870 |
| Predicted MIPS at 115 MHz | 93.001 |
| Load-use stalls | 1,470 |
| Control flush cycles | 1,763 |
| Fetch wait cycles | 1,470 |
| Memory wait cycles | 1,470 |
| Taken branches | 294 |
| Not-taken branches | 1,469 |
| Jumps | 1,469 |

The aligned benchmark is intentionally heavier than the previous FPGA demo workload. Therefore its predicted 115 MHz MIPS is lower than the Phase 17E `0100` board reading, which used the earlier demo program.

## Scaled Counter Check

`tb/tb_phase18_mmcm_mips_counter_scaled.sv` checks the measurement-counter style with a short simulation window:

- `CPU_CLOCK_HZ = 1150`
- `MIPS_DIVISOR = 10`

The test verifies:

- zero-retire windows do not divide by zero;
- display mode `000` selects measured MIPS;
- display mode `001` selects CPI x100;
- display mode `110` selects the 115 MHz clock-debug value.

Result:

```text
PHASE 18 SCALED MIPS COUNTER TEST PASSED
```

The MMCM itself is bypassed for this simulation-only counter check.

## FPGA Method

| Item | Value |
| --- | --- |
| Top module | `fpga_top_phase18_forwardtiming_mmcm_benchmark` |
| Wrapper RTL | `rtl/fpga_top_phase18_forwardtiming_mmcm_benchmark.sv` |
| Base counter wrapper | `rtl/fpga_top_pipeline_forwardtiming_mmcm_mips.sv` |
| Vivado script | `scripts/run_vivado_impl_phase18_forwardtiming_mmcm_benchmark.tcl` |
| Board | Digilent Basys 3 |
| FPGA | `xc7a35tcpg236-1` |
| CPU clock | 115.000 MHz from RTL-instantiated MMCM |
| Measurement window | 115,000,000 CPU cycles |
| Instruction memory file | `programs/final_benchmark.mem` |

The Phase 18 top is a separate wrapper. It keeps the proven Phase 17E MMCM and MIPS-counter logic, but overrides the instruction-memory image with `programs/final_benchmark.mem`.

Display modes match Phase 17E:

| SW3:SW1 | Display |
| ---: | --- |
| `000` | measured integer MIPS |
| `001` | CPI x100 |
| `010` | load-use stall percentage x100 |
| `011` | control-flush percentage x100 |
| `100` | instruction-fetch wait percentage x100 |
| `101` | memory-wait percentage x100 |
| `110` | clock debug value `0115` |
| `111` | measured integer MIPS |

## Timing Result

Vivado implementation was run for the Phase 18 wrapper at the 115 MHz generated CPU clock.

| Metric | Value |
| --- | ---: |
| WNS | +0.014 ns |
| TNS | 0.000 ns |
| WHS | +0.036 ns |
| THS | 0.000 ns |
| LUTs | 1,825 |
| FFs | 2,072 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| MMCM | 1 |
| Bitstream | generated |

Bitstream path:

```text
reports/phase18_benchmark_aligned_impl/bitstreams/fpga_top_phase18_forwardtiming_mmcm_benchmark.bit
```

Critical path summary:

| Item | Value |
| --- | --- |
| Source | `phase17e_counter_wrapper/cpu_inst/id_ex_reg_reg[rs1][0]/C` |
| Destination | `phase17e_counter_wrapper/cpu_inst/fetch_buffer_valid_reg/D` |
| Requirement | 8.696 ns |
| Data path delay | 8.583 ns |
| Logic delay | 2.591 ns |
| Route delay | 5.992 ns |
| Logic levels | 11 |

The implementation is timing-clean, so the Phase 18 FPGA bitstream is valid for board testing.

## Comparison

| Evidence type | Benchmark | Result |
| --- | --- | ---: |
| XSim predicted MIPS at 115 MHz | `final_benchmark.mem` | 93.001 |
| FPGA measured MIPS at 115 MHz | `final_benchmark.mem` | `0093`, approximately 93 MIPS |

Confirmed board reading in MIPS mode:

```text
0093
```

The display is integer-only, and `0093` matches the XSim prediction of 93.001 MIPS within display precision.

## Confirmed Board Observation

| Item | Value |
| --- | --- |
| Board | Digilent Basys 3 |
| CPU clock | 115.000 MHz MMCM-generated |
| Benchmark | `programs/final_benchmark.mem` |
| Display mode | SW3:SW1 = `000` |
| Observed display | `0093` |
| Interpretation | approximately 93 MIPS |

This confirms that the simulation and FPGA hardware measurements agree closely when they use the same benchmark image and the same `retire_valid` counting definition.

## Acceptance Criteria

A fair Phase 18 hardware result requires:

- same CPU RTL: `cpu_core_pipeline_forwardtiming.sv`;
- same instruction-memory file: `programs/final_benchmark.mem`;
- same `retire_valid` definition in simulation and FPGA hardware;
- clean post-route timing;
- correct `CPU_CLOCK_HZ = 115_000_000` measurement window;
- physical Basys 3 display result.

## Result Interpretation

If FPGA and simulation differ, plausible causes include:

- integer MIPS truncation on the 7-segment display;
- reset, fill and drain effects;
- benchmark warm-up;
- one-second sampling-window boundary effects;
- different simulation length versus board measurement window.

Phase 18 does not replace the confirmed Phase 17E 100 MIPS result unless the aligned benchmark is physically tested and shows a higher timing-clean board value. Its purpose is measurement fairness and traceability.
