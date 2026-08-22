# Stage 11 — Extended Lookahead Prefetch Scheduler

## Preparation status

Stage 10B remains frozen. No Stage 10A, Stage 10B, CPU, ISA, or shared
functional RTL was changed in this preparation pass.

The Vivado executable is installed at
`C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`, but Stage 11 has not
been simulated, synthesized, or implemented in this environment. No
Stage 11 PASS or performance result is claimed.

## Experiment definition

Stage 11 will compare lookahead depths 6 and 8 (depth 12 is optional)
against the frozen Stage 10B depth-4 scheduler. The experiment keeps
two entries, one synchronous read port, one outstanding read, in-order
execution, and the existing ISA unchanged.

Candidate selection must reject duplicates, pending addresses, current
store hazards, intervening same-address stores, inactive program slots,
and PC wraparound. The nearest safe VLOAD is selected.

## Required evidence

- 32 or more functional tests per implemented depth.
- 20/20 frozen Stage 10B regression.
- At least 8 architectural-equivalence cases.
- Unchanged register-VADD, array-add, XOR, and VSRA benchmarks.
- Deep-prefetch request/hit counters, maximum distance, and two-entry
  occupancy.
- Post-synthesis resources and post-route 80 MHz setup/hold timing.

## Executed results

The harness was expanded to 32 named tests and executed in Vivado 2026.1
for both depth 6 and depth 8: 32/32 passed at each depth. The targeted
program issued a distance-5 prefetch and later consumed it as a hit.

Stage 10B versus Stage 11 depth-6 architectural equivalence passed 8/8
(dependent ALU, memory pipeline, multiple memory operations, store hazard,
invalid instruction, restart, XOR, and VSRA).

Unchanged benchmarks remained at 4/21/13/13 cycles for register VADD,
array add, XOR, and VSRA at both depths. The array benchmark retained
three ALU/read overlaps and three ALU-origin hits; deeper lookahead did not
reduce its cycle count.

Post-route characterization:

| Variant | LUT | LUTRAM | FF | RAMB36 | DSP | Setup WNS | Hold WHS | Array cycles |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Stage 10B depth 4 | 3109 | 44 | 1446 | 2 | 0 | +0.186 ns | +0.083 ns | 21 |
| Stage 11 depth 6 | 3177 | 68 | 1450 | 2 | 0 | +0.001 ns | +0.249 ns | 21 |
| Stage 11 depth 8 | 3349 | 76 | 1446 | 2 | 0 | +0.334 ns | +0.219 ns | 21 |

Depth 6's routed worst path was current-PC control to the vector data
memory address (11.905 ns, 2.280 ns logic, 9.625 ns routing, 11 levels).
Depth 8's was current-PC control to vector-register-file state (12.022 ns,
3.289 ns logic, 8.733 ns routing, 12 levels). Both remain routing-heavy.

The measured array throughput is 60.952 MAdds/s at 80 MHz. Efficiency is
approximately 19.19 MAdds/s per 1000 LUT at depth 6 and 18.20 at depth 8,
versus approximately 19.60 for Stage 10B. Thus depth 6 is the better
extended-lookahead candidate, but it provides no unchanged-workload speedup
and has only 1 ps setup margin.
