# Phase 14C Six-Stage Pipeline Arithmetic Execution

## Purpose

Phase 14C extends the separate Phase 14 six-stage pipeline path so it can execute basic arithmetic instructions correctly in simulation.

The preferred measured CPU remains the Phase 13E forwarding-timing pipeline RTL using the Phase 13I `fanout_opt` implementation strategy:

- Fmax: 115.607 MHz
- CPI: 1.339
- Practical estimated MIPS: ~86.4

Phase 14C does not claim a performance improvement and does not run a Phase 14 Vivado timing comparison.

## Files Added Or Modified

Added:

- `tb/tb_cpu_core_pipeline6_arithmetic.sv`
- `reports/phase14c_pipeline6_arithmetic.md`

Modified:

- `rtl/cpu_core_pipeline6.sv`
- `rtl/fpga_top_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_skeleton.sv`
- `scripts/run_xsim_regression.ps1`
- `README.md`
- `docs/verification.md`

The Phase 13E/13I preferred RTL files were not modified.

## Six-Stage Arithmetic Datapath

The Phase 14 path still uses:

```text
IF -> ID -> OP -> EX -> MEM -> WB
```

| Stage | Phase 14C behaviour |
| --- | --- |
| IF | Issues sequential instruction BRAM requests and tracks request PC metadata. |
| ID | Decodes supported Phase 14C opcodes, register fields and signed `imm13`. |
| OP | Reads architectural registers and applies simple arithmetic forwarding. |
| EX | Computes ADD, SUB, AND, OR, XOR and ADDI results. |
| MEM | Pass-through placeholder; no data memory is implemented yet. |
| WB | Writes arithmetic results to the internal register store and retires valid instructions. |

## Register Storage And Writeback

Phase 14C uses internal architectural register storage inside `rtl/cpu_core_pipeline6.sv`.

Rules:

- `x0` is always reported as zero.
- Writes to `x0` are ignored.
- Arithmetic writes occur only when a valid supported instruction reaches the WB boundary.
- NOP retires without writing a register.
- Invalid and unsupported opcodes become safe bubbles and do not retire or write.

Debug outputs were added for selected registers `x0` through `x13`, writeback validity, writeback destination register, writeback data and stall visibility.

## Hazard And Forwarding Strategy

Phase 14C prioritises correctness over CPI, but the arithmetic path uses simple forwarding instead of stalling.

When an instruction enters OP/EX, source operands can be forwarded from:

1. current OP/EX ALU result;
2. EX/MEM writeback data;
3. MEM/WB writeback data;
4. architectural register storage.

Forwarding ignores `x0` and invalid stages. This covers the focused arithmetic dependency chain without adding stalls. `debug_stall_active` remains low in Phase 14C because LOAD/STORE and load-use hazards are not implemented yet.

## Supported Instructions

Implemented in Phase 14C:

- NOP
- ADD
- SUB
- AND
- OR
- XOR
- ADDI

Not implemented yet:

- LOAD
- STORE
- BEQ
- JUMP

Unsupported valid opcodes are treated as safe bubbles in this phase.

## Focused XSim Result

Command:

```powershell
xvlog/xelab/xsim for rtl/cpu_defs_pkg.sv, rtl/bram_instr_mem.sv, rtl/cpu_core_pipeline6.sv and tb/tb_cpu_core_pipeline6_arithmetic.sv
```

Transcript:

- `reports/simulation_transcripts/phase14c_pipeline6_arithmetic_focused_20260713_194940.txt`

Result:

- Focused Phase 14C arithmetic test passed.
- Checks run: 377
- Failures: 0

Coverage:

- reset clears pipeline and registers;
- ADDI writes `x1 = 5` and `x2 = 7`;
- ADD/SUB/AND/OR/XOR execute correctly;
- negative immediate sign extension writes `x8 = 32'hffff_ffff`;
- writes to `x0` are ignored;
- dependent arithmetic instructions read forwarded values rather than stale register values;
- NOP retires safely;
- invalid opcode does not retire or write;
- no memory write occurs;
- pause/resume holds pipeline and register state safely.

The known Vivado/XSim `xelab` object-directory cleanup warning appeared after the snapshot was built. XSim ran successfully and the self-checking testbench reported PASS.

## Full Regression Result

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase14c_full_xsim_regression_20260713_195034.txt`

Result:

- Full local XSim regression completed successfully.
- The Phase 14B skeleton test remains in regression.
- The Phase 14C arithmetic test is now included in regression and reported `tests_run=377 tests_failed=0`.
- The known `xelab` cleanup warning appeared after snapshot builds, but XSim completed successfully.

## Known Limitations

Phase 14C does not implement:

- LOAD/STORE;
- data memory;
- BEQ/JUMP redirects;
- load-use hazard handling;
- full forwarding for memory/control instructions;
- branch prediction, target buffers or caches;
- Phase 14 Vivado timing or MIPS measurement.

The current best measured implementation remains Phase 13E RTL with the Phase 13I `fanout_opt` strategy.

## Recommended Next Phase

Phase 14D should add LOAD/STORE support and load-use hazard handling to the separate six-stage path. It should verify:

- synchronous data BRAM timing;
- effective address calculation;
- STORE data correctness;
- LOAD writeback correctness;
- x0 protection on LOAD;
- load-to-ALU dependency handling;
- no regression of the Phase 14C arithmetic checks.
