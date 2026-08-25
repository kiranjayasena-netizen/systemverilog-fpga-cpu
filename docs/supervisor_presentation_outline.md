# Supervisor Presentation Outline

This 12-section outline is a concise presentation plan based only on the
measured final project evidence. Detailed source material is indexed in
[`reports/final_project_results.md`](../reports/final_project_results.md).

## 1. Motivation: a small CPU for AI-style arithmetic

**Key message:** A custom FPGA CPU can expose useful signed-int8 parallelism
without requiring a large accelerator.

- Build and verify a pipelined SystemVerilog CPU.
- Target signed-int8 dot products relevant to quantized inference.
- Measure complete-program behaviour, not only an arithmetic datapath.

**Suggested evidence:** final-results headline and Stage J workload table.

**Speaker note:** Frame the project as a measured CPU/ISA experiment, not a
claim that one instruction solves the whole memory problem.

## 2. Starting point and target platform

**Key message:** The design is a compact custom processor for a Basys 3.

- 32-bit custom ISA and scalar pipeline.
- `xc7a35tcpg236-1`, Vivado 2026.1.
- Synchronous 256-word instruction and data memories.

**Suggested evidence:** architecture specification, register/memory section.

**Speaker note:** Establish the resource and memory constraints before showing
performance.

## 3. MAC8 extension

**Key message:** MAC8 provides one signed 8x8 multiply-accumulate per
instruction.

- Low signed byte from each source; 32-bit accumulator.
- Historical microbenchmark: scalar 29 cycles, MAC8 19 cycles.
- This historical result is context, not the final same-workload comparison.

**Suggested evidence:** Stage E results and final ISA table.

**Speaker note:** Make clear that historical and final comparisons use
different benchmark conventions.

## 4. DOT4ACC design

**Key message:** DOT4ACC performs four signed-int8 products per instruction.

- Four packed byte lanes, modulo-32-bit accumulation.
- Pipelined arithmetic integrated into the scalar CPU.
- Issue at I, arithmetic completion at I+3, retirement at I+4.

**Suggested evidence:** DOT pipeline timing diagram in `final_cpu_architecture.md`.

**Speaker note:** Emphasize that the instruction increases useful work per
instruction while preserving normal in-order retirement.

## 5. Arithmetic pipeline result

**Key message:** Register-resident DOT4ACC sustains II=1.

- N=128 register-resident DOT: 43 cycles.
- Same-rd DOT chain: II=1.
- N=64 register-resident result: 27 cycles.

**Suggested evidence:** Stage K performance hierarchy.

**Speaker note:** This is arithmetic-level performance, before memory and
program overhead.

## 6. Memory bottleneck and Stage H

**Key message:** Feeding the arithmetic was the dominant optimization problem.

- H0 N=128: 294 cycles, model `9K+6`.
- One deferred completion entry and selective second-LOAD admission.
- H1.3b N=128: 263 cycles, model `8K+7`.

**Suggested evidence:** Stage H cycle progression table.

**Speaker note:** At N=128 there are 31 admissions, transfers, BRAM reads, and
completions, with zero duplicate/lost transactions.

## 7. Physical timing challenge

**Key message:** Functional acceleration and timing closure are separate
engineering constraints.

- T0/T1/T2/T3 WNS: -1.865/-1.525/-0.623/-0.920 ns at 100 MHz.
- T2 was retained as the best timing-equivalent implementation.
- Final validated point: 93 MHz PASS 5/5; 94 MHz failed.

**Suggested evidence:** final timing-recovery table and critical-path report.

**Speaker note:** The final frequency is a repeatably validated operating
point, not an exact mathematical Fmax.

## 8. Stage I measurement decision

**Key message:** Not every possible overlap is worth implementing.

- Independent scalar/DOT serialization was measured.
- Realistic memory-shaped opportunity was about two cycles.
- Stage I was NO-GO; no RTL was created.

**Suggested evidence:** Stage I report.

**Speaker note:** This is evidence of measurement-driven scope control.

## 9. Representative AI workloads

**Key message:** Complete programs achieve useful but lower throughput than
the arithmetic microbenchmark.

- J1 N=128: 358 cycles, 33.2514 MMAC/s, result `0x000028e5`.
- J2 2x64: 331 cycles, 35.9637 MMAC/s.
- J2 outputs: `0x000024e5`, `0x0000bf7b`.

**Suggested evidence:** Stage J results table.

**Speaker note:** Loads, pointer updates, control, BRAM latency, and stores are
included in the timing boundary.

## 10. Final same-workload comparison

**Key message:** DOT4ACC materially reduces arithmetic work relative to MAC8.

- Same deterministic 128-product workload and golden result `0x00004f25`.
- MAC8: 134 cycles; DOT4ACC: 43 cycles.
- DOT4ACC is 3.1163x faster, with 75% fewer arithmetic instructions.

**Suggested evidence:** Stage L comparison table.

**Speaker note:** No scalar same-workload speedup is claimed because the ISA
lacks general multiply, shift, and byte extraction.

## 11. Final implementation and lessons

**Key message:** The finished design is small, measurable, and physically
characterised.

- 93 MHz PASS 5/5; 2008 LUT, 1812 FF, 2 RAMB18, 5 DSP48.
- Arithmetic acceleration alone does not remove feed/control overhead.
- Routing/control paths matter as much as DSP arithmetic.

**Suggested evidence:** final resource/timing table.

**Speaker note:** Distinguish the same-hardware runtime comparison from a
hypothetical scalar-only area comparison.

## 12. Closure and thesis direction

**Key message:** The summer-project architecture is frozen and provides a
reproducible thesis baseline.

- Immutable tag: `summer-project-final`.
- Future work should study memory feeding, timing, or scalable AI execution.
- No thesis RTL is part of this milestone.

**Suggested evidence:** [`docs/thesis_extension_plan.md`](thesis_extension_plan.md)
and [`docs/post_summer_project_handoff.md`](post_summer_project_handoff.md).

**Speaker note:** End with the measured result and the research question it
opens, not with an unimplemented feature claim.
