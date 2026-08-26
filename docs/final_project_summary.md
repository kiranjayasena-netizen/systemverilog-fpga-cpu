# Final Project Summary

## Project overview

This project progresses from a general-purpose SystemVerilog CPU, through a
signed-INT8 AI-specialized CPU, to a standalone four-lane vector GPU. The
target is Digilent Basys 3 (`xc7a35tcpg236-1`) using Vivado 2026.1.

## Released systems

### General-purpose CPU — `book-v1.0`

The book release contains the teaching/general CPU. Its historical final
physical milestone measured approximately 104 MIPS at 119 MHz on the project
benchmark.

### CPU AI / DOT4ACC — `cpu-ai-v1.0`

DOT4ACC computes four signed INT8 lane products and accumulates them into `rd`
modulo 2^32. At the common 80 MHz validation clock:

| Workload | Baseline | Optimized | Speedup |
|---|---:|---:|---:|
| DOT4 | 42 | 17 | 2.4706x |
| DOT64 | 73 | 32 | 2.2813x |
| MATVEC | 27 | 20 | 1.3500x |
| EDGE | 16 | 17 | 0.9412x |

EDGE is an optimized slowdown. All results matched independent golden
references. Optimized stability was 100/100 with zero UART errors, timeouts,
result mismatches, or cycle nondeterminism.

Final resources/timing: baseline 2087 LUT, 1890 FF, 1 RAMB18, 0 DSP,
WNS/WHS +2.194/+0.038 ns; optimized 2992 LUT, 2199 FF, 1 RAMB18, 5 DSP,
WNS/WHS +0.141/+0.058 ns. The speedups come from execution-cycle reduction,
not a higher clock.

### Vector GPU — `gpu-v1.0`

The selected `rtl/vector_load_overlap_program_core.sv` provides four 32-bit
SIMD lanes, 128-bit vectors, and eight 128-bit vector registers. At 80 MHz,
REG_VADD takes 4 cycles, ARRAY_ADD 20 cycles, XOR 13 cycles, and VSRA 13
cycles. GPU v1.0 was physically validated on Basys 3, including 100 repeated
launches with no UART or result failures.

## Architecture trade-offs

The general CPU favors flexibility, CPU AI trades LUT/FF/DSP resources for
targeted INT8 dot products, and the GPU trades scalar flexibility for SIMD
throughput. Specialization is workload-dependent; the EDGE slowdown is direct
evidence that it does not guarantee universal speedup.

## Verification methodology

Evidence combines self-checking XSim, canonical-versus-validation equivalence,
independent Python golden references, paired bitstreams, internal cycle
counters, UART control, post-route timing, and physical Basys 3 validation.
UART wall-clock latency is excluded from execution-time measurements.

## Claim boundary

The project demonstrates custom FPGA CPU development, targeted signed-INT8
acceleration, and standalone SIMD/vector processing. It does not establish
commercial CPU performance, GPU-class graphics, NPU-class performance, general
neural-network inference acceleration, or universal AI acceleration.

## Future work

Possible future versions may explore quantized neural-network inference, wider
packed arithmetic, saturation/rounding, matrix-multiply hardware, DMA/memory
feeding, GPU VMUL and masks, vector branches/loops, CPU/GPU interfaces, and
larger memories. These are not v1.0 requirements.
