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

## H1 candidate status

An initial load-only overlap successor was explored, with source-register reuse allowed after DOT issue and active DOT destination/base conflicts blocked. Functional verification exposed duplicate DOT acceptance and stale operands in existing LOAD-dependent DOT tests. The candidate was rejected before implementation timing; no unsafe arbitration or architectural change was retained.

This result confirms that a safe H1 design needs an explicit accepted-DOT capture state plus a complete one-entry deferred normal-completion protocol and backpressure. Simply relaxing the younger-instruction hold is insufficient.

## Preserved baseline

The Stage D/G3.1 RTL and DOT arithmetic remain unchanged. Stage E still passes 233 checks with the historical memory-fed results above. No H1 implementation result is claimed.

Next work should be a narrower H1 redesign based on an explicit LOAD overlap state machine; do not begin H2 or Stage I until that design is specified and verified.
