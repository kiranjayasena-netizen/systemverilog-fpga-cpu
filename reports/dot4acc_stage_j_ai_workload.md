# Stage J — Representative AI Workload

Stage J evaluates the frozen H1.3b/T2 CPU as an application processor. No CPU
RTL, constraints, or timing implementation was changed.

## Frozen baseline

Stage H remains H1.3b with the T2 timing-equivalent implementation, validated
at 93 MHz (PASS 5/5). Its N=128 memory-feed microbenchmark is 263 cycles
(8K+7), with 31 second-LOAD admissions/transfers/BRAM reads/completions.
Stage I remains NO-GO; no scalar/DOT overlap architecture was reopened.

## ISA and data representation

The benchmark uses the repository's custom encodings: `LOAD` (opcode 7),
`STORE` (8), `ADDI` (6), `DOT4ACC` (c), and NOP padding. Addresses are byte
addresses and the BRAMs index `addr[9:2]`. `DOT4ACC rd,rs1,rs2` performs four
signed int8 lane products from bits [7:0], [15:8], [23:16], and [31:24],
accumulating modulo 32 bits.

Packed words use lane 0 in bits [7:0]. Data is deterministic: the A vector is
`((37*i+17) mod 251)-125` with explicit 127, -128, -1, and 1 boundary values;
the B vector is `((53*i+91) mod 251)-125` with deterministic zeros and signed
boundaries. The golden model independently sign-extends each byte and performs
32-bit modular accumulation.

## Workloads and layout

J1 is a complete 32/64/128-element dot product. Input A starts at word 0 and B
at word 32 (byte address 128). Each block executes two LOADs, one DOT4ACC, and
two independent pointer ADDIs, then stores the result at byte address 252.

J2 is a two-output 64-element matrix-vector product (the largest simple
unrolled form that fits the 256-word instruction memory). A 4x128 unrolled
program would exceed that instruction depth. Input words occupy 0..15, weight
rows occupy 32..47 and 48..63, and outputs are stored at words 100 and 101
(byte addresses 400 and 404). Each row has 16 DOT4ACC operations (64 MACs).

Timing starts on the first enabled clock after reset/program initialization and
ends when the final architectural STORE retires. Initialization is excluded
because it is testbench loading, not CPU execution.

## Results

| Benchmark | Cycles | Retired | LOAD | STORE | DOT | Scalar | Branch | MAC/cycle | MMAC/s @93 MHz | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| J1 N=32 | 94 | 41 | 16 | 1 | 8 | 16 | 0 | 0.340426 | 31.6596 | PASS |
| J1 N=64 | 182 | 81 | 32 | 1 | 16 | 32 | 0 | 0.351648 | 32.7033 | PASS |
| J1 N=128 | 358 | 161 | 64 | 1 | 32 | 64 | 0 | 0.357542 | 33.2514 | PASS |
| J2 2x64 | 331 | 134 | 64 | 2 | 32 | 32 | 0 | 0.386707 | 35.9637 | PASS |

Golden results (hexadecimal 32-bit): J1 N=32 `000057ba`, N=64 `000024e5`,
N=128 `000028e5`; J2 outputs `000024e5` and `0000bf7b`. All stored results
matched exactly. Useful work is 128 MACs for J1 N=128 and 128 MACs for J2.

The observed aggregate hold counter was 48/96/192 cycles for J1 N=32/64/128
and 192 for J2. These are pipeline/memory-feed holds, not silently removed
from the full-program timing window. No branch instructions are needed by the
unrolled kernels; scalar/control work is explicitly counted.

J1 N=128 is 95 cycles above the 263-cycle Stage H microbenchmark (+36.1%).
That difference is not a pure kernel penalty: J1 performs a second independent
LOAD stream and 64 pointer-update ADDIs, whereas the Stage H loop uses the
minimal memory-feed sequence. It therefore measures complete-program cost.
J1 scaling is consistent with a fixed startup plus approximately linear
per-four-lane work; larger N amortizes fixed fill/drain cost, while scalar
pointer work remains visible. J2 completes two outputs in 331 cycles (165.5
cycles/output) and exposes the cost of application-level loads and control
around useful DOT work.

## Verification and physical status

The Stage J XSim testbench compiled and passed for all four workloads, including
independent signed-int8 golden checks. Existing individual regressions remain
the established passing results: A1 306/0, A2 2859/0, C 1468/0, D 3945/0,
Stage G 4258/0, Stage H 4254/0, Stage E 233/0, MAC8 29/19 with result
`0xfffffff2`, and Phase12 457 cycles/319 retired. Stage H invariants remain
39/71/135/263, 8K+7, 31/31/31/31, register 27/43, and DOT II=1.

No new Vivado run was required: Stage J uses the frozen H1.3b/T2 hardware
already validated at 93 MHz PASS 5/5. Stage J is an application measurement,
not an architecture optimization.

## Conclusion

The representative workload executes correctly and demonstrates full-program
AI-style throughput, instruction mix, and control/memory overhead at the
physically validated clock. Stage J is complete; Stage K/L work has not begun.
