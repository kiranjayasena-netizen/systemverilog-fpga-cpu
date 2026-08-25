# Stage L — Final Scalar / MAC8 / DOT4ACC Comparison

## 1. Scope and frozen CPU

Stage L evaluates the frozen H1.3b/T2 CPU at its validated 93 MHz operating
point. No RTL, constraints, memory sizes, or pipeline controls changed. The
physical basis is 2008 LUT, 1812 FF, 2 RAMB18, 5 DSP48, 1 BUFG, 0 latches;
93 MHz is PASS 5/5 and 94 MHz is the nearest tested failure.

## 2. ISA feasibility result

The final ISA provides ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ, JUMP,
MAC8, DOT4ACC, and NOP. It has no scalar multiply, shift, byte extract, or
variable rotate instruction. Consequently, arbitrary signed-int8 products
from the Stage J N=128 dataset cannot be expressed compactly as scalar code.

A supported-instruction repeated-add/sign-detection prototype was attempted;
it did not complete within 1,000,000 cycles. A register-resident scalar
sequence using only ADD/SUB also did not produce the golden result on the
frozen T2 instance, so it is explicitly excluded from speedup claims. No
precomputed products were substituted.

This is a measured ISA limitation, not a request to add a scalar multiply.
The strongest valid same-CPU comparison is therefore the deterministic
register-resident equivalent between MAC8 and DOT4ACC, with the scalar result
reported as unavailable. The historical 29-cycle scalar / 19-cycle MAC8
figure remains context only because it used a different historical execution
setup and is not a fair Stage L N=128 comparison.

## 3. Fair equivalent workload

All valid Stage L implementations use the same deterministic signed-int8
pattern repeated 32 times:

```text
A = [ 3, -2,  1, -1 ]
B = [127,-128,  0,  5 ]
accumulator = 37
```

Each implementation performs exactly 128 products and accumulates modulo
32 bits. The independent golden result is `0x00004f25`.

- Scalar fallback: seven ADD/SUB instructions per four-lane group; invalid
  on T2 and excluded from accepted comparison.
- MAC8: 128 MAC8 instructions, cycling through four register pairs.
- DOT4ACC: 32 DOT4ACC instructions using packed registers.

Timing begins after reset/program/register initialization and ends at final
STORE retirement for every run. Initialization is outside the timed region for
all cases.

## 4. Valid measured comparison

| Metric | Scalar fallback | MAC8 | DOT4ACC |
|---|---:|---:|---:|
| Useful MACs | 128 | 128 | 128 |
| Golden result | `0x00004f25` | `0x00004f25` | `0x00004f25` |
| Valid result | No | Yes | Yes |
| Cycles | 230* | 134 | 43 |
| Retired instructions | 225* | 129 | 33 |
| LOAD | 0 | 0 | 0 |
| STORE | 1 | 1 | 1 |
| Arithmetic instructions | 225* | 128 | 32 |
| MAC8 instructions | 0 | 128 | 0 |
| DOT4ACC instructions | 0 | 0 | 32 |
| MAC/cycle | invalid | 0.955224 | 2.976744 |
| MMAC/s @93 MHz | invalid | 88.8358 | 276.8372 |
| Execution time | invalid | 1.44086 µs | 0.462366 µs |

`*` Scalar values are retained only as an invalid fallback diagnostic: the
stored result was `0x00000205`, not the golden result, and must not be used for
speedup calculations.

Valid same-work speedups at 93 MHz:

- DOT4ACC versus MAC8: `134 / 43 = 3.1163x`.
- Arithmetic instruction reduction: `1 - 32/128 = 75.0%`.
- Retired-instruction reduction: `1 - 33/129 = 74.4%`.
- Useful MACs per retired instruction: MAC8 `0.9922`; DOT4ACC `3.8788`.

The comparison demonstrates the benefit of four-lane arithmetic without
claiming an unsupported scalar baseline.

## 5. Stage J and Stage H context

The same frozen CPU's complete-program results are:

| Workload | Cycles | Useful MACs | MAC/cycle | MMAC/s @93 MHz |
|---|---:|---:|---:|---:|
| Stage H memory-fed N=128 | 263 | 128 | 0.486692 | 45.2624 |
| Stage J J1 N=128 | 358 | 128 | 0.357542 | 33.2514 |
| Stage J J2 2×64 | 331 | 128 | 0.386707 | 35.9637 |

These include loads, pointer/control work, BRAM latency, and final stores.
The register-resident 2.976744 MAC/cycle DOT figure is therefore an arithmetic
microbenchmark, not an application throughput claim. Stage H and Stage J show
how memory and program overhead reduce the realized rate.

## 6. Fairness audit

- Same final T2 CPU and 93 MHz basis: yes.
- Same signed-int8 values and modulo-32-bit accumulation: yes for MAC8/DOT.
- Same useful products: 128 for both valid implementations.
- Same timing boundary: yes, first post-reset instruction through final STORE.
- Same final golden result: yes, `0x00004f25`.
- Precomputed products: none.
- Scalar exception: direct arbitrary-data scalar multiplication is not
  expressible compactly in the implemented ISA; the failed prototype is not
  presented as a performance result.

## 7. Regressions and limitations

Stage H/T2 benchmark evidence remains 233/0 with 39/71/135/263 cycles,
`8K+7`, 31/31/31/31 ownership counts, register DOT 27/43, and II=1. Stage J
golden outputs remain `0x000057ba`, `0x000024e5`, `0x000028e5`, and
`0x000024e5`/`0x0000bf7b`. Retained regressions are A1 306/0, A2 2859/0,
C 1468/0, D 3945/0, Stage G 4258/0, Stage E 233/0, MAC8 29/19 with
`0xfffffff2`, and Phase12 457 cycles/319 retired.

Limitations are the scalar ISA's lack of multiply/shift/byte extraction, the
256-word instruction memory, and the fact that runtime comparisons all include
the full mixed-capability T2 hardware rather than hypothetical scalar-only
area. No new Vivado run was required.

## Final conclusion

For a fair equivalent register-resident workload, DOT4ACC is 3.1163× faster
than MAC8 and reduces arithmetic and retired instruction counts by about 75%.
A fair arbitrary-data scalar N=128 comparison is not expressible on the frozen
ISA without inventing functionality, so no scalar speedup is claimed. The
final CPU architecture remains unchanged and frozen.

**STAGE L COMPLETE — FINAL COMPARATIVE EVALUATION COMPLETE — ARCHITECTURE REMAINS FROZEN**
