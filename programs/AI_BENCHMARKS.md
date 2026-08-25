# Stage 27 CPU AI benchmark images

Each baseline/optimized pair computes the same workload and writes to the
documented validation result locations. The `.mem` files are the exact images
used for Stage 27 physical evidence.

| Workload | Baseline image | Optimized image | Golden |
|---|---|---|---|
| DOT4 | `ai_dot4_70_baseline.mem` | `ai_dot4_70_dot4acc.mem` | `0x46` |
| DOT64 | `ai_dot64_baseline.mem` | `ai_dot64_dot4acc.mem` | `0x40` |
| MATVEC | `ai_matvec_baseline.mem` | `ai_matvec_dot4acc.mem` | `0x278, 0xffff_ff11` |
| EDGE | `ai_edge_baseline.mem` | `ai_edge_dot4acc.mem` | `0x1` |

Physical cycles were 42/17, 73/32, 27/20, and 16/17 respectively (baseline /
optimized). The EDGE result is a documented optimized slowdown.
