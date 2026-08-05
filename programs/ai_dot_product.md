# Signed INT8 Dot-Product Benchmark

These two hand-encoded programs calculate the same four-element dot product:

```text
a = [ 3, -2,  5, -4]
b = [-3,  4, -1, -2]
dot(a, b) = -9 - 8 - 5 + 8 = -14
```

Both programs store the 32-bit result `0xffff_fff2` at data-memory byte
address 0. The benchmark is intentionally unrolled so its static and retired
instruction counts are unambiguous.

## Existing-ISA baseline

File: `programs/ai_dot_product_baseline.mem`

The baseline initializes eight source registers and `x9` as the accumulator,
then implements multiplication with repeated signed addition or subtraction.
It uses only instructions that existed before the AI extension.

| Words | Work | Count |
| --- | --- | ---: |
| 0-8 | Initialize sources and accumulator with `ADDI` | 9 |
| 9-22 | Four products using repeated `ADD`/`SUB` | 14 |
| 23 | Store the result | 1 |
| 24 | Trailing NOP | 1 |

The arithmetic kernel is 14 instructions; execution through the result store
is 24 retired instructions.

## MAC8 version

File: `programs/ai_dot_product_mac.mem`

The MAC version has the same nine initialization instructions, followed by:

```text
MAC8 x9, x1, x2
MAC8 x9, x3, x4
MAC8 x9, x5, x6
MAC8 x9, x7, x8
STORE x9, [x0 + 0]
```

The arithmetic kernel is four instructions; execution through the result
store is 14 retired instructions. Cycle counts are measured by
`tb/tb_cpu_core_pipeline_mac.sv` and recorded in
`docs/ai_optimization_plan.md`.
