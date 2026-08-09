# Stage H — Memory-feed optimisation

## H0 baseline accounting

The existing G3.1 architecture was measured without RTL changes. A deterministic, mutually exclusive cycle classifier was added to the Stage E benchmark. Priority is: LOAD-use stall, DOT frontend hold, DOT issue, DOT completion, DOT retirement, fetch/memory wait, then other.

| N | cycles | LOAD-use | DOT hold | fetch/wait | DOT retirement | other | sum |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 42 | 4 | 20 | 13 | 5 | 0 | 42 |
| 32 | 78 | 8 | 40 | 21 | 9 | 0 | 78 |
| 64 | 150 | 16 | 80 | 37 | 17 | 0 | 150 |
| 128 | 294 | 32 | 160 | 69 | 33 | 0 | 294 |

For K DOT operations, the measured decomposition is:

```text
K LOAD-use + 5K DOT-hold + (2K+5) fetch/wait + (K+1) retirement
= 9K + 6 cycles
```

For N=128, K=32: `32 + 160 + 69 + 33 = 294` exactly. The classifier found no unexplained residual cycles.

## H1.1 candidate status

The H1.1 successor adds an explicit dynamic ID/EX consumption token, a one-LOAD overlap reservation, and a deferred LOAD completion record. Deferred capture is based on the older DOT remaining architecturally pending, not only on a same-cycle RF collision. The normal MEM/WB payload is consumed on the capture edge.

Focused architectural verification passed 4,258 checks with zero failures. Register-resident Stage E checks also passed. The memory-fed cycles remained unchanged: 42, 78, 150 and 294. H1.1 therefore removed no end-to-end cycles; its category redistribution for N=128 was 32 LOAD-use, 129 DOT-hold, 38 fetch/wait and 95 retirement cycles. Because there was no material workload improvement, no Vivado implementation was run and the candidate is not retained as a performance improvement.

The candidate does establish the required ordering mechanisms: an overlapped LOAD cannot commit before its older DOT, deferred completion is consumed once, and the dynamic acceptance guard is not based on PC equality alone. A future H1.2 design should target the remaining frontend/retirement serialization rather than weaken these protections.

## H1.2 deferred LOAD-to-DOT forwarding

H1.2 was implemented in a separate successor and added only rs1/rs2 forwarding from a valid deferred LOAD. The deferred entry remained architecturally live; forwarding did not consume it. A DOT-only exception released the scalar hold only when the ID/EX DOT was ready and had no deferred accumulator dependency. Non-DOT instructions and additional LOADs remained blocked.

The focused H1.2 architectural suite passed 4,258 checks with zero failures, and the copied Stage E benchmark passed 233 checks with zero failures. However, memory-fed totals remained 42/78/150/294 cycles. N=128 therefore showed 0-cycle improvement over H1.1 and H0. The measured H1.2 decomposition remained 32 LOAD-use, 129 DOT-hold, 38 fetch/wait and 95 retirement cycles.

Because the primary checkpoint `N=128 < 294` was not met, no Vivado implementation was run. H1.2 is rejected as a performance candidate, although its forwarding and coexistence assertions remain useful evidence for a future narrowly scoped refinement.

## Preserved baseline

The Stage D/G3.1 RTL and DOT arithmetic remain unchanged. Stage E still passes 233 checks with the historical memory-fed results above. No H1 implementation result is claimed.

Next work should be a narrower H1 redesign based on an explicit LOAD overlap state machine; do not begin H2 or Stage I until that design is specified and verified.
