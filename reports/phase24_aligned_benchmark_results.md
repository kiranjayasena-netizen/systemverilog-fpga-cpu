# Phase 24 Aligned Benchmark Results

## Benchmark

Phase 24 uses the shared aligned benchmark:

- Program: `programs/final_benchmark.mem`
- CPU: `rtl/cpu_core_pipeline_forwardtiming_phase24.sv`
- Testbench: `tb/tb_phase24_final_benchmark.sv`
- Retire definition: same `debug_retire_valid` style used by the hardware MIPS wrappers

The simulation ran for 20,000 enabled cycles.

## Result

| Metric | Phase 18/21 baseline | Phase 22/23 JUMP-cache | Phase 24 frontend split |
| --- | ---: | ---: | ---: |
| Enabled cycles | 20,000 | 20,000 | 20,000 |
| Retired instructions | 16,174 | 16,921 | 13,254 |
| CPI | 1.236552 | 1.181963 | 1.508978 |
| Predicted MIPS at 100 MHz | 80.872 | 84.605 | 66.270 |
| Predicted MIPS at 115 MHz | 93.001 | 97.296 | 76.210 |
| Predicted MIPS at 117 MHz | 94.618 | 98.988 | 77.536 |
| Predicted MIPS at 119 MHz | 96.235 | 100.680 | 78.861 |
| Predicted MIPS at 120 MHz | 97.044 | 101.526 | 79.524 |

## Detailed Phase 24 Counters

| Counter | Value |
| --- | ---: |
| Core total cycles | 20,000 |
| Core retired instructions | 13,254 |
| Data hazard stalls | 1,205 |
| Load-use stalls | 1,205 |
| Control flush cycles | 1,444 |
| Fetch wait cycles | 1,205 |
| Memory wait cycles | 1,205 |
| Taken branches | 240 |
| Not-taken branches | 1,204 |
| Jumps | 1,204 |
| Wrong-path flushed | 1,444 |

## Targets

| Target | Required CPI | Phase 24 status |
| --- | ---: | --- |
| 100 MIPS at 119 MHz | <= 1.190 | not reached |
| 100 MIPS at 117 MHz | <= 1.170 | not reached |
| 100 MIPS at 115 MHz | <= 1.150 | not reached |

## Conclusion

The aligned benchmark result regressed substantially. Phase 24 proves the copied CPU remains correct, but the added frontend request staging reduces useful retirement rate. It should not be used as a performance replacement for Phase 20E, Phase 18 baseline, or the Phase 22/23 simulation-only JUMP-cache result.
