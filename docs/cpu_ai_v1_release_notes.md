# CPU AI v1.0 release notes

This release freezes the Stage 27 CPU AI validation implementation. The
optimized core adds signed INT8 DOT4ACC (four lane products accumulated into a
32-bit result) while the paired baseline uses scalar instructions.

Physical validation used matched workloads, independent golden references, the
same UART/control path, and a Digilent Basys 3 at 80 MHz:

| Workload | Baseline | Optimized | Measured speedup |
|---|---:|---:|---:|
| DOT4 | 42 cycles | 17 cycles | 2.4706x |
| DOT64 | 73 cycles | 32 cycles | 2.2813x |
| MATVEC | 27 cycles | 20 cycles | 1.3500x |
| EDGE | 16 cycles | 17 cycles | 0.9412x (slowdown) |

Results matched the golden models. The optimized design passed 100/100
stability jobs with zero UART errors, timeouts, mismatches, or cycle
nondeterminism. Final timing is positive for both variants; the optimized
design uses 2992 LUT, 2199 FF, 1 RAMB18 and 5 DSP versus 2087 LUT, 1890 FF,
1 RAMB18 and 0 DSP for baseline. This is a measured kernel tradeoff, not a
claim of general AI acceleration.

Stage 27C simulation cycles (41/16, 72/31, 26/19, 15/16) are simulation
evidence and are intentionally separate from the physical values above.

See [the reproduction guide](cpu_ai_v1_reproduction.md) and [the manifest](cpu_ai_v1_release_manifest.md).
