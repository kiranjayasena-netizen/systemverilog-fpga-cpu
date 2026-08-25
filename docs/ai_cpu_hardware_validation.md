# Stage 27 AI CPU hardware validation

This stage validates the frozen `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
implementation without modifying its datapath. DOT4ACC uses opcode `0xc`,
fields `[27:23]=rd`, `[22:18]=rs1`, `[17:13]=rs2`, and reserved immediate
bits `[12:0]=0`. It computes four signed INT8 products, adds them to the
32-bit accumulator in `rd`, and wraps modulo 2^32.

The repository contains the existing scalar baseline workload
`programs/ai_dot_product_baseline.mem` and the DOT4ACC workload
`programs/ai_dot_product_dot4acc.mem`. Existing XSim suites are the source of
truth for arithmetic and cycle measurements. The independent Python model is
`tools/ai_cpu_golden.py`.

## Current validation boundary

The frozen optimized CPU top is a switch/LED shell with a fixed instruction
image. It has no host program/data load, UART, result-readback, or cycle-count
port. Consequently a physical Basys 3 comparison cannot honestly be performed
through the existing top without either changing the frozen CPU core or adding
a dedicated validation wrapper with explicit memory/control ports. Stage 27
therefore prepares and runs simulation validation, records this integration
blocker, and does not claim physical CPU results.

The GPU UART and `gpu-v1.0` release are unaffected.

Stage 27B re-audited both frozen cores and confirms this remains the blocking
interface limitation. The detailed matrix is in
`docs/ai_cpu_validation_interface_matrix.md`.
Historical Stage 27C implementation references (superseded by the final
UART-fix rebuild below): baseline WNS/WHS +1.956/+0.093 ns and optimized
+0.443/+0.117 ns. Stage 27C simulation closure (physical testing not run):
DOT4 70/70 (41/16
cycles), DOT64 64/64 (72/31), MATVEC `0x278,0xffff_ff11`/same (26/19), and
signed edge 1/1 (15/16). UART, wrapper, completion, cycle-counter,
reset/restart, and three-run deterministic E2E checks pass. The signoff script
emitted `AI_CPU_STAGE27C_SIGNOFF_PASS`; no physical speedup is claimed. A
fresh paired Vivado rebuild is blocked by the local tclapp project-write error.
Final paired implementation status: both validation tops were rebuilt at the
common 80 MHz clock using the isolated Vivado user-data wrapper. Baseline
WNS/WHS = +1.956/+0.093 ns; optimized = +0.443/+0.117 ns. TNS/THS are zero
with no failing endpoints. Bitstreams are under `.ai_cpu_baseline/` and
`.ai_cpu_optimized/`. The original `tclapp::load_apps`/`Could not open 'C'`
failure was a corrupted or unwritable user TclStore path, not RTL behavior.
Physical testing remains out of scope.

## Stage 27D physical Basys 3 validation

Physical validation ran on Digilent Basys 3 `xc7a35t` target `210183BE6B56`
through COM4 at 80 MHz using the final rebuilt bitstreams. Board results
(`READ_CYCLES`, excluding UART time) were DOT4 0x46/42 baseline and 0x46/17
optimized, DOT64 0x40/73 and 0x40/32, MATVEC 0x278,0xffff_ff11/27 and
0x278,0xffff_ff11/20, and EDGE 0x1/16 and 0x1/17. Ratios are 2.4706x,
2.2813x, 1.3500x, and 0.9412x (EDGE optimized slowdown). Reset/restart passed
for both variants. Optimized stability passed 100/100 jobs (25 per workload)
with zero errors, timeouts, mismatches, or cycle nondeterminism.
