# AI CPU benchmark evidence

Stage 27D physical Basys 3 measurements at 80 MHz (`READ_CYCLES`; UART time
excluded):

| Workload | Baseline | Optimized | Ratio | Result |
|---|---:|---:|---:|---|
| DOT4 | 42 | 17 | 2.4706x | `0x46` |
| DOT64 | 73 | 32 | 2.2813x | `0x40` |
| MATVEC | 27 | 20 | 1.3500x | `0x278, 0xffff_ff11` |
| EDGE | 16 | 17 | 0.9412x | `0x1` |

All results match independent golden references. Optimized stability was
100/100 jobs with no UART errors, timeouts, mismatches, or nondeterminism.
