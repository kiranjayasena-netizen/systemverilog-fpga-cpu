# Project History

This document records the phase-by-phase development path for the `systemverilog-fpga-cpu` project. The README is intentionally shorter and links here for the detailed history.

## Early RTL Blocks

The project began with small, independently verified RTL modules:

- `alu.sv`
- `register_file.sv`
- `program_counter.sv`
- instruction and data memories
- `fetch_unit.sv`
- `instruction_decoder.sv`
- `control_unit.sv`

Each block was paired with a self-checking Vivado XSim testbench. Early waveform screenshots are stored under `docs/images/`.

## Integrated CPU

The first integrated CPU combined fetch, decode, control, register-file, ALU, memory and PC-update logic into a simple single-cycle-style custom-ISA CPU.

The integrated CPU verified:

- ADD, SUB, AND, OR, XOR and ADDI
- LOAD and STORE
- BEQ and JUMP
- signed `imm13` behaviour
- `x0` write protection
- invalid-opcode safety

This path had good simulated CPI but did not meet the Basys 3 100 MHz timing target in the early post-route implementation.

## Multi-Cycle CPU

Phase 8 introduced a separate multi-cycle CPU path to improve timing closure while preserving the custom ISA. The multi-cycle design broke instruction execution into several FSM-controlled steps.

Key results:

- Phase 8B created the separate multi-cycle skeleton.
- Phase 8C added arithmetic execution.
- Phase 8D added LOAD/STORE execution.
- Phase 8E added BEQ/JUMP control flow.
- Phase 8F ran full custom-ISA program verification.
- Phase 8G showed the separate multi-cycle CPU met the 100 MHz Basys 3 timing target.

## BRAM and Prefetch Development

Phase 10 and Phase 11 made the memory system more FPGA-realistic.

Phase 10 added BRAM-aware instruction and data memory work:

- standalone BRAM-style memory prototypes
- a BRAM-aware multi-cycle CPU path
- full custom-ISA verification
- synthesis and implementation evidence

Phase 11 added instruction prefetching and control-flow improvements:

- BRAM-aware prefetch CPU
- full custom-ISA simulation
- Basys 3 implementation
- control-flow optimised prefetch CPU

The Phase 11E control-flow optimised prefetch CPU was the best multi-cycle/prefetch result before full pipelining.

## Pipelined CPU Development

Phase 12 created the first full separate pipelined CPU path. It handled synchronous instruction/data BRAM, forwarding, load-use stalls, branch/jump flushing and architectural retirement.

Phase 13 then refined the five-stage pipeline:

- Phase 13A added timing-safe fast JUMP target requests.
- Phase 13B explored BEQ target prefetching, but it did not replace the preferred path.
- Phase 13C improved timing closure.
- Phase 13D tested a load-forwarding timing experiment, but the CPI cost made it unsuccessful.
- Phase 13E restructured forwarding paths and became the preferred five-stage architecture for later work.
- Phase 13H consolidated the Phase 13 study.
- Phase 13I used Vivado implementation strategies to reach a timing-clean 115.607 MHz estimate for the Phase 13 path.

At the fixed 100 MHz Basys 3 board clock, the Phase 13 forward-timing CPU became the best board-measured design, displaying `0087` MIPS.

## Six-Stage Pipeline

Phase 14 explored a deeper six-stage pipeline:

```text
IF -> ID -> OP -> EX -> MEM -> WB
```

Development was incremental:

- Phase 14A planned the architecture.
- Phase 14B created the six-stage skeleton.
- Phase 14C added arithmetic.
- Phase 14D added LOAD/STORE.
- Phase 14E added BEQ/JUMP redirects and wrong-path protection.
- Phase 14F measured simulation CPI.
- Phase 14G implemented the design on the Basys 3 target.

Phase 14G closed timing at 166.667 MHz and produced an estimated practical throughput of approximately 101.8 MIPS using simulation CPI. At the fixed 100 MHz board clock, however, the six-stage CPU measured about 63 MIPS because its CPI was worse on the measured workload.

This created the central project trade-off: higher Fmax does not automatically mean higher real throughput when CPI worsens.

## Hardware Bring-Up and Measurement

Phase 15 and Phase 16 made the CPUs observable on the physical Basys 3 board.

Phase 15 added:

- a slow-enable bring-up wrapper
- SW0 run enable
- SW1 slow mode
- BTNC reset
- LED pipeline/debug visibility
- sticky event LEDs for short retire/write/redirect pulses

Phase 16 added 7-segment hardware MIPS counters and comparison bitstreams. The Phase 14G six-stage CPU displayed approximately `0063` MIPS at the fixed 100 MHz board clock.

## Phase 17 Profiling and 100 MIPS Result

Phase 17 returned to the Phase 13 forward-timing five-stage CPU because it had the best fixed-100 MHz board result.

Key Phase 17 steps:

- Phase 17A added a hardware profiling wrapper for the Phase 13 CPU.
- Phase 17B confirmed board readings: `0087` MIPS, `0115` CPI x100 and `1250` control-flush x100.
- Phase 17C tested a direct EX-stage redirect optimisation, but the copy failed 10 ns timing and was not accepted.
- Phase 17D swept the original Phase 13 timing path and showed 8.650 ns / 115.607 MHz was timing-clean.
- Phase 17E generated a 115.000 MHz CPU clock using an RTL-instantiated MMCM and physically measured `0100` MIPS on the Basys 3.

Phase 17E did not modify the original Phase 13 CPU RTL. It clocked the known-good Phase 13 forward-timing CPU faster and used a 115,000,000-cycle one-second measurement window for the hardware MIPS counter.

Final distinction:

- Best fixed 100 MHz board result: Phase 13, approximately 87 MIPS.
- Best physical FPGA-measured result: Phase 17E, approximately 100 MIPS at 115 MHz.
- Best timing-estimated result: Phase 14G, approximately 101.8 MIPS.

## Phase 18 Simulation-to-FPGA Benchmark Alignment

Phase 18 created a shared benchmark flow so simulation and FPGA measurements can be compared with the same workload:

- `programs/final_benchmark.mem` is used in both XSim and the FPGA wrapper.
- `tb/tb_phase18_final_benchmark_forwardtiming.sv` measures enabled cycles, retired instructions and CPI using the same Phase 13 `retire_valid` signal used by the hardware MIPS counter.
- `fpga_top_phase18_forwardtiming_mmcm_benchmark` reuses the proven Phase 17E 115 MHz MMCM/MIPS-counter wrapper but overrides instruction memory with the final benchmark image.

The Phase 18 XSim run measured 20,000 enabled cycles, 16,174 retired instructions and CPI 1.236552. That predicts approximately 93.0 MIPS at 115 MHz for the aligned benchmark.

The Phase 18 FPGA wrapper closed timing at 115 MHz and generated a bitstream. The Basys 3 board measurement displayed `0093`, matching the simulation prediction of approximately 93.0 MIPS for the final benchmark.
