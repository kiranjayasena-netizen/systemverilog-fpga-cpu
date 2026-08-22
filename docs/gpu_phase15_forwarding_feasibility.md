# Stage 15 — Load-result forwarding feasibility

Stage 14 already hides the only independent miss/writeback opportunity in
the unchanged ARRAY_ADD workload. The remaining four misses are followed
immediately by `VADD V3,V1,V2`, with the loaded `V2` used as `srcB`.

Forwarding the returning memory vector directly to the ALU would make the
dependent calculation numerically possible during the load-return cycle.
It would not make the schedule shorter: the load still needs to write `V2`
through the single whole-vector RF write path, while the VADD needs to write
`V3`. Retiring both would violate `RF_WRITES_PER_CYCLE <= 1`.

Deferring the ALU result to a later buffer would only move the writeback
cycle, so it is not a Stage 15 success. The four cases therefore classify as
forwarding-only-conflict/RF-write-conflict. No Stage 15 RTL was created and
the best verified core remains Stage 14 at 20 ARRAY_ADD cycles.
