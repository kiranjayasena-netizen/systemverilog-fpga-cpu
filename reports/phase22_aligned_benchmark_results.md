# Phase 22 Aligned Benchmark Results

## Purpose

This report compares Phase 22 against the Phase 18 / Phase 21 aligned benchmark baseline using the same program image:

- `programs/final_benchmark.mem`

## Simulation Method

The testbench runs for 20,000 enabled cycles and counts retired instructions with the CPU `retire_valid` signal. CPI is calculated as:

```text
CPI = enabled cycles / retired instructions
```

Predicted MIPS is calculated as:

```text
MIPS = clock frequency in MHz / CPI
```

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_xsim_phase22_performance.ps1
```

## Results

| Design | CPI | Predicted MIPS at 115 MHz | Predicted MIPS at 117 MHz | Predicted MIPS at 119 MHz | Predicted MIPS at 120 MHz |
| --- | ---: | ---: | ---: | ---: | ---: |
| Phase 18 baseline | 1.236552 | 93.001 | 94.618 | 96.235 | 97.044 |
| Phase 21 copied CPU | 1.236552 | 93.001 | 94.618 | 96.235 | 97.044 |
| Phase 22 copied CPU | 1.181963 | 97.296 | 98.988 | 100.680 | 101.526 |

Phase 22 reaches the simulation CPI target:

| Target | Result |
| --- | --- |
| CPI <= 1.190 for 100 MIPS at 119 MHz | met |
| CPI <= 1.170 for 100 MIPS at 117 MHz | not met |
| CPI <= 1.150 for 100 MIPS at 115 MHz | not met |

## Counter Comparison

| Metric | Phase 18/21 baseline | Phase 22 |
| --- | ---: | ---: |
| Enabled cycles | 20,000 | 20,000 |
| Retired instructions | 16,174 | 16,921 |
| CPI | 1.236552 | 1.181963 |
| Load-use stalls | 1,470 | 1,538 |
| Control flush cycles | 1,763 | 1,845 |
| Fetch wait cycles | 1,470 | 1,538 |
| Memory wait cycles | 1,470 | 1,538 |
| Taken branches | 294 | 307 |
| Not-taken branches | 1,469 | 1,538 |
| Jumps | 1,469 | 1,538 |
| Wrong-path flushed | 2,057 | 1,229 |

The main improvement is the reduction in wrong-path frontend work. The counter values are sampled over a fixed cycle window, so branch/jump counts rise because more loop iterations complete within the same 20,000 cycles.

## Timing Reality Check

The improved simulation CPI is not enough by itself. The 119 MHz Vivado implementation failed setup timing:

| Clock | WNS | TNS | WHS | THS | Bitstream |
| ---: | ---: | ---: | ---: | ---: | --- |
| 119 MHz | -1.258 ns | -246.378 ns | +0.087 ns | 0.000 ns | not generated |

Therefore no Phase 22 board MIPS result is claimed.
