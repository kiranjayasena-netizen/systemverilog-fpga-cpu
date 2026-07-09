# Phase 10B Architecture Trade-Off Comparison

## Purpose

Phase 10B compares the original single-cycle-style CPU implementation with the separate multi-cycle CPU implementation.

The goal is to explain the architectural trade-off between instruction throughput, timing closure, resource cost and FPGA implementation reliability.

## Why This Comparison Matters

The project now has two CPU implementation paths:

- The original `fpga_top` path, built around the first integrated `cpu_core`.
- The separate `fpga_top_multicycle` path, built around `cpu_core_multicycle`.

Both preserve the same custom ISA and instruction encodings. The comparison shows why the multi-cycle design is a better FPGA implementation path even though the original single-cycle-style design has a lower CPI in simulation.

## Phase 7 Single-Cycle-Style Baseline

Target board: Digilent Basys 3

FPGA part: `xc7a35tcpg236-1`

Top module: `fpga_top`

Target clock: 10 ns / 100 MHz

Post-route result:

- LUTs: 2,983
- FFs: 8,314
- BRAM: 0
- DSP: 0
- WNS: -1.551 ns
- TNS: -5707.315 ns
- Estimated maximum frequency: approximately 86.6 MHz
- 100 MHz timing status: not met
- Worst path classification: single-cycle-style PC/fetch/decode/execute/writeback path

## Phase 8G Multi-Cycle Result

Target board: Digilent Basys 3

FPGA part: `xc7a35tcpg236-1`

Top module: `fpga_top_multicycle`

Target clock: 10 ns / 100 MHz

Post-route result:

- LUTs: 3,027
- FFs: 8,654
- BRAM: 0
- DSP: 0
- WNS: +1.389 ns
- TNS: 0.000 ns
- Estimated maximum frequency: approximately 116.1 MHz
- 100 MHz timing status: met

## Phase 10A Multi-Cycle Benchmark Results

The Phase 10A benchmark used `tb/tb_cpu_core_multicycle_performance.sv`.

| Benchmark | Cycles | Instructions | CPI | MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Arithmetic-heavy | 42 | 11 | 3.818 | 26.190 |
| Memory-heavy | 50 | 12 | 4.167 | 24.000 |
| Branch/jump | 39 | 11 | 3.545 | 28.205 |
| Simple loop | 71 | 20 | 3.550 | 28.169 |

## Phase 10B Single-Cycle-Style Benchmark Results

The Phase 10B benchmark uses `tb/tb_cpu_core_singlecycle_performance.sv` and the original `cpu_core` path. It runs benchmark programs equivalent to the Phase 10A programs.

Status: passed.

Transcript:

- `reports/simulation_transcripts/phase10b_xsim_regression_20260709_194210.txt`

| Benchmark | Cycles | Instructions | CPI | MIPS at 86.6 MHz estimated Fmax | Theoretical MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: | ---: |
| Arithmetic-heavy | 11 | 11 | 1.000 | 86.600 | 100.000, not timing-safe |
| Memory-heavy | 12 | 12 | 1.000 | 86.600 | 100.000, not timing-safe |
| Branch/jump | 11 | 11 | 1.000 | 86.600 | 100.000, not timing-safe |
| Simple loop | 20 | 20 | 1.000 | 86.600 | 100.000, not timing-safe |

Theoretical 100 MHz throughput is shown for architectural comparison only. The original single-cycle-style implementation did not meet 100 MHz post-route timing, so the 100 MHz number is not a timing-safe FPGA result.

## Side-By-Side Benchmark Comparison

| Benchmark | Single-cycle CPI | Multi-cycle CPI | Single-cycle MIPS at estimated Fmax | Multi-cycle MIPS at estimated Fmax | Single-cycle MIPS at 100 MHz | Multi-cycle MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Arithmetic-heavy | 1.000 | 3.818 | 86.600 | 30.407 | 100.000, not timing-safe | 26.190 |
| Memory-heavy | 1.000 | 4.167 | 86.600 | 27.864 | 100.000, not timing-safe | 24.000 |
| Branch/jump | 1.000 | 3.545 | 86.600 | 32.746 | 100.000, not timing-safe | 28.205 |
| Simple loop | 1.000 | 3.550 | 86.600 | 32.704 | 100.000, not timing-safe | 28.169 |

## FPGA Implementation Comparison

| Architecture | Top module | LUTs | FFs | BRAM | DSP | WNS | TNS | Estimated Fmax | 100 MHz timing |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Single-cycle-style | `fpga_top` | 2,983 | 8,314 | 0 | 0 | -1.551 ns | -5707.315 ns | ~86.6 MHz | Not met |
| Multi-cycle | `fpga_top_multicycle` | 3,027 | 8,654 | 0 | 0 | +1.389 ns | 0.000 ns | ~116.1 MHz | Met |

## Interpretation

The single-cycle-style CPU has the better CPI because it attempts to complete one instruction per clock cycle. In simulation this gives CPI 1.000 for the benchmark programs.

The cost is timing. The original FPGA implementation has to fit fetch, decode, register read, ALU work, memory access, writeback and PC update into one 10 ns cycle. Post-route timing showed that this path does not meet the 100 MHz target.

The multi-cycle CPU takes more cycles per instruction, so its CPI is worse. However, it divides instruction execution across shorter FSM states, allowing the implemented design to meet the 100 MHz timing target with positive slack. This makes the multi-cycle design the preferred reliable FPGA implementation path for the Basys 3 target.

For this project, the important result is not just maximum simulated instruction throughput. The important engineering result is that the multi-cycle architecture converts a timing-failing baseline into a timing-clean FPGA implementation while preserving the custom ISA.

## Limitations

- The benchmark programs are small and educational.
- The MIPS values are estimates derived from simulation cycle counts and Vivado timing reports.
- The estimated Fmax values come from routed timing reports, not physical board measurement.
- Hardware validation is still pending until the Basys 3 board is available.
- The current memories are simple educational memory arrays rather than a full BRAM-oriented subsystem.

## Recommended Next Work

1. Complete Basys 3 hardware bring-up when the board arrives.
2. Capture real reset, enable switch and LED evidence.
3. Study BRAM-based instruction and data memory implementation.
4. Compare resource and timing impact after memory-system changes.
5. Consider a pipelined CPU as a future extension if higher throughput is required.

## Conclusion

The single-cycle-style CPU is simpler to reason about and has better simulated CPI, but it does not meet the 100 MHz post-route timing target. The multi-cycle CPU has lower instruction throughput for these benchmarks, but it meets 100 MHz timing and is therefore the better FPGA implementation path for reliable Basys 3 deployment.

No RTL, instruction encodings or existing program files were changed for Phase 10B.
