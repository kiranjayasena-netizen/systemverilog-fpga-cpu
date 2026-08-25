# Stage 12 — Two Outstanding Speculative Reads

Stage 12 is an independent derivative of the frozen Stage 11 depth-6
core. The ISA, in-order retirement, two prefetch data entries, one
physical synchronous read port, and vector memory are unchanged.

## Memory semantics

`vector_data_memory` captures `memory[read_addr]` on a rising edge when
`read_enable` is asserted and exposes that value as the response for the
following cycle. Responses are therefore fixed-latency and in order. Stage
12 uses a two-record FIFO: request 0 is the response head and request 1 is
the second outstanding request. One new physical read command is still
issued per cycle at most.

Each pending record reserves its destination prefetch slot. Candidate
selection rejects addresses in either valid entry or either pending record.
Current architectural VLOAD misses have priority over speculation. Stores
invalidate matching valid entries and mark matching pending responses stale;
stale data is discarded when the response arrives. Reset, restart, and
external memory loading clear both pending records and both entries.

## Verification

- Stage 12 functional suite: 46/46 PASS.
- Frozen Stage 11 depth-6 regression: 32/32 PASS.
- Frozen Stage 10B regression: 20/20 PASS.
- Frozen Stage 10A regression: 26/26 PASS.
- Stage 11 ↔ Stage 12 architectural equivalence: 10/10 PASS.

The functional monitor observed a second request while request 0 was still
pending and recorded an outstanding high-watermark of 2. The one-read-per-
cycle checker found no competing architectural/speculative read command.

## Unchanged benchmarks

| Benchmark | Cycles | Adds/elements per cycle |
|---|---:|---:|
| Register VADD | 4 | 4.000 adds/cycle |
| Array add | 21 | 0.761905 adds/cycle |
| XOR | 13 | 1.230769 lane-elements/cycle |
| VSRA | 13 | 1.230769 lane-elements/cycle |

Array counters were 3 ALU/read overlaps, 3 ALU-origin hits, 4 total
prefetch requests, 3 hits, one two-outstanding useful pair, and an
outstanding high-watermark of 2. Thus the second request is exercised, but
the unchanged array schedule remains at the Stage 11 cycle count of 21.

At 80 MHz these architectural counts correspond to 320 MAdds/s for the
register benchmark, 60.952 MAdds/s for array add, and 98.462 million
lane-elements/s for both XOR and VSRA.

## Physical characterization

Post-route resources: 3247 LUTs (3179 logic LUTs, 68 LUTRAM), 1522 FFs,
2 RAMB36, 0 RAMB18, and 0 DSP. At 80 MHz, setup WNS is +0.348 ns with
zero TNS/failing endpoints; hold WHS is +0.200 ns with zero THS/failing
endpoints. The worst setup path is `core/current_pc_reg[1]/C` to
`core/eu/vector_register_file_inst/regs_reg[4][64]/D`, 12.052 ns total
(3.240 ns logic, 8.812 ns routing, 73.116% routing, 12 logic levels).

The data memory remains two RAMB36E1 blocks and DSP usage remains zero.

## Verdict

Two outstanding requests are functionally supported and physically close
80 MHz without additional BRAM or DSP. They do not reduce the unchanged
benchmark cycle counts below Stage 11 (21/13/13), so the experiment is a
correctness/timing PASS but a partial performance result. Further
architecture should be driven by a measured bottleneck rather than adding
more speculative depth by assumption.
