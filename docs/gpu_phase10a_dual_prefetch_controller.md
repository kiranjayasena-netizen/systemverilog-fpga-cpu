# Stage 10A - Genuine Two-Entry Prefetch Controller

Stage 10A replaces the former compatibility shell with a standalone
controller containing two real prefetch entries and explicit pending-read
state. Stage 9 RTL is unchanged.

Each entry stores `valid`, a 5-bit address, and 128-bit data. A synchronous
read request records `pending_read_valid`, `pending_read_addr`, and a target
slot. The returned `read_data` is captured on the following clock and only
then marks the selected entry valid. At most one read request is generated per
cycle.

The current conservative policy uses VSTORE/read overlap only. A bounded
lookahead considers the next two instruction slots and selects a future VLOAD
when an entry is free. ALU/read overlap is intentionally not implemented;
that is Stage 10B. Duplicate addresses already valid or pending are
suppressed. VLOAD hits prioritize entry 0, consume exactly one entry, and
write the destination register only at the architectural execution edge.
Misses use the Stage 7 two-phase fallback.

The controller now includes bounded four-slot lookahead, duplicate-aware
candidate selection, intervening-store address checks, and debug visibility
of both entries and pending state. The self-checking XSim test demonstrates
the two-entry request path and passes. However, the complete acceptance matrix
(isolated entry-specific hits, stale pending-read cancellation, all store
invalidation cases, full Stage 8/9 equivalence, and physical synthesis) still
requires completion before declaring Stage 10A complete.

## Second-entry scheduling debug

The failing targeted sequence initially produced only one request because the
test placed the second VSTORE immediately while the first synchronous read was
still pending. In addition, candidate validity and candidate-address
selection were separate expressions: a later eligible VLOAD could make
`candidate_valid` true while `candidate_addr` still selected the earlier
duplicate slot. The request was therefore either blocked by pending state or
repeated the already-selected address.

The controller now derives `candidate_addr` from the same eligible-slot
signals (`c1` through `c4`) used by `candidate_valid`, so duplicate slots are
skipped and scanning continues. The targeted proof inserts the minimum idle
instruction after the second request opportunity, allowing the synchronous
return to fill entry 0 before entry 1 is reserved. The observed result is:

```text
prefetch requests = 2
entry-0 hits       = 1
entry-1 hits       = 1
max valid entries  = 2
```

The two entries hold distinct vectors at the same time and are then consumed
independently. This is a targeted debug result only; the full Stage 10A
acceptance, benchmark, synthesis, and timing stages remain future work.

## Stage 10A-V1C functional acceptance closure

The acceptance testbench was expanded to 26 independently reported tests and
run in XSim. Individual checks are non-fatal so the complete suite executes
even when a diagnostic mismatch occurs. The initial full run identified two
testbench issues and one RTL correctness issue:

* TEST 04 originally placed its second store while the first synchronous read
  was pending, so entry 1 could not fill. The test was corrected to use the
  proven safe spacing; the controller then filled both entries.
* TEST 12's arithmetic expectation was checked against the architectural RF
  state after the miss writeback; the miss path and dependent VADD produce the
  expected lane-wise sum.
* A genuine hit qualification bug was found in the Stage 10A RTL. A buffered
  address of zero could assert `prefetch_hit` during a following ALU
  instruction because non-memory instructions decode `mem_addr` as zero. The
  minimal fix qualifies both hit signals with `is_vload`, preventing load
  write priority from overwriting an ALU result.

Final XSim result:

```text
Tests run: 26
Tests failed: 0
VECTOR DUAL PREFETCH PROGRAM CORE TEST PASSED
```

The suite covers ordinary miss fallback, both entry-specific hits and
independent consumption, duplicate/pending suppression, VSTORE/read overlap,
current/intervening store safety, store invalidation, pending stale-read
discard, miss/hit dependency cases, ALU-to-store dependency, no early
architectural register write, addresses 0 and 31, lane order, final load and
store, invalid instructions, reset/restart, external idle memory update, and
the one-read-per-cycle acceptance check. Stage 1 through Stage 7 regressions
were rerun and passed (20/20 ALU, 22/22 execution unit, 18/18 decoder,
24/24 integration, 25/25 programmable core, 24/24 data memory, and 22/22
memory core).

This closes the V1 functional-acceptance task. Architectural equivalence,
unchanged Stage 8/9 benchmark regression, synthesis, and 80 MHz
characterisation remain Stage 10A-V2/V3 work. ALU/read overlap remains
deferred to Stage 10B.

## Stage 10A-V2 - equivalence and unchanged benchmark regression

The paired harness `tb/vector_stage9_stage10a_equivalence_tb.sv` ran six
representative programs on Stage 9 and Stage 10A with identical instruction,
register, and data-memory initialization. Architectural register and touched
memory results matched in every case: dependent ALU operations,
load/load/add/store, multiple memory operations, a store hazard, invalid
instruction handling, and restart.

Result: `STAGE 9 / STAGE 10A ARCHITECTURAL EQUIVALENCE PASSED`.

The unchanged Stage 8/9 workloads measured on Stage 10A were: register-only
VADD 4 cycles, array add 24 cycles, XOR 16 cycles, and VSRA 16 cycles. The
Stage 8 / Stage 9 references are 4/4, 24/21, 16/13, and 16/13 cycles. Thus
the conservative Stage 10A schedule did not improve these workloads over
Stage 9; the unchanged benchmark schedule generated only two prefetch
requests and no useful entry hits in this run.

| Workload | Stage 8 | Stage 9 | Stage 10A |
|---|---:|---:|---:|
| Register-only VADD | 4 | 4 | 4 |
| Vector array add | 24 | 21 | 24 |
| XOR transform | 16 | 13 | 16 |
| VSRA transform | 16 | 13 | 16 |

The Stage 10A array-add rate is 0.666667 adds/cycle. At 80 MHz this is
53.333 MAdds/s projected only; physical 80 MHz validation belongs to V3.
XOR and VSRA are 1.000000 lane-elements/cycle, or 80.000 million lane
elements/s projected at 80 MHz. Dual-entry buffering alone therefore gives no
measured throughput gain on the unchanged workloads. Safe ALU/read overlap
remains the separate Stage 10B question and was not implemented.

## Stage 10A-V3 - physical characterization and closure

The frozen Stage 10A core was synthesized and implemented for
`xc7a35tcpg236-1` with Vivado 2026.1. Post-synthesis utilization was 3197 LUT
(3153 logic LUT, 44 LUTRAM), 1416 FF, 2 RAMB36, 0 RAMB18, and 0 DSP48.
Post-route utilization was 3024 LUT (2980 logic LUT, 44 LUTRAM), 1416 FF,
2 RAMB36, 0 RAMB18, and 0 DSP48. The 32x128 vector data memory remained two
RAMB36E1 blocks; the small instruction memories used RAM32M/LUTRAM-style
resources. The two retained prefetch vectors used controller FF/LUT resources
and no additional BRAM.

The 80 MHz implementation passed: setup WNS +0.414 ns, TNS 0, zero setup
failures; hold WNS +0.059 ns, TNS 0, zero hold failures. The worst setup path
was `core/current_pc_reg[0]` to
`core/eu/vector_register_file_inst/regs_reg[5][96]/D`, with 11.991 ns data
delay: 3.346 ns logic and 8.645 ns routing across 13 logic levels. Routing
was 72.1% of the path, so the design remained routing-dominated.

Relative to Stage 9 (2847 LUT, 1142 FF, 20 LUTRAM, 2 RAMB36), Stage 10A
post-route adds 177 LUT (+6.22%), 274 FF (+23.99%), and 24 LUTRAM (+120%).
BRAM and DSP counts are unchanged. At the validated 80 MHz clock, measured
Stage 10A throughput is 320.000 MAdds/s for register-only VADD, 53.333
MAdds/s for array add, and 80.000 million lane-elements/s for XOR and VSRA.
The array-add figure is lower than Stage 9's 60.952 MAdds/s because the
unchanged Stage 10A schedule recorded no architectural prefetch hits.

Stage 10A is experimentally complete and physically closed, but the second
entry is a buffering/correctness capability rather than a measured throughput
optimization on these workloads. The evidence supports studying Stage 10B
bounded ALU/read overlap; Stage 10B is not implemented here.
