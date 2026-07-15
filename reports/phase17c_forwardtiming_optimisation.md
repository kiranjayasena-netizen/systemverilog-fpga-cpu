# Phase 17C Forward-Timing Optimisation Decision

## Purpose

Phase 17C is reserved for a targeted CPI optimisation of the Phase 13 forward-timing five-stage CPU after Phase 17A/17B identify the dominant lost-cycle source.

## Status

Deferred.

No CPU RTL has been changed in Phase 17C because the requested optimisation should be based on measured hardware bottleneck data. The current available board result gives throughput and implied CPI, but it does not yet expose the stall/flush/fetch-wait breakdown required to choose the right optimisation.

## Why No RTL Optimisation Was Made Yet

The user goal is to improve the best fixed-100 MHz board-measured path without unsupported claims. Blind changes would risk:

- increasing CPI, as Phase 13D did when decode-time WB-to-ID bypass was removed;
- hurting timing by adding target-buffer or control-flow complexity;
- optimising for the wrong workload;
- weakening the known-good Phase 13E/13I path.

## Optimisation Options To Use After Phase 17A Data

| Measured bottleneck | Candidate optimisation |
| --- | --- |
| Load-use stalls dominate | Refine load-use detection so only true consumers stall |
| Control flushes dominate | Reduce conservative redirect penalty while preserving wrong-path protection |
| Fetch waits dominate | Inspect fetch-buffer behavior and avoid unnecessary frontend bubbles |
| Program mix dominates | Create a hardware benchmark program aligned with the simulation benchmark |

## Required Verification For A Future RTL Change

Any future Phase 17C RTL optimisation should use a separate path, for example:

- `rtl/cpu_core_pipeline_forwardtiming_opt.sv`
- `rtl/fpga_top_pipeline_forwardtiming_opt.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming_opt.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming_opt.tcl`

Required checks:

- arithmetic execution still works;
- LOAD/STORE still works;
- forwarding still works;
- load-use hazards still work;
- `x0` remains protected;
- BEQ/JUMP still work;
- invalid opcodes and NOP remain safe;
- performance counters remain meaningful;
- full XSim regression passes;
- 10 ns Vivado implementation passes.

## Decision

Phase 17C optimisation is intentionally deferred until Phase 17A hardware counter readings identify the dominant CPI bottleneck. Phase 13E/13I remains the known-good five-stage path.
