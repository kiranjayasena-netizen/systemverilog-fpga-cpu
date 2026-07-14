# Phase 14E Six-Stage Pipeline BEQ/JUMP Control Flow

## Purpose

Phase 14E extends the separate Phase 14 six-stage pipeline so it can execute BEQ and JUMP control-flow instructions with redirect handling, younger-instruction flushing, stale fetch-response invalidation and wrong-path side-effect protection.

The preferred measured implementation remains the Phase 13E forwarding-timing pipeline with the Phase 13I `fanout_opt` Vivado strategy:

- Fmax: 115.607 MHz
- CPI: 1.339
- Practical estimated MIPS: ~86.4

Phase 14E does not claim a performance improvement and does not run a Phase 14 timing comparison.

## Files Added Or Modified

Added:

- `tb/tb_cpu_core_pipeline6_control.sv`
- `reports/phase14e_pipeline6_control.md`

Modified:

- `rtl/cpu_core_pipeline6.sv`
- `rtl/fpga_top_pipeline6.sv`
- `scripts/run_xsim_regression.ps1`
- `README.md`
- `docs/verification.md`

The Phase 13E/13I preferred RTL files were not modified.

## Six-Stage Control-Flow Summary

The Phase 14 path still uses:

```text
IF -> ID -> OP -> EX -> MEM -> WB
```

| Stage | Phase 14E behaviour |
| --- | --- |
| IF | Issues sequential instruction-BRAM requests and tracks request PC metadata. |
| ID | Decodes arithmetic, memory and control-flow opcodes. |
| OP | Prepares register operands, store data and branch operands using existing forwarding. |
| EX | Executes ALU/address operations and resolves BEQ/JUMP redirects. |
| MEM | Accesses synchronous data memory. |
| WB | Writes arithmetic/load results and retires valid instructions. |

## BEQ Strategy

BEQ is resolved conservatively in EX. The OP stage prepares `rs1` and `rs2` operands using the existing forwarding path. In EX, BEQ compares:

```text
operand_a == operand_b
```

If equal, the branch redirects to the custom-ISA PC-relative word target:

```text
target_pc = instruction_pc + (sign_extended_imm13 << 2)
```

If not equal, no redirect occurs and sequential fetch continues.

## JUMP Strategy

JUMP is also resolved in EX for Phase 14E. It always redirects when the instruction is valid, using the same target convention:

```text
target_pc = instruction_pc + (sign_extended_imm13 << 2)
```

No prediction, target buffer or early JUMP optimisation is added in this phase.

## Redirect, Flush And Stale-Response Handling

When a taken BEQ or JUMP is resolved:

- the redirecting instruction moves from OP/EX to EX/MEM so it can retire exactly once;
- IF/ID, ID/OP and the next OP/EX contents are converted into bubbles;
- `fetch_pc_reg` is set to the redirect target;
- `fetch_request_valid_reg` is cleared so the old synchronous instruction-BRAM response is not accepted;
- `paused_response_valid_reg` is cleared so a buffered wrong-path response cannot re-enter the pipeline.

Redirect has priority over load-use stalls and normal fetch movement. This keeps older control-flow decisions authoritative and prevents stale wrong-path instructions from retiring.

## Wrong-Path Protection

Wrong-path protection relies on the pipeline valid bits and redirect flush:

- wrong-path arithmetic instructions are flushed before writeback;
- wrong-path LOAD instructions are flushed before register writeback;
- wrong-path STORE instructions are flushed before the MEM write-enable stage;
- flushed instructions do not retire;
- invalid opcodes remain bubbles and do not cause side effects;
- writes to `x0` remain ignored.

Correct-path STORE instructions still write exactly once.

## Branch Operand Hazards

Phase 14E reuses the Phase 14C/14D forwarding and load-use interlock:

- arithmetic-to-BEQ dependencies use existing operand forwarding;
- LOAD-to-BEQ dependencies stall until the LOAD value is available through MEM/WB forwarding;
- STORE-data forwarding and load-use STORE handling continue to work.

The strategy is conservative and correctness-focused rather than CPI-optimised.

## Focused XSim Result

Command:

```powershell
xvlog/xelab/xsim for rtl/cpu_defs_pkg.sv, rtl/bram_instr_mem.sv, rtl/bram_data_mem.sv, rtl/cpu_core_pipeline6.sv and tb/tb_cpu_core_pipeline6_control.sv
```

Transcript:

- `reports/simulation_transcripts/phase14e_pipeline6_control_focused_20260713_205349.txt`

Result:

- Focused Phase 14E control-flow test passed.
- Checks run: 2,812
- Failures: 0

Coverage:

- BEQ not taken executes fall-through instructions;
- BEQ taken skips the wrong-path instruction;
- wrong-path STORE after BEQ is blocked;
- forward JUMP skips the wrong-path instruction;
- wrong-path STORE after JUMP is blocked;
- BEQ uses forwarded arithmetic operands;
- BEQ waits for or forwards a LOAD result safely;
- backward loop executes correctly with BEQ exit and JUMP back-edge;
- invalid opcode at a redirected target remains safe;
- NOP remains safe;
- pause/resume around a pending control redirect holds state and suppresses side effects.

## Full Regression

Full local regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase14e_full_xsim_regression_20260713_205407.txt`

Result:

- Full local XSim regression completed successfully.
- The Phase 14E control-flow test passed inside the full regression.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

## Known Limitations

- The control-flow penalty is not CPI-optimised.
- There is no branch prediction.
- There is no target buffer.
- No full custom-ISA Phase 14 benchmark has been added yet.
- No Phase 14 Vivado timing or MIPS result is claimed.

## Recommended Next Phase

Phase 14F should run full custom-ISA regression-style programs on the separate six-stage pipeline, measure CPI, and compare final architectural state against the established Phase 13/Phase 6 program expectations. Phase 13I remains the preferred measured implementation until Phase 14 has full verification and a better measured practical MIPS result.
