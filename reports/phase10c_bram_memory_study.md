# Phase 10C BRAM Memory Study

## Purpose

Phase 10C studies BRAM-style instruction and data memory implementations for the custom CPU project.

The current verified CPU cores are not modified in this phase. Instead, standalone memory prototypes are added and tested so the memory behaviour can be understood before changing the working processor path.

## Why Phase 10C Exists

Phase 8G showed that the separate multi-cycle FPGA top meets the 100 MHz post-route timing target, but the reported BRAM usage is still 0. The implementation is therefore using distributed logic resources for the current memories rather than FPGA block RAM.

The Phase 8G timing path is now memory-related. That makes memory implementation the next useful study area after the successful multi-cycle timing work.

## Why BRAM Is Useful On FPGA

Block RAM is a dedicated FPGA memory resource. Using BRAM can:

- reduce LUT usage for larger memories,
- provide a more scalable instruction/data memory implementation,
- make memory placement and routing more predictable,
- better match how practical FPGA soft-core processors store programs and data.

The trade-off is that FPGA block RAM normally has synchronous read behaviour. Data is returned after a clock edge, not immediately in the same cycle as a combinational memory read.

## Standalone Prototype Modules

Phase 10C adds two standalone modules:

- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`

These modules are written in a Xilinx-friendly style using `(* ram_style = "block" *)` memory arrays. They are prototypes only and are not integrated into either `cpu_core` or `cpu_core_multicycle`.

## BRAM-Style Instruction Memory

`bram_instr_mem` provides:

- parameterised width and depth,
- parameterised `$readmemh` init-file loading,
- 32-bit byte address input,
- word index derived from the byte address,
- synchronous instruction output,
- NOP/zero output for out-of-range reads.

The synchronous read means the requested instruction appears after a rising clock edge.

## BRAM-Style Data Memory

`bram_data_mem` provides:

- parameterised width and depth,
- 32-bit byte address input,
- synchronous write,
- synchronous read,
- `mem_read` and `mem_write` controls,
- word index derived from the byte address,
- zero output when `mem_read` is low or the address is out of range.

The data memory intentionally avoids a full memory reset loop. Resetting every word can prevent BRAM inference or create unnecessary logic. For deterministic testing, the testbench writes known values before reading them.

## Test Results

Standalone simulations passed in Vivado XSim 2026.1.

The full XSim regression also passed after adding these tests.

Transcript:

- `reports/simulation_transcripts/phase10c_xsim_regression_20260709_200053.txt`

### Instruction Memory Test

Files tested:

- `rtl/bram_instr_mem.sv`
- `tb/tb_bram_instr_mem.sv`
- `programs/add_test.mem`

Coverage:

- `$readmemh` loading from `programs/add_test.mem`,
- one-cycle synchronous read latency,
- byte-address to word-index mapping,
- unaligned addresses mapping through word addressing,
- out-of-range read returning NOP/zero.

Result:

- Tests run: 9
- Tests failed: 0
- `PHASE 10C BRAM INSTRUCTION MEMORY TEST PASSED`

### Data Memory Test

Files tested:

- `rtl/bram_data_mem.sv`
- `tb/tb_bram_data_mem.sv`

Coverage:

- one-cycle synchronous read latency,
- synchronous write,
- write/read word 0,
- write/read word 1,
- word 0 unchanged after word 1 write,
- unaligned byte addresses mapping to word addresses,
- `mem_read = 0` returning zero after a clock edge,
- disabled write not updating memory,
- out-of-range read returning zero,
- out-of-range write not corrupting valid memory.

Result:

- Tests run: 13
- Tests failed: 0
- `PHASE 10C BRAM DATA MEMORY TEST PASSED`

## Future CPU Integration Implications

The existing CPU cores are not modified yet because synchronous memory changes instruction and data timing.

A future BRAM-integrated multi-cycle CPU will likely need extra FSM states:

- `FETCH_ADDR`: drive the instruction address into BRAM.
- `FETCH_CAPTURE`: capture the instruction returned by synchronous instruction memory.
- `MEMORY_ADDR`: drive the data memory address and control signals.
- `MEMORY_CAPTURE`: capture LOAD data returned by synchronous data memory.

STORE timing may remain simpler than LOAD timing, but it still needs careful control so `mem_write`, address and write data are valid at the target clock edge.

## Expected Trade-Offs

Potential benefits:

- BRAM usage should increase from the current 0 BRAM baseline.
- LUT memory usage may reduce for larger instruction/data memories.
- Timing and routing may become more predictable.
- The memory implementation will better match FPGA hardware resources.

Potential costs:

- CPI may increase if extra memory states are required.
- Testbenches must account for synchronous memory latency.
- Control logic becomes more complex.
- Small memories may not always benefit from BRAM compared with distributed memory.

## Limitations

- These are standalone memory prototypes only.
- They are not yet integrated into `cpu_core_multicycle`.
- No existing CPU behaviour was changed.
- No instruction encodings were changed.
- No physical Basys 3 hardware validation has been performed.

## Recommendation For Phase 10D

If Phase 10C remains passing in the full regression, Phase 10D should integrate the BRAM-style instruction and data memory behaviour into a separate multi-cycle CPU path.

The safest next step is to keep the current verified `cpu_core_multicycle` unchanged and create a separate BRAM-integrated variant or wrapper. That would allow direct comparison of CPI, BRAM usage, LUT usage, timing slack and maximum frequency against the Phase 8G multi-cycle baseline.
