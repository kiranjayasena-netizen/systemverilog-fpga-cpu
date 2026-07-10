# Phase 10F BRAM-Aware Multi-Cycle CPU Variant

## Purpose

Phase 10F creates a separate experimental BRAM-aware multi-cycle CPU variant. The goal is to begin integrating the Phase 10C synchronous-read BRAM-style memories without modifying the verified CPU baselines.

This phase does not replace:

- `rtl/cpu_core.sv`
- `rtl/cpu_core_multicycle.sv`
- `rtl/cpu_top.sv`
- `rtl/fpga_top.sv`
- `rtl/fpga_top_multicycle.sv`

The existing custom instruction encoding is unchanged.

## New Implementation Path

New CPU module:

- `rtl/cpu_core_multicycle_bram.sv`

New focused testbench:

- `tb/tb_cpu_core_multicycle_bram_basic.sv`

The new CPU variant instantiates:

- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`

The existing verified `cpu_core_multicycle` baseline is preserved.

## BRAM-Aware FSM

The Phase 10F CPU uses explicit states for synchronous instruction and data memory timing:

- `FETCH_ADDR`
- `FETCH_CAPTURE`
- `DECODE`
- `EXECUTE`
- `MEMORY_ADDR`
- `MEMORY_CAPTURE`
- `WRITEBACK`

`FETCH_ADDR` presents the PC to instruction BRAM. `FETCH_CAPTURE` captures the instruction returned by the synchronous instruction memory and advances the default sequential PC.

## Instruction Sequences

| Instruction | Implemented state sequence |
| --- | --- |
| NOP | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> FETCH_ADDR` |
| ADD/SUB/AND/OR/XOR/ADDI | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> WRITEBACK -> FETCH_ADDR` |
| LOAD | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> MEMORY_ADDR -> MEMORY_CAPTURE -> WRITEBACK -> FETCH_ADDR` |
| STORE | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> MEMORY_ADDR -> FETCH_ADDR` |
| BEQ | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> FETCH_ADDR` |
| JUMP | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> EXECUTE -> FETCH_ADDR` |
| Invalid opcode | `FETCH_ADDR -> FETCH_CAPTURE -> DECODE -> FETCH_ADDR` |

Branch and jump support is implemented in the new module, using the existing convention:

```text
instruction_pc + (imm_ext << 2)
```

Phase 10F only runs a basic focused test. Full branch/jump regression for this BRAM-aware path should be part of the next phase.

## LOAD And STORE Timing

LOAD uses the BRAM data-memory latency explicitly:

1. `EXECUTE` calculates the effective address.
2. `MEMORY_ADDR` presents the address and asserts `mem_read`.
3. `MEMORY_CAPTURE` captures the BRAM read data.
4. `WRITEBACK` writes the captured data to `rd`, unless `rd` is `x0`.

STORE uses:

1. `EXECUTE` calculates the effective address.
2. `MEMORY_ADDR` presents the address, store data and one-cycle write enable.
3. The CPU returns to fetch without register writeback.

## Simulation Result

Simulator: Vivado XSim 2026.1

Standalone command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram.sv tb\tb_cpu_core_multicycle_bram_basic.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_basic -s tb_cpu_core_multicycle_bram_basic_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_basic_sim -runall
```

Focused Phase 10F result:

- Tests run: 27
- Tests failed: 0
- `PHASE 10F BRAM-AWARE CPU BASIC TEST PASSED`

The full XSim regression also passed after adding the Phase 10F test.

Transcript:

- `reports/simulation_transcripts/phase10f_xsim_regression_20260710_102950.txt`

Coverage:

- reset state,
- `FETCH_ADDR` and `FETCH_CAPTURE` behaviour,
- instruction register capture after synchronous instruction-memory read,
- sequential PC advance,
- ADDI,
- ADD,
- SUB,
- AND,
- OR,
- XOR,
- STORE through BRAM data memory,
- LOAD with synchronous BRAM data capture,
- `x0` write protection,
- invalid opcode safety,
- STORE write-enable pulse state.

## Expected CPI Impact

Compared with the Phase 8 multi-cycle CPU, the BRAM-aware CPU needs additional states around memory reads:

- instruction fetch is split into address and capture phases,
- LOAD uses address, capture and writeback phases,
- arithmetic instructions still need the fetch capture overhead.

This will likely increase CPI compared with the current timing-clean multi-cycle CPU. The expected benefit is better use of FPGA memory resources and a more scalable memory implementation.

## Limitations

- This is an initial BRAM-aware CPU variant only.
- Full custom-ISA program regression has not yet been completed for this new path.
- Branch and jump are implemented, but not yet covered by a full Phase 8F-style BRAM-aware regression.
- FPGA synthesis and BRAM inference confirmation are future work.
- No physical Basys 3 hardware validation has been performed.

## Recommendation

The recommended next phase is Phase 10G: full BRAM-aware custom-ISA verification.

After full verification passes, a later phase should create a BRAM-aware FPGA top and Vivado scripts to confirm BRAM inference, resource usage, timing, CPI and estimated MIPS.
