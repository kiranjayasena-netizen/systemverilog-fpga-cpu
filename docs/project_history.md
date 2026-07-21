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

## Phase 19 Past-100-MIPS Attempts

Phase 19 keeps the confirmed Phase 17E result honest by separating timing-clean candidates from physical board measurements, then records the successful Phase 19A and Phase 19B board readings.

Phase 19A created separate MMCM wrappers for the original Phase 13 forward-timing CPU at 115.5, 116.0, 116.5 and 117.0 MHz. All four targets closed timing and generated bitstreams. The 117.0 MHz board test displayed `0102`, approximately 102 MIPS, making Phase 19A the strongest real board-measured result at that stage.

Phase 19B created a high-frequency MMCM/MIPS-counter wrapper for the Phase 14G six-stage CPU. The 150, 155 and 160 MHz targets closed timing and generated bitstreams. The 160 MHz board test displayed `0101`, approximately 101 MIPS. The 166.667 MHz target failed setup timing in the new hardware-measurement wrapper, so it is not valid board evidence.

Phase 19C documented the aligned-benchmark requirement. With the Phase 18 CPI of 1.236552, the aligned benchmark needs about 123.655 MHz to reach 100 MIPS, or it needs CPI to improve to 1.15 or better at 115 MHz.

## Phase 20 Real Performance Improvement Work

Phase 20 starts from the confirmed Phase 19A 102 MIPS board result and tries to improve real CPU performance without overwriting proven baselines.

The first Phase 20 CPU copy, `cpu_core_pipeline_forwardtiming_phase20`, adds conservative static backward-BEQ prediction. Focused XSim correctness passed, but the aligned `programs/final_benchmark.mem` CPI remained 1.236552, matching Phase 18. This showed that the safe prediction experiment did not help the final benchmark because its hot loop already relies on the earlier JUMP path and forward BEQs.

Phase 20E then extended the original Phase 13 CPU frequency path. The 118.5 MHz target passed timing and displayed `0103`; the 119.0 MHz target passed timing and displayed `0104`. This made Phase 20E the strongest physical board-measured result at approximately 104 MIPS. The 117.5 and 118.0 MHz runs failed setup timing in their specific implementation attempts, and the 120.0 MHz target was left for future selective testing.

Phase 20 also documented the Phase 19B 166.667 MHz six-stage timing failure.

## Phase 21 CPI-Focused Follow-Up

Phase 21 continues the post-104-MIPS work with a copied Phase 13-derived CPU:

- `rtl/cpu_core_pipeline_forwardtiming_phase21.sv`
- `tb/tb_phase21_forwardtiming_correctness.sv`
- `tb/tb_phase21_final_benchmark.sv`

The Phase 21 copy keeps the original Phase 13 CPU RTL untouched and tests conservative static backward-BEQ prediction plus a load-use hazard audit. Focused XSim correctness passed with 26 checks and 0 failures.

On the aligned `programs/final_benchmark.mem` workload, CPI remained `1.236552`, matching the Phase 18 baseline. The predicted aligned-benchmark throughput therefore stayed at approximately 93.001 MIPS at 115 MHz and 96.235 MIPS at 119 MHz.

Phase 21 also prepared:

- copied-CPU MMCM benchmark scripts for 115, 117, 119 and 120 MHz;
- original Phase 20E frequency-extension scripts for 119.5, 120.0, 120.5 and 121.0 MHz;
- a follow-up analysis of the Phase 19B six-stage 166.667 MHz timing failure.

No new Phase 21 board MIPS result is claimed. Phase 20E remains the best confirmed physical result at approximately 104 MIPS.

## Phase 22 Frontend CPI Experiment

Phase 22 targets the real aligned-benchmark hot path after Phase 21 showed that broad backward-BEQ prediction did not help. A copied CPU, `cpu_core_pipeline_forwardtiming_phase22`, adds a one-entry unconditional JUMP target cache.

The cache learns a JUMP PC and target, pre-requests the target when that JUMP PC is fetched again, and consumes the already-returning target response when the JUMP is decoded. A directed XSim test includes a repeated backward-JUMP loop to exercise this path.

Phase 22 correctness passed with 29 checks and 0 failures. The aligned benchmark CPI improved from `1.236552` to `1.181963`, predicting about 100.680 MIPS at 119 MHz. The 119 MHz Vivado implementation failed setup timing with WNS `-1.258 ns`, so no Phase 22 hardware result is claimed.

Phase 20E remains the best confirmed physical result at approximately 104 MIPS.

## Phase 23 Retimed JUMP-Cache Timing Experiment

Phase 23 follows the Phase 22 result with another copied CPU, `cpu_core_pipeline_forwardtiming_phase23`. It keeps the one-entry unconditional JUMP target cache idea but registers predictor hit and target metadata before the frontend uses the prediction.

Focused XSim correctness again passed with 29 checks and 0 failures. The aligned benchmark CPI remained `1.181963`, matching Phase 22 and preserving the 4.415% improvement over the Phase 18/21 baseline.

Vivado timing improved compared with Phase 22 at 119 MHz:

- Phase 22 119 MHz WNS: `-1.258 ns`
- Phase 23 119 MHz WNS: `-0.981 ns`

However, Phase 23 still failed setup timing at 119, 117 and 115 MHz, so no bitstream was generated and no board result is claimed. Phase 20E remains the best confirmed physical result at approximately 104 MIPS.

## Phase 24 Frontend-Split Timing-Friendly Experiment

Phase 24 follows the Phase 22/23 timing failures with a cleaner copied CPU experiment, `cpu_core_pipeline_forwardtiming_phase24`. Instead of another predictor retiming patch, the copied CPU registers the instruction-memory request PC and request-valid state so the frontend request path is structurally separated from immediate redirect selection.

Focused XSim correctness passed with 29 checks and 0 failures. The experiment preserved architectural correctness for arithmetic, LOAD/STORE, BEQ, JUMP, wrong-path side-effect protection, x0 protection and pause/resume behavior.

The aligned benchmark result was not an improvement:

- Phase 18/21 CPI: `1.236552`
- Phase 22/23 CPI: `1.181963`
- Phase 24 CPI: `1.508978`

Vivado closed timing at 100 and 105 MHz, but the 110 MHz implementation failed with WNS `-0.574 ns` and TNS `-162.224 ns`. The 115, 117 and 119 MHz targets were not run.

Phase 24 is therefore a useful timing/CPI trade-off result rather than a performance replacement. It shows that splitting the frontend too conservatively can add more fetch latency than it saves, and Phase 20E remains the best confirmed physical FPGA result.
