# GPU Stage 10 - Dual-Prefetch/ALU-Overlap Assessment

Stage 10 preserves Stage 9 as the optimized functional baseline. A separate
`vector_dual_prefetch_program_core` shell and equivalence test were added, but
no unsafe two-entry speculative controller was introduced.

The existing memory has one synchronous read port and one write port. Two
prefetch entries cannot create two reads per cycle. A correct implementation
must also track pending read return, valid entries, duplicate addresses, and
intervening stores. The current Stage 9 controller already consumes the only
safe store/read overlap; adding deeper lookahead without a complete in-order
dependency controller would risk stale loads.

The Stage 10 shell therefore reports Stage 9-equivalent behavior and makes no
new performance claim. This is an explicit no-go for speculative ALU/read
overlap in this stage, not a claim that two entries were physically realized.

## Result

The Stage 10 compatibility test passes with unchanged ISA and architectural
behavior. Stage 9 remains the valid optimized result: four-vector array add
in 21 cycles, 0.761905 scalar additions/cycle, 80 MHz PASS. Stage 10 has no
independent post-route result because no new datapath/controller was accepted.

## Recommendation

Before implementing a real dual-entry scheduler, define a cycle-accurate
pending-read protocol and exact store-dependency checks, then characterize it
as a separate experiment. The one-read-port structural limit means additional
buffer entries alone cannot approach one vector result per cycle; additional
memory bandwidth or banking is the more fundamental research direction.
