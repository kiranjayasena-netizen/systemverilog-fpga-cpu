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

## H1.3a second-LOAD ID/EX boundary experiment

H1.3a was derived from H1.2 in separate files and retained the one-entry deferred completion design. The proposed safe boundary is the existing `id_ex_reg`: a second LOAD may be admitted once, but while `deferred_load_valid` is occupied it must remain in ID/EX. Consequently it cannot transfer to `ex_mem_reg`, cannot assert the synchronous data-BRAM read enable, and cannot create a normal or deferred completion. The existing H1.2 scalar hold therefore supplies the required upstream backpressure; no second completion slot was added.

The corrected direct IF/ID diagnostic confirmed the reconstructed schedule. For N=16/32/64/128, second-LOAD IF/ID blocking was 12/28/60/124 cycles. Second-LOAD admissions were 0/0/0/0; exact second-LOAD ID/EX-held and pre-completion-held counts were 0/0/0/0. H1.2 deferred rs1/rs2 forwarding use and DOT issues while deferred were also 0 for all four sizes. Thus the realised program never reaches the state in which the second LOAD can be admitted under the restricted one-entry schedule; the experiment did not silently move those cycles into an ID/EX hold.

The H1.3a focused architectural suite passed 4,254 checks with zero failures, and the Stage E-derived benchmark passed 233 checks with zero failures. The unchanged memory-fed results were:

| N | cycles | LOAD-use | DOT hold | fetch/wait | retirement | second IF/ID blocked | second admitted | second ID/EX held |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 42 | 4 | 17 | 10 | 11 | 12 | 0 | 0 |
| 32 | 78 | 8 | 33 | 14 | 23 | 28 | 0 | 0 |
| 64 | 150 | 16 | 65 | 22 | 47 | 60 | 0 | 0 |
| 128 | 294 | 32 | 129 | 38 | 95 | 124 | 0 | 0 |

N=128 therefore improved by 0 cycles versus H0/H1.1/H1.2. The one-entry completion restriction is not yet reached by LOAD B; the dominant limitation remains the existing frontend/retirement serialization. Since the required `N=128 < 294` checkpoint was not met, no Vivado implementation was run and no second deferred entry was added. H1.3a is retained as a verified boundary experiment, not as a performance improvement.
