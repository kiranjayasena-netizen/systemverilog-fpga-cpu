# GPU Stage 5A — Synthesis and Physical Baseline

## Scope

Stage 5A characterises the existing standalone `vector_program_core` without
changing Stage 1–5 functional RTL. The target is the Basys 3 Artix-7
`xc7a35tcpg236-1`, using Vivado 2026.1.

## Reproducible flow

The physical top is the Stage-5A-only wrapper
`rtl/vector_program_core_synth_top.sv`. It instantiates the complete
`vector_program_core` and reduces synthetic package IO to compact status and
parity outputs; it adds no compute behavior. The baseline script is
`scripts/run_vector_stage5a_baseline.tcl` and uses
`constraints/vector_program_core_stage5a.xdc` with a 10.000 ns clock.

The original direct top was not physically meaningful because its 128-bit
debug/load ports required more package pins than were available. The wrapper
resolved that implementation-top issue while preserving the datapath.

## Measured 100 MHz result

The design synthesized and routed successfully at the 100 MHz target, but
did not meet setup timing:

| Metric | Result |
|---|---:|
| Clock target | 100 MHz / 10.000 ns |
| WNS | -0.629 ns |
| TNS | -32.957 ns |
| Setup failing endpoints | 217 / 2092 |
| Hold WNS | +0.275 ns |
| Hold failing endpoints | 0 |
| Pulse-width WNS | +3.750 ns |

Therefore 100 MHz is a measured implementation failure for the unmodified
Stage 5 core. No timing optimisation was attempted.

## Resources

Post-route hierarchical utilization:

| Resource | Total |
|---|---:|
| LUT | 2284 |
| Logic LUT | 2272 |
| LUTRAM | 12 |
| FF | 1035 |
| RAMB18 | 0 |
| RAMB36 | 0 |
| DSP48 | 0 |

The execution unit/register-file hierarchy accounts for 2120 LUTs and 1024
FFs in the report. The instruction memory accounts for 153 LUTs, including
12 LUTRAMs. Vivado's distributed-memory inference report identified the
16×16-bit instruction store as `RAM32M` distributed RAM primitives. The
vector register file remained LUT/FF logic rather than BRAM.

## Critical path

The worst setup path starts at `core_inst/current_pc_reg[1]/C` and ends in a
vector-register-file state bit. Its post-route delay is 10.480 ns, comprising
3.153 ns logic and 7.327 ns routing over 11 logic levels. The path includes
the PC/sequencing and instruction/control/data selection family rather than a
DSP or BRAM path. Hold timing is clean; the reported worst hold WNS is
0.275 ns.

## Timing sweep status

The reusable sweep script is `scripts/run_vector_stage5a_timing_sweep.tcl`
and records frequency, period, WNS, TNS, failing endpoints, and status. A
full sweep was not run in this pass because each default post-route run takes
several minutes. Two clean targets were measured with the same RTL and flow:

| Target | WNS | Setup | Result |
|---:|---:|---|---|
| 80 MHz / 12.500 ns | +0.480 ns | 0 failing endpoints | PASS |
| 100 MHz / 10.000 ns | -0.629 ns | 217 failing endpoints | FAIL |

Thus the highest tested passing target is 80 MHz and the nearest tested higher
target is 100 MHz FAIL. This is a measured bracket, not an exact Fmax claim.
The reusable sweep script `scripts/run_vector_stage5a_timing_sweep.tcl` and
the 80 MHz helper `scripts/run_vector_stage5a_80mhz.tcl` support later finer
characterisation without changing RTL.

## Preservation and comparison

The synthesis hierarchy confirms that instruction memory, PC/sequencing,
decoder, vector register file, and four-lane ALU are present. The frozen CPU
reference (2008 LUT, 1812 FF, 2 RAMB18, 5 DSP48 at 93 MHz) is not an
apples-to-apples comparison; the two tops have different functionality and
interfaces. Stage 5A uses no DSP48 and no BRAM.

The Stage 5 functional testbench and all Stage 1–4 regressions remain
passing. Generated checkpoints and Vivado databases are ignored and are not
part of the intended source deliverable.

## Limitations and next step

This baseline has no vector data memory, VMUL, branches, masks, or CPU
interface. The next architectural stage remains the standalone vector data
memory; timing optimisation is intentionally deferred until after the
baseline is recorded.
