# Phase 14D Six-Stage Pipeline LOAD/STORE Execution

## Purpose

Phase 14D extends the separate Phase 14 six-stage pipeline so it can execute LOAD and STORE instructions using synchronous data memory.

The preferred measured implementation remains the Phase 13E forwarding-timing pipeline with the Phase 13I `fanout_opt` Vivado strategy:

- Fmax: 115.607 MHz
- CPI: 1.339
- Practical estimated MIPS: ~86.4

Phase 14D does not claim a performance improvement and does not run a Phase 14 timing comparison.

## Files Added Or Modified

Added:

- `tb/tb_cpu_core_pipeline6_memory.sv`
- `reports/phase14d_pipeline6_memory.md`

Modified:

- `rtl/cpu_core_pipeline6.sv`
- `rtl/fpga_top_pipeline6.sv`
- `scripts/run_xsim_regression.ps1`
- `README.md`
- `docs/verification.md`

The Phase 13E/13I preferred RTL files were not modified.

## Six-Stage Memory Datapath

The Phase 14 path still uses:

```text
IF -> ID -> OP -> EX -> MEM -> WB
```

| Stage | Phase 14D behaviour |
| --- | --- |
| IF | Issues sequential instruction-BRAM requests and tracks request PC metadata. |
| ID | Decodes supported Phase 14D opcodes, register fields and signed `imm13`. |
| OP | Reads and forwards base operands and STORE data. |
| EX | Computes arithmetic results or LOAD/STORE effective addresses. |
| MEM | Drives synchronous data-memory read or write request. |
| WB | Writes arithmetic or LOAD results and retires valid instructions. |

Phase 14D uses the existing `rtl/bram_data_mem.sv` module for data memory.

## LOAD Timing

LOAD effective address calculation happens in EX:

```text
effective_address = rs1 + sign_extended_imm13
```

The LOAD request is driven when the instruction is in EX/MEM. Because `bram_data_mem.sv` has synchronous read behaviour, the read data is not used in the same cycle as the request. The LOAD metadata moves into MEM/WB, and the data-memory response is used for writeback from the WB stage.

If `enable` is deasserted while a LOAD response is waiting in MEM/WB, the response is captured into a small hold register so resume does not lose the loaded value.

## STORE Timing

STORE effective address calculation also happens in EX:

```text
effective_address = rs1 + sign_extended_imm13
store_data        = rs2 value, with forwarding
```

The STORE write enable is asserted only while the STORE is valid in EX/MEM and `enable` is high. This prevents duplicate writes during pause. STORE does not write the register file and retires after passing through MEM/WB.

## Hazard And Forwarding Strategy

Phase 14D keeps the Phase 14C arithmetic forwarding behaviour and adds safe memory handling.

Forwarding priority for operand reads is:

1. OP/EX arithmetic result;
2. EX/MEM arithmetic result;
3. MEM/WB writeback result, including LOAD data;
4. architectural register storage.

LOAD results are not forwarded from OP/EX or EX/MEM because synchronous data memory has not returned the data yet.

For an immediate load-use dependency, the core uses a conservative stall:

- hold IF/ID and ID/OP;
- buffer any returned instruction-BRAM response;
- insert a bubble into OP/EX;
- allow older stages to drain.

The focused test verifies load-use arithmetic and load-use STORE dependencies. This conservative approach is correct but may not be performance-optimal.

## Focused XSim Result

Command:

```powershell
xvlog/xelab/xsim for rtl/cpu_defs_pkg.sv, rtl/bram_instr_mem.sv, rtl/bram_data_mem.sv, rtl/cpu_core_pipeline6.sv and tb/tb_cpu_core_pipeline6_memory.sv
```

Transcript:

- `reports/simulation_transcripts/phase14d_pipeline6_memory_focused_20260713_202559.txt`

Result:

- Focused Phase 14D memory test passed.
- Checks run: 489
- Failures: 0

Coverage:

- reset clears pipeline and registers;
- basic STORE to `[x1 + 0]`;
- basic LOAD from `[x1 + 0]`;
- STORE/LOAD with `+4` byte offset;
- negative-offset LOAD using `[x5 - 4]`;
- STORE-data forwarding from a recent ADDI result;
- LOAD-use arithmetic dependency;
- LOAD-use STORE dependency;
- LOAD and ADDI writes to `x0` are ignored;
- invalid opcode remains a safe bubble;
- NOP retires safely;
- pause/resume during data-memory activity holds state and does not duplicate STORE writes.

## Full Regression

Full local regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase14d_full_xsim_regression_20260713_202642.txt`

Result:

- Full local XSim regression completed successfully.
- The Phase 14D memory test passed inside the full regression.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

## Known Limitations

- BEQ and JUMP are not implemented in the Phase 14 six-stage path yet.
- Wrong-path branch/jump protection is not implemented yet.
- No full custom-ISA Phase 14 benchmark has been added yet.
- No Phase 14 Vivado timing or MIPS result is claimed.
- Load-use handling is conservative and may add more stalls than a later optimised design.

## Recommended Next Phase

Phase 14E should add BEQ/JUMP redirects and wrong-path protection for the separate six-stage pipeline while preserving the Phase 13I result as the preferred measured baseline.
