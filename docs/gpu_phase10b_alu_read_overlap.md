# Stage 10B-A — Safe ALU/read prefetch overlap

Stage 10B-A is an independent functional experiment derived from the frozen
Stage 10A dual-entry controller.  Stage 10A proved that two prefetched vectors
can coexist, but its conservative policy issued reads only from VSTORE cycles;
the unchanged workloads therefore recorded no architectural prefetch hits.

## Scope

The new `vector_alu_prefetch_program_core` permits one safe prefetch request
during a valid ALU instruction when the synchronous data-memory read port is
otherwise idle.  VSTORE/read overlap is retained.  No ISA, memory-port,
register-file, lane, or entry-count changes are made.

The normal architectural VLOAD miss read remains highest priority.  ALU and
the prefetch datapath are independent, but the memory interface still accepts
at most one new read request per cycle.  Pending reads use the same explicit
address/slot state and return path as Stage 10A.  Candidate selection retains
the Stage 10A duplicate and intervening-store checks, and buffered hits remain
qualified by `is_vload` so an ALU instruction cannot consume a prefetch entry.

Each entry records whether its request originated on an ALU cycle.  This makes
the targeted ALU-issued-hit proof observable through `alu_prefetch_hit_count`.

The functional testbench's one-read check is defined at the arbitration
boundary: an architectural VLOAD read intent and a speculative prefetch intent
must never be true together.  Consecutive cycles with one read each are legal
for the synchronous single-port memory and are not double-read violations.
The ALU dependency test uses the actual lane-wise VXOR result and the no-free
slot test holds both entries valid while a later distinct candidate is visible.

The no-free-capacity acceptance event is defined in terms of slot ownership:
one valid entry plus the one outstanding pending-read reservation can occupy
both slots before the pending response asserts its valid bit.  TEST 12 latches
that reachable event and verifies that no additional speculative command is
issued.  A both-valid ALU observation was not required because, with four-slot
lookahead and one outstanding read, the first architectural VLOAD can consume
the first entry before the second response becomes visible.

The benchmark's `MAX_VALID_ENTRIES` value is a testbench observation, not an
RTL counter.  Its original implementation only assigned 2 when both entries
were valid simultaneously, leaving the reported value at 0 when entries were
filled and consumed without overlapping validity.  The benchmark monitor now
tracks the maximum of the number of valid entries (0, 1, or 2) on every clock;
workloads, cycle counting, and RTL counters are unchanged.

The functional debug pass also prints TEST 06's encoded instructions and lane
operands.  Its expected result is VADD lanes `(6,8,10,12)` followed by VXOR
with V1 lanes `(1,2,3,4)`, giving lane order `(7,10,9,8)` and packed value
`128'h00000008_00000009_0000000A_00000007`.  TEST 12 now issues its first
prefetch at PC0, the second at PC2 after the first return, and observes both
entries full at PC3 before the first load is consumed.

## Functional proof

`tb/vector_alu_prefetch_program_core_tb.sv` contains named overlap, hit,
dependency, safety, reset, invalid-instruction, and one-read-per-cycle tests.
The central sequence issues a prefetch from an ALU cycle, waits for synchronous
return, and executes a future VLOAD that consumes the buffered vector.

Full Stage 10A acceptance (26/26) remains the frozen-baseline regression.
Benchmark, synthesis, and timing characterization are intentionally deferred
to Stage 10B-B/C.

## Environment status

The repository-side implementation and build scripts are present, but this
workspace does not provide Vivado/XSim, Icarus, Verilator, or another
SystemVerilog simulator.  Consequently functional, equivalence, synthesis,
and post-route results must be obtained in the FPGA/Vivado environment before
Stage 10B or Stage 10 can be marked PASS.

## Limitations and next step

Only the prefetch opportunity policy changes.  There is still one synchronous
read port, bounded four-slot lookahead, and no ALU/read overlap for invalid or
memory-conflicting instructions.  After the functional proof passes, run the
unchanged Stage 8/9/10A workloads to determine whether useful ALU-issued hits
translate into cycle-count improvement.
