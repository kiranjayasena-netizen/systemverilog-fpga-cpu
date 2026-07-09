# Phase 10A Performance Benchmarking

## Purpose

Phase 10A measures the simulated instruction throughput of the separate multi-cycle CPU, `rtl/cpu_core_multicycle.sv`, using benchmark-style self-checking testbench programs.

The aim is to collect useful performance evidence while Basys 3 hardware bring-up remains pending. This is simulation-based benchmarking only; it does not claim measured hardware speed.

## Method

The benchmark testbench is `tb/tb_cpu_core_multicycle_performance.sv`.

It instantiates `cpu_core_multicycle` directly and supplies small in-testbench instruction memories for four benchmark programs:

- Arithmetic-heavy program
- Memory-heavy program
- Branch/jump program
- Simple loop program

The testbench counts completed instructions using the multi-cycle CPU state machine:

- Arithmetic, ADDI and LOAD complete in `WRITEBACK`.
- STORE completes in `MEMORY`.
- BEQ and JUMP complete in `EXECUTE`.
- NOP and invalid instructions complete in `DECODE`.

This avoids assuming single-cycle timing.

## Simulation Result

Simulator: Vivado XSim 2026.1

Standalone command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_performance.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_performance -s tb_cpu_core_multicycle_performance_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_performance_sim -runall
```

Status: passed.

The self-checking testbench reported:

- Tests run: 41
- Tests failed: 0
- `PHASE 10A MULTI-CYCLE PERFORMANCE TEST PASSED`

The full XSim regression also passed after adding this benchmark.

Transcript:

- `reports/simulation_transcripts/phase10a_xsim_regression_20260709_190808.txt`

## Benchmark Results

The estimates below assume the Phase 8G multi-cycle FPGA target clock of 100 MHz, where each cycle is 10 ns.

| Benchmark | Cycles | Completed instructions | Arithmetic | Loads | Stores | Branches | Jumps | CPI | Estimated MIPS at 100 MHz | Estimated runtime |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Arithmetic-heavy | 42 | 11 | 10 | 0 | 0 | 0 | 0 | 3.818 | 26.190 | 420 ns |
| Memory-heavy | 50 | 12 | 4 | 4 | 3 | 0 | 0 | 4.167 | 24.000 | 500 ns |
| Branch/jump | 39 | 11 | 7 | 0 | 0 | 2 | 1 | 3.545 | 28.205 | 390 ns |
| Simple loop | 71 | 20 | 11 | 0 | 1 | 4 | 3 | 3.550 | 28.169 | 710 ns |

Aggregate across these benchmark runs:

- Total cycles: 202
- Completed instructions: 54
- Arithmetic instructions: 32
- LOAD instructions: 4
- STORE instructions: 4
- Branch instructions: 6
- JUMP instructions: 4
- Aggregate CPI: 3.741
- Estimated aggregate throughput at 100 MHz: 26.733 MIPS
- Aggregate simulated runtime at 100 MHz: 2.020 us

## Interpretation

The multi-cycle CPU has instruction-dependent execution time:

- Register arithmetic and ADDI use four active cycles.
- LOAD uses five active cycles.
- STORE uses four active cycles.
- BEQ and JUMP use three active cycles.
- NOP uses two active cycles.

The measured CPI values are therefore expected. The memory-heavy benchmark has the highest CPI because LOAD instructions require the extra `MEMORY` and `WRITEBACK` stages.

## Limitations

- These are simulation benchmark results, not measured hardware results.
- The programs are deliberately small and educational rather than representative application workloads.
- The MIPS estimates assume the implemented multi-cycle FPGA top is run at 100 MHz.
- Physical Basys 3 validation remains pending until the board is available.

## Conclusion

Phase 10A adds simulation-based performance evidence for the multi-cycle CPU without changing RTL. The separate multi-cycle CPU passes the benchmark testbench, and the results provide a first CPI and MIPS estimate for later comparison with hardware observations or future architectural changes.
