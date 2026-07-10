# Phase 10G BRAM-Aware CPU Full Verification

## Purpose

Phase 10G verifies the separate BRAM-aware multi-cycle CPU variant against the full custom ISA program behaviours that were previously used for the non-BRAM multi-cycle CPU. Phase 10F proved the basic BRAM-aware fetch, arithmetic, LOAD/STORE and invalid-opcode paths. Phase 10G extends that evidence to full program-level coverage, including branch and jump control flow.

This phase does not replace the existing verified CPU baseline. The original `cpu_core.sv`, the original `cpu_core_multicycle.sv`, the FPGA top-level wrappers and the instruction encodings were left unchanged.

## Design Under Test

Files used by the Phase 10G testbench:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_multicycle_bram.sv`
- `tb/tb_cpu_core_multicycle_bram_full_programs.sv`

The BRAM-aware CPU uses synchronous instruction and data memory prototypes. Instruction fetch therefore uses a two-state sequence:

- `FETCH_ADDR`
- `FETCH_CAPTURE`

LOAD also accounts for synchronous BRAM data read latency:

- address calculation in `EXECUTE`
- BRAM read request in `MEMORY_ADDR`
- data capture in `MEMORY_CAPTURE`
- register writeback in `WRITEBACK`

## Custom ISA Coverage

The Phase 10G testbench covers:

- `NOP`
- `ADD`
- `SUB`
- `AND`
- `OR`
- `XOR`
- `ADDI`
- `LOAD`
- `STORE`
- `BEQ`
- `JUMP`
- invalid opcode safety

It runs six full-program style subtests:

| Program | Main behaviour verified |
| --- | --- |
| BRAM arithmetic edge | ADDI, ADD, SUB, negative immediate sign extension, wraparound, underflow and `x0` protection |
| BRAM memory offset | LOAD/STORE base + offset, base + 4, negative offset load and BRAM data memory contents |
| BRAM branch control | BEQ taken, BEQ not taken, skipped instruction protection and fall-through execution |
| BRAM jump control | forward JUMP and skipped instruction protection |
| BRAM simple loop | repeated ADD/SUB, BEQ loop exit, backward JUMP and final STORE |
| BRAM invalid opcode safety | invalid opcodes keep `valid_instr` low and do not write registers or memory |

## Branch And Jump PC Handling

The BRAM-aware CPU preserves the existing custom ISA branch and jump convention:

```text
pc_target = instruction_pc + (imm_ext << 2)
```

Using `instruction_pc` is important because the sequential PC has already advanced during instruction fetch. The Phase 10G branch and jump subtests verify:

- BEQ taken updates the PC to the target.
- BEQ not taken follows the sequential path.
- JUMP updates the PC to the target.
- Forward and backward control-flow offsets work.
- BEQ and JUMP do not assert `reg_write`.
- BEQ and JUMP do not assert `mem_write`.

## LOAD/STORE BRAM Timing

The testbench checks that STORE writes occur only during the `MEMORY_ADDR` state and that LOAD data is not written back until after the BRAM read data has been captured. It also verifies:

- base + 0 addressing
- base + 4 addressing
- negative offset addressing
- final BRAM data memory word values
- `x0` remains protected from LOAD writeback

## Simulation Result

Simulator:

- Vivado XSim 2026.1

Standalone command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram.sv tb\tb_cpu_core_multicycle_bram_full_programs.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_full_programs -s tb_cpu_core_multicycle_bram_full_programs_phase10g_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_full_programs_phase10g_sim -runall
```

Full regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase10g_xsim_regression_20260710_105251.txt`

Result:

- Full XSim regression passed.
- Phase 10G testbench summary: 135 tests run, 0 tests failed.
- Console output included `PHASE 10G BRAM-AWARE FULL-PROGRAM TEST PASSED`.
- The known Vivado/XSim object-directory cleanup warning appeared after elaboration, but the snapshots were built, `xsim` ran, and all self-checking tests passed.

## CPI And Estimated MIPS

The Phase 10G testbench counts active cycles and completed instructions using BRAM-aware instruction completion points:

- arithmetic, ADDI and LOAD complete at `WRITEBACK`
- STORE completes during `MEMORY_ADDR`
- BEQ and JUMP complete during `EXECUTE`
- NOP and invalid opcodes complete during `DECODE`

| Program | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| BRAM arithmetic edge | 48 | 10 | 4.800 | 20.833 |
| BRAM memory offset | 49 | 9 | 5.444 | 18.367 |
| BRAM branch control | 46 | 10 | 4.600 | 21.739 |
| BRAM jump control | 31 | 7 | 4.429 | 22.581 |
| BRAM simple loop | 73 | 16 | 4.562 | 21.918 |
| BRAM invalid opcode safety | 24 | 6 | 4.000 | 25.000 |
| Aggregate | 271 | 58 | 4.672 | 21.402 |

The CPI is higher than the earlier non-BRAM multi-cycle CPU because synchronous BRAM instruction fetch and LOAD operations require extra capture states. This is expected and is the main performance cost of moving toward FPGA block RAM style memories.

## Limitations

- This is simulation evidence only.
- Phase 10G does not prove BRAM inference in synthesis.
- Phase 10G does not include routed implementation timing for the BRAM-aware top level.
- Physical Basys 3 board validation remains pending because the board is not available.

## Conclusion

Phase 10G passed. The separate BRAM-aware multi-cycle CPU now passes full custom ISA program verification in simulation, including arithmetic, memory, branch, jump, loop and invalid-opcode safety scenarios.

The recommended next phase is Phase 10H: create a BRAM-aware FPGA top-level implementation path, run Vivado synthesis and implementation, confirm whether BRAM resources are inferred, and compare timing/resource results against the Phase 8G non-BRAM multi-cycle CPU.
