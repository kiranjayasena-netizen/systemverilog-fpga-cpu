# GPU Stage 9 - Memory Prefetch Optimisation

Stage 9 is a separate optimization core; the Stage 7/8 baseline remains
unchanged. The ISA is unchanged. The measured Stage 8 bottleneck was memory
latency: array addition spent 20 of 24 cycles in VLOAD/VSTORE operations,
while register-only VADD reached four lane additions per cycle.

## Architecture

`rtl/vector_prefetch_program_core.sv` reuses the existing instruction memory,
memory decoder, vector data memory, and vector execution unit. It adds one
pending prefetch entry containing an address and valid state. The next
sequential instruction is decoded combinationally.

When the current instruction is an ALU operation or VSTORE and the next slot
is VLOAD, the core issues the next data-memory read early. The Stage 6 memory
supports one read and one write on the same edge, so a VSTORE can overlap this
read. No speculative register write occurs.

The first VLOAD is a miss and retains Stage 7's request/writeback sequence.
A matching prefetched VLOAD consumes the registered memory result and commits
in one execution step. Prefetch state is cleared on reset, program start,
completion, idle external data access, and hit consumption. A store to the
prefetched address is excluded from prefetch issue, preventing stale data.

## Correctness and equivalence

The self-checking `tb/vector_prefetch_program_core_tb.sv` covers register-only
ALU execution, array addition, XOR and VSRA transforms, address-independent
results, dependency chains, and packed lane ordering. The same Stage 8
programs produce the same architectural results on the baseline and optimized
cores. Invalid slots and normal VLOAD misses retain baseline behavior.

Observed counters for the memory workloads were three prefetch requests,
three hits, one compulsory miss, and three store/read overlaps. There were no
ALU/read overlaps because the one-entry policy deliberately schedules reads
only after stores; this is conservative and avoids competing with a current
load.

## Performance comparison

| Metric | Stage 8 baseline | Stage 9 prefetch |
|---|---:|---:|
| Register-only VADD cycles | 4 | 4 |
| Array-add cycles | 24 | 21 |
| Array-add cycles/vector | 6.000 | 5.250 |
| Array-add cycles/scalar element | 1.500 | 1.3125 |
| Array-add scalar additions/cycle | 0.666667 | 0.761905 |
| Array-add ALU fraction | 0.166667 | 0.190476 |
| XOR transform cycles | 16 | 13 |
| VSRA transform cycles | 16 | 13 (same one-load/ALU/store schedule) |

At the validated 80 MHz implementation point, array addition improves from
53.333 to 60.952 Madd/s (+14.29%). XOR and VSRA improve from 80.000 to
98.462 million lane elements/s. These are lane-element rates, not CPU speedup
claims or external DDR bandwidth.

## Physical implementation

The Stage 9 top was implemented for `xc7a35tcpg236-1` with
`scripts/run_vector_stage9_80mhz_impl.tcl` and a 12.500 ns clock constraint.

| Resource/timing metric | Stage 8 | Stage 9 |
|---|---:|---:|
| LUT | 2784 | 2847 |
| FF | 1039 | 1142 |
| LUTRAM | 12 | 20 |
| RAMB36 | 2 | 2 |
| DSP48 | 0 | 0 |
| 80 MHz setup WNS | +0.155 ns | +0.138 ns |
| 80 MHz setup TNS | 0 ns | 0 ns |
| 80 MHz hold WNS | +0.263 ns (Stage 8) | report retained in timing summary |

The optimization costs 63 LUT (+2.26%), 103 FF (+9.91%), and 8 additional
LUTRAM, with no BRAM or DSP increase. Stage 9 remains an 80 MHz PASS; no
higher frequency claim is made.

The worst Stage 9 setup path starts at `core/current_pc_reg[2]/C` and ends in
the vector-register file. Data delay is 12.231 ns (3.512 ns logic, 8.719 ns
routing, 13 logic levels), so routing remains the dominant physical concern.

## Recommendation and limitations

The one-entry prefetch demonstrates a useful 3-cycle reduction on the
four-vector array add without ISA changes or extra BRAM. The remaining
limitation is that only one sequential read can be in flight and ALU/read
overlap is intentionally conservative. A future stage may study a small
multi-entry scheduler or carefully verified ALU/read overlap. VMUL is not yet
justified by these memory-shaped measurements and is not implemented here.
