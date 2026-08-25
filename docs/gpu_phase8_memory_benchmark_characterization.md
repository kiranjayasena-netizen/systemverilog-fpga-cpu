# GPU Stage 8 - Memory-Processing Benchmark Characterization

Stage 8 characterizes the existing Stage 7 memory-enabled four-lane SIMD
core. No functional RTL or instruction semantics were changed.

## Method and cycle model

The benchmark testbench (`tb/vector_memory_program_core_benchmark_tb.sv`)
loads registers, data memory, and instruction memory before timing starts.
Timing begins after the `start` pulse has launched a run and counts rising
clock edges until `done` is observed after the final architectural effect.
Preload cycles are excluded. The measured Stage 7 model is:

| Instruction | Execution cost |
|---|---:|
| ALU instruction | 1 cycle |
| VSTORE | 1 cycle |
| VLOAD | 2 cycles (read request plus register writeback) |
| Invalid slot | 1 cycle, no architectural write |

## Benchmark results

All results below passed their independent output checks.

| Workload | Vectors | Scalar elements | VLOAD | VSTORE | ALU ops | Cycles | Cycles/vector | Cycles/element | Useful scalar ops/cycle | ALU fraction | Logical bytes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Register-only VADD chain | 4 | 16 | 0 | 0 | 4 | 4 | 1.000 | 0.250 | 4.000000 | 1.000000 | 0 |
| Four-vector array add | 4 | 16 | 8 | 4 | 4 | 24 | 6.000 | 1.500 | 0.666667 | 0.166667 | 192 |
| Four-vector XOR transform | 4 | 16 | 4 | 4 | 4 | 16 | 4.000 | 1.000 | 1.000000 | 0.250000 | 128 |
| Four-vector VSRA transform | 4 | 16 | 4 | 4 | 4 | 16 | 4.000 | 1.000 | 1.000000 | 0.250000 | 128 |

The array-add program is:

```text
for each chunk i = 0..3:
    VLOAD  V1,[i]
    VLOAD  V2,[8+i]
    VADD   V3,V1,V2
    VSTORE [16+i],V3
```

It performs 16 scalar additions in 24 cycles, or 1.5 cycles per scalar
element and 0.666667 useful scalar additions per cycle. Each chunk moves
48 logical bytes (two 16-byte loads plus one 16-byte store), or 12 bytes per
scalar addition.

The XOR and VSRA transforms each perform one load, one ALU operation, and one
store per vector. Their checks cover lane-independent data and exact packed
128-bit results.

## Stage 7 physical implementation at 80 MHz

The unchanged Stage 7 synthesis top was implemented for
`xc7a35tcpg236-1` with a 12.500 ns clock constraint using
`scripts/run_vector_stage8_80mhz_impl.tcl`.

| Metric | Post-route result |
|---|---:|
| Clock target | 80 MHz (12.500 ns) |
| Setup WNS | +0.155 ns |
| Setup TNS | 0 ns |
| Setup failing endpoints | 0 |
| Hold WNS | +0.263 ns |
| Hold TNS | 0 ns |
| Timing status | PASS |
| LUT | 2784 |
| Logic LUT | 2772 |
| LUTRAM | 12 |
| FF | 1039 |
| RAMB36 | 2 |
| RAMB18 | 0 |
| DSP48 | 0 |

This is a validated 80 MHz implementation point, not an Fmax claim. No
100 MHz Stage 8 implementation was run.

The worst setup path starts at `core/current_pc_reg[1]/C` and ends in the
vector-register-file state. Its post-route data delay is 12.242 ns, with
3.462 ns logic delay and 8.780 ns routing delay across 12 logic levels. The
dominant category is therefore the PC/sequencer-to-decode/register datapath,
with routing (about 72%) larger than logic delay. This is consistent with a
long control path through instruction memory/decode, source selection, ALU
control, and register writeback rather than a standalone BRAM path.

## Resource interpretation

The Stage 5A post-route reference was 2284 LUT, 1035 FF, zero RAMB36, and
zero DSP48. Stage 7 is 500 LUT higher at this post-route point (+21.89%),
four FF higher (+0.39%), and adds two RAMB36 blocks. The Stage 7 synthesis
report (2953 LUT) is retained separately; the comparison above uses
post-route totals consistently.

Hierarchical post-route utilization attributes 2591 LUT and 1024 FF to the
vector execution unit/register file, 102 LUT (12 LUTRAM) to the 16 x 16
instruction memory, and 78 LUT plus two RAMB36 to the vector data memory.
No DSP48 is inferred. The 32 x 128 data memory remains block RAM, while the
small instruction memory is distributed RAM (12 LUTRAM).

At 80 MHz, illustrative useful rates are:

* register-only arithmetic: 320 lane additions/s (320 Madd/s);
* array add: 53.333 Madd/s;
* XOR and VSRA transforms: 80 million 32-bit lane elements/s.

The array-add logical traffic rate is 192 bytes / (24/80 MHz) = 640 MB/s;
this is an on-core logical traffic estimate, not external DDR bandwidth.

## Bottleneck and next-stage recommendation

Register-only arithmetic reaches four lane operations per cycle, while the
memory-backed array add reaches only 0.666667 useful lane operations per
cycle and spends 20 of 24 cycles in loads/stores. The measured ALU fraction
is 1/6 for array addition versus 1/4 for unary transforms. Together with the
post-route routing-dominated control path, this indicates that memory
latency/control and feed efficiency are the immediate bottlenecks, not a lack
of arithmetic width. The recommended next architecture study is therefore
memory-throughput optimisation (overlap, scheduling, or prefetch research),
not VMUL implementation. No such optimization is implemented in Stage 8.

No CPU-versus-SIMD workload speedup is claimed. The frozen CPU figures are
provided only as separate resource context and are not an apples-to-apples
benchmark comparison.

## Reproduction and artifacts

Run the benchmark with Vivado XSim by compiling the Stage 7 RTL plus
`tb/vector_memory_program_core_benchmark_tb.sv`. The 80 MHz implementation
is reproduced by `scripts/run_vector_stage8_80mhz_impl.tcl` and
`constraints/vector_memory_program_core_stage8_80mhz.xdc`; reports are under
`reports/vector_stage8/`.

Stage 8 deliberately adds no VMUL, branches, masks, additional lanes,
pipeline, scheduler, cache, DMA, or CPU connection.
