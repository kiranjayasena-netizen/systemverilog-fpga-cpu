# Final Project Results

## Status

Engineering development is complete. The frozen processor is the H1.3b
functional architecture implemented by the T2 timing-equivalent RTL:

- Core: `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Wrapper: `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Constraints: `constraints/basys3.xdc`
- FPGA: Digilent Basys 3, `xc7a35tcpg236-1`
- Tool: Vivado 2026.1

The highest repeatably validated operating frequency is **93 MHz (PASS 5/5)**.
The nearest tested higher point, 94 MHz, failed with WNS -0.257 ns and 118
setup failures. The representative 93 MHz result is WNS +0.230 ns, TNS 0,
hold WNS +0.059 ns, with 2008 LUT, 1812 FF, 2 RAMB18, 5 DSP48, 1 BUFG, and
0 latches. This is a measured validated frequency, not an exact mathematical
Fmax.

## Architecture in one view

The CPU is a five-boundary scalar pipeline (IF, ID, EX, MEM, WB/retirement)
with synchronous BRAM instruction/data memories, a two-read/one-write 32-bit
register file, scalar ALU/branch/MAC8 execution, and a pipelined four-lane
signed-int8 DOT4ACC unit. DOT4ACC accepts a new operation at II=1; issue at I
completes at I+3 and retires at I+4. The complete specification is in
[`final_cpu_architecture.md`](final_cpu_architecture.md).

Stage H adds one deferred-load completion entry and atomic selective admission
of one younger LOAD (`second_load_transfer_fire`, reservation/ownership, and
in-order retirement). It changes the memory-fed N=128 model from `9K+6` to
`8K+7` without a second RF port, cache, DMA, or scratchpad.

## Stage H cycle progression

| Stage | N=128 cycles | Model | Result |
|---|---:|---|---|
| H0 | 294 | 9K+6 | baseline |
| H1.1 | 294 | 9K+6 | first LOAD overlap, performance-neutral |
| H1.2 | 294 | 9K+6 | deferred forwarding correct but unused |
| H1.3a | 294 | 9K+6 | safe boundary, zero second-LOAD admissions |
| H1.3b | **263** | **8K+7** | 31 real second-LOAD admissions |

The frozen H1.3b measurements are N=16/32/64/128 = **39/71/135/263**. At
N=128, admissions/transfers/BRAM reads/completions are **31/31/31/31** with
zero duplicate or lost completions. The architectural cycle speedup is
294/263 = **1.118x**; at 93 MHz this is approximately **45.26 MMAC/s**.

## Timing-recovery history

| Candidate | WNS @100 MHz | TNS | Setup failures | Hold WNS |
|---|---:|---:|---:|---:|
| H1.3b T0 | -1.865 ns | -817.384 ns | 698 | +0.059 ns |
| T1 | -1.525 ns | -537.848 ns | 652 | +0.059 ns |
| T2 | -0.623 ns | -71.487 ns | 286 | +0.057 ns |
| T3 | -0.920 ns | -233.654 ns | 454 | +0.110 ns |
| Final T2 @93 MHz | **+0.230 ns** | **0** | **0** | **+0.059 ns** |

T1 removed a late redirect qualification. T2 isolated branch operands from
DOT-only deferred forwarding and is the retained physical implementation. T3
was functionally safe but physically worse and is rejected. Stage I measured
scalar/DOT serialization but its realistic opportunity was about two cycles;
it is **NO-GO — RTL NOT JUSTIFIED**.

## Performance hierarchy

| Level | Workload | Cycles | Useful MACs | MMAC/s @93 MHz |
|---|---|---:|---:|---:|
| Arithmetic | register DOT N=128 | 43 | 128 | 276.84 |
| Kernel | Stage H memory-fed N=128 | 263 | 128 | 45.26 |
| Application | Stage J J1 N=128 | 358 | 128 | 33.2514 |
| Application | Stage J J2 2x64 | 331 | 128 | 35.9637 |

The decreasing rates are expected: memory, BRAM latency, address updates,
control flow, and final stores are included at the kernel/application levels.
Stage J J1 results are 94/182/358 cycles for N=32/64/128 with golden outputs
`0x000057ba`, `0x000024e5`, and `0x000028e5`. J2 uses 2x64 because a simple
4x128 unrolled program exceeded the 256-word instruction memory; its outputs
are `0x000024e5` and `0x0000bf7b`.

## Stage L final comparison

The valid same-workload comparison repeats the four-lane pattern
`A=[3,-2,1,-1]`, `B=[127,-128,0,5]` **32 times**, for 128 total signed-int8
products, starting from accumulator 37. Both valid implementations produce
the independent golden result `0x00004f25`.

| Metric | MAC8 | DOT4ACC |
|---|---:|---:|
| Cycles | 134 | 43 |
| Retired | 129 | 33 |
| Arithmetic instructions | 128 | 32 |
| Useful MACs | 128 | 128 |
| MAC/cycle | 0.955224 | 2.976744 |
| MMAC/s @93 MHz | 88.8358 | 276.8372 |
| Result | 0x00004f25 | 0x00004f25 |

DOT4ACC is **3.1163x** faster than MAC8 for this fair register-resident
workload, with 75.0% fewer arithmetic instructions and approximately 74.4%
fewer retired instructions. No scalar same-workload speedup is claimed: the
frozen ISA has no general scalar multiply, shift, or byte-extraction operation.
The failed scalar fallback is retained only as an invalid diagnostic, not as
a performance result. The historical scalar 29 / MAC8 19 result used a
different workload and is context only.

## Regression and limitations

Retained individual regression evidence is A1 306/0, A2 2859/0, C 1468/0,
D 3945/0, Stage G 4258/0, Stage H 4254/0, Stage E 233/0, MAC8 scalar 29 /
MAC8 19 with result `0xfffffff2`, and Phase12 457 cycles / 319 retired.
Register DOT remains 27/43 cycles for N=64/128 and same-rd II=1.

Known limits are the 93 MHz validated boundary (94 MHz failed), the final
BRAM/control critical path, 256-word instruction memory, one deferred-load
entry, conservative scalar/DOT serialization, and no cache/DMA/scratchpad or
second RF write port. These are documented limits, not open optimization work.

## Reference index

- [Final architecture specification](final_cpu_architecture.md)
- [Stage H memory-feed report](dot4acc_stage_h_memory_feed.md)
- [Stage I scalar-overlap report](dot4acc_stage_i_scalar_overlap.md)
- [Stage J AI workload report](dot4acc_stage_j_ai_workload.md)
- [Stage K final characterisation](dot4acc_stage_k_final_characterisation.md)
- [Stage L comparison](dot4acc_stage_l_final_comparison.md)
- [Master machine-readable results](final_project_results.csv)
- [Reproducibility guide](../docs/reproducibility.md)

## Final declaration

**ENGINEERING DEVELOPMENT COMPLETE — ARCHITECTURE FROZEN.** No Stage M or
further architecture optimization is part of this project milestone.
