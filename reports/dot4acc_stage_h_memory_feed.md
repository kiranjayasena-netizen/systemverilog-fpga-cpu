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

## H1.3b selective second-LOAD admission

H1.3b was derived from H1.3a in separate files. It introduced an atomic `second_load_transfer_fire` event and explicit `second_load_idex_owned` state. The event consumes IF/ID LOAD B and loads ID/EX together; ownership is set once on that event. The first-load context is recognized from the live lifetime of `load_overlap_reserved`, `dot_load_completion_deferred` or `deferred_load_valid`, rather than assuming one particular flag remains asserted.

The exception remains LOAD-only. Non-LOAD scalar instructions continue to be blocked. LOAD B is held in ID/EX only while the deferred entry is valid; it cannot advance to EX/MEM, launch BRAM or create a completion during that state. On release, it transfers once and the diagnostics observed exactly one EX/MEM transfer, BRAM read and completion for every admitted LOAD B.

The focused H1.3b inherited suite passed 4,254 checks with zero failures and the Stage E-derived benchmark passed 233 checks with zero failures. The measured ownership and performance results were:

| N | cycles | LOAD-use | DOT hold | fetch/wait | retirement | IF/ID blocked | admitted | ID/EX held | EX/MEM | BRAM | completion |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 39 | 1 | 17 | 10 | 11 | 12 | 3 | 0 | 3 | 3 | 3 |
| 32 | 71 | 1 | 33 | 14 | 23 | 28 | 7 | 0 | 7 | 7 | 7 |
| 64 | 135 | 1 | 65 | 22 | 47 | 60 | 15 | 0 | 15 | 15 | 15 |
| 128 | 263 | 1 | 129 | 38 | 95 | 124 | 31 | 0 | 31 | 31 | 31 |

The second LOAD was admitted 31 times at N=128, and the primary performance checkpoint was met: N=128 fell from 294 to 263 cycles, a 31-cycle reduction (1.118x speedup). At nominal 100 MHz this is approximately 48.67 MMAC/s. No deferred rs1/rs2 forwards were consumed in this benchmark; both operands were available through the ordinary path by the time DOT issue occurred. The reduction came from allowing the second LOAD to enter the pipeline, not from deferred-value forwarding.

The ID/EX-held count was zero because the deferred entry drained before the admitted LOAD reached a cycle requiring an ID/EX hold. The one-entry completion rule was therefore not overflowed. A Vivado implementation is justified by the measured cycle improvement, but has not yet been run; functional/regression completion precedes the required 100 MHz comparison.

One clean 100 MHz default-flow attempt was launched with the H1.3b top and unchanged Stage G methodology. Vivado failed before synthesis/implementation with the existing Tcl file-open/tool initialization error (`Could not open 'C' for writing`); consequently no timing or resource result is claimed from that attempt.

## H1.3b-T1 timing-recovery candidate

T1 was derived into separate RTL, wrapper, testbench and script files and made
one control-only change. The shared `load_overlap_allowed` decode no longer
carries the late `redirect_pending_valid` and `ex_redirect_taken` terms. A
separate `load_overlap_transfer_fire` retains both conditions at the sequential
transfer/ownership boundary, preserving redirect priority and H1.3b behaviour.
Focused verification remained 4,254/0 and the memory-fed benchmark remained
39/71/135/263 cycles (`8K+7` exactly).

The earlier Vivado failure was tool initialization: normal user APPDATA caused
`tclapp::load_apps` to attempt opening the single token `C`. Launching
`C:\\AMDDesignTools\\2026.1\\Vivado\\bin\\vivado.bat` with temporary clean
APPDATA/LOCALAPPDATA/XILINX_LOCAL_USER_DATA allowed the flow to run. The T1
wrapper module-name mismatch was corrected in the new wrapper only.

| candidate | WNS (ns) | TNS (ns) | setup fails | hold WNS (ns) | LUT | FF | RAMB18 | DSP48 | critical path |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| H1.3b T0 | -1.865 | -817.384 | 698 | +0.059 | 2007 | 1813 | 2 | 5 | BRAM → branch/redirect → overlap/frontend → instruction BRAM |
| H1.3b-T1 | -1.525 | -537.848 | 652 | +0.059 | 1984 | 1812 | 2 | 5 | data BRAM → deferred-load mux → branch/PC reset → ID/EX PC reset |

T1 improved WNS by 0.340 ns and reduced failing endpoints by 46, but remains a
clear setup failure; 5/5 repeatability was not started. The T1 worst path is
`cpu_inst/data_mem_inst/mem_reg/CLKARDCLK` to
`cpu_inst/id_ex_reg_reg[pc][28]/R`, with 10.955 ns data delay (4.633 ns logic,
6.322 ns routing, 12 levels). It remains a data-memory/branch-PC control
family, not DOT DSP arithmetic. T1 is rejected for timing closure; H1.3b's
263-cycle architecture remains the functional baseline for a separately
approved timing study.

## H1.3b-T2 deferred-load/branch-control isolation

T2 hypothesis: because `scalar_overlap_hold` prevents a non-DOT instruction
from advancing while `deferred_load_valid` is asserted, branch comparison does
not need the DOT-only deferred-load forwarding mux; give branches an equivalent
RF/EX-MEM/MEM-WB/DOT-completion forwarding path that excludes deferred data.

The T2 candidate was created separately and preserved H1.2 deferred rs1/rs2
forwarding for DOTs. A simulation assertion proves that a branch cannot be in
ID/EX while a deferred LOAD is pending. Focused verification passed 4,254/0;
Stage E passed 233/0 and retained 39/71/135/263 cycles, exact `8K+7`, 31/31/31/31
N=128 ownership counts, register-resident 27/43 cycles and II=1.

The clean 100 MHz routed result was:

| candidate | WNS (ns) | TNS (ns) | setup fails | hold WNS (ns) | LUT | FF | RAMB18 | DSP48 | critical path |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| H1.3b T0 | -1.865 | -817.384 | 698 | +0.059 | 2007 | 1813 | 2 | 5 | WB/redirect/overlap/frontend |
| H1.3b-T1 | -1.525 | -537.848 | 652 | +0.059 | 1984 | 1812 | 2 | 5 | BRAM/deferred-load/branch-PC/ID-EX reset |
| H1.3b-T2 | -0.623 | -71.487 | 286 | +0.057 | 2014 | 1812 | 2 | 5 | BRAM/deferred-load/redirect/ID-EX operand reset |

T2's worst path is `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK` to
`cpu_inst/id_ex_reg_reg[operand_a][1]/R`: 9.989 ns data delay, 4.633 ns logic,
5.356 ns routing and 12 levels. The first 25 paths remain the same family,
with endpoints across ID/EX operand and accumulator reset pins and slacks from
-0.623 to approximately -0.574 ns. T2 therefore materially improved the
target family but did not reach 100 MHz; no repeatability runs were started.
T2 is rejected for closure. No T3, Fmax sweep, or architectural redesign was
started.

## H1.3b-T3 ID/EX valid-only flush experiment

T3 hypothesis: ordinary EX redirects need only invalidate `id_ex_reg.valid`,
while global reset and hazard/hold bubbles retain the existing full payload
clear; stale ID/EX payload is harmless whenever valid is zero.

The valid-bit contract was checked against all ID/EX consumers. Payload fields
are only architecturally effective through valid-gated EX/MEM, memory, branch,
DOT issue, forwarding, retirement and performance-counter logic. Global reset
remained a full `clear_id_ex()` operation. Only the `if (ex_redirect_taken)`
flush changed from `clear_id_ex()` to `invalidate_id_ex()`.

T3 focused verification passed 4,254/0, Stage E passed 233/0, and all
39/71/135/263 memory-fed and 27/43 register-resident cycle invariants were
preserved. Individual A1/A2/C/D/G, MAC8 and Phase12 regressions also passed.

The clean 100 MHz T3 implementation regressed timing:

| candidate | WNS (ns) | TNS (ns) | setup fails | hold WNS (ns) | LUT | FF | RAMB18 | DSP48 | critical path |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| H1.3b T0 | -1.865 | -817.384 | 698 | +0.059 | 2007 | 1813 | 2 | 5 | WB/redirect/overlap/frontend |
| H1.3b-T1 | -1.525 | -537.848 | 652 | +0.059 | 1984 | 1812 | 2 | 5 | BRAM/deferred-load/branch-PC/ID-EX reset |
| H1.3b-T2 | -0.623 | -71.487 | 286 | +0.057 | 2014 | 1812 | 2 | 5 | BRAM/deferred-load/redirect/ID-EX operand reset |
| H1.3b-T3 | -0.920 | -233.654 | 454 | +0.110 | 2050 | 1814 | 2 | 5 | BRAM/deferred-load/DOT logic/instruction reset |

T3's worst path is `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK` to
`cpu_inst/id_ex_reg_reg[instruction][1]/R`, with 10.276 ns data delay,
4.633 ns logic, 5.643 ns routing and 12 levels. The payload-reset endpoint
disappeared, but the late control cone moved to the instruction field and
included DOT-related combinational logic. T3 worsened WNS by 0.297 ns versus
T2 and is rejected. No 5/5 run, T4, Fmax sweep or Stage I work was started.
