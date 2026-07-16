# Performance Results

This page summarises the current CPU verification, FPGA implementation and hardware performance evidence for the `systemverilog-fpga-cpu` project.

The project now has three distinct kinds of performance evidence:

- Self-checking Vivado XSim simulations prove custom-ISA correctness and measure CPI.
- Vivado post-route timing reports show the highest timing-clean clock frequencies reached by each FPGA implementation path.
- Basys 3 hardware measurements use FPGA-resident counters and the 7-segment display to measure real board throughput at the fixed 100 MHz board clock.

The main performance formula is:

```text
MIPS = clock frequency in MHz / CPI
```

## Current Best Results

| Category | Result |
| --- | ---: |
| Best 100 MHz board-measured MIPS | Phase 13, approximately 87 MIPS |
| Phase 14G board-measured MIPS at 100 MHz | approximately 63 MIPS |
| Phase 14G post-route timing-clean frequency | 166.667 MHz |
| Phase 14G estimated peak practical MIPS | approximately 101.8 MIPS |
| Phase 16A 7-seg measured value | `0063` |
| Target FPGA board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |

The project now reports both board-measured throughput at the fixed 100 MHz Basys 3 clock and post-route timing-estimated peak throughput. These are intentionally separate because they answer different questions.

## Hardware-Measured Board Results

These results were measured on the Basys 3 FPGA using the 100 MHz board clock and FPGA-resident MIPS counter / 7-segment display experiments.

Calculated CPI uses:

```text
CPI = 100 / hardware-measured MIPS
```

| CPU version | Hardware-measured MIPS at 100 MHz | Calculated CPI |
| --- | ---: | ---: |
| Phase 8 MC | 26 | 3.85 |
| Phase 10 BRAM + MC | 21 | 4.76 |
| Phase 11E Control Optimised | 35 | 2.86 |
| Phase 12 Pipeline, 5 Stage | 77 | 1.30 |
| Phase 13 Forward Timing | 87 | 1.15 |
| Phase 14G Pipeline, 6 Stage | 63 | 1.59 |

At the fixed 100 MHz Basys 3 board clock, the Phase 13 five-stage forwarded pipeline produced the best measured hardware throughput, around 87 MIPS. The Phase 14G six-stage pipeline measured around 63 MIPS at the same board clock. This does not mean the six-stage design failed; it shows a CPI versus clock-frequency trade-off. The six-stage design increased the maximum timing-clean frequency, but its deeper pipeline increased CPI on the measured benchmark.

A deeper pipeline does not automatically produce more MIPS at the same clock frequency. The six-stage pipeline can improve maximum clock frequency by reducing logic per stage, but it can also increase pipeline overhead, branch/jump flush penalties, load-use penalties and fill/drain overhead. Therefore, at 100 MHz, the design with the lower CPI wins.

## Phase 13 Versus Phase 14G

| Metric | Phase 13 five-stage pipeline | Phase 14G six-stage pipeline |
| --- | ---: | ---: |
| Hardware measured at 100 MHz | approximately 87 MIPS | approximately 63 MIPS |
| Implied hardware CPI | approximately 1.15 | approximately 1.59 |
| Post-route timing-clean frequency | 115.607 MHz in Phase 13I | 166.667 MHz |
| Simulation CPI used for timing estimate | 1.339 | 1.638 |
| Estimated peak practical MIPS | approximately 86.4 MIPS | approximately 101.8 MIPS |

Phase 13 is the strongest result for fixed 100 MHz Basys 3 board operation. Phase 14G is the strongest result for timing closure and estimated peak frequency.

Break-even calculation for Phase 14G versus the Phase 13 board-measured result:

```text
required frequency = 87 MIPS * 1.638 CPI = 142.5 MHz
```

Since Phase 14G closed timing at 166.667 MHz, the timing estimate suggests it could exceed Phase 13 if the board implementation is clocked above approximately 142.5 MHz. The current physical hardware MIPS display measurement was performed at 100 MHz.

Conclusion:

- At the fixed 100 MHz board clock, Phase 13 is the best hardware-measured design.
- For timing closure and estimated peak frequency, Phase 14G is the strongest design.
- The project demonstrates a real CPU engineering trade-off between CPI and maximum clock frequency.

## Phase 17 Direction

Phase 17 returns to the Phase 13 forward-timing CPU because it is the best fixed-100 MHz board-measured path:

```text
Phase 13 board-measured throughput ~= 87 MIPS
Phase 13 implied CPI ~= 1.15
Phase 13 control-flush display ~= 1250, or 12.50%
```

The goal is not to replace the Phase 14G timing evidence. The goal is to understand why Phase 13 retires about 87 million instructions per second at the 100 MHz board clock rather than approaching the 100 MIPS theoretical limit for CPI 1.0.

The Phase 17B hardware profiler confirmed:

| Metric | Display | Meaning |
| --- | ---: | --- |
| MIPS | 0087 | approximately 87 MIPS |
| CPI x100 | 0115 | approximately 1.15 CPI |
| Control flush percentage x100 | 1250 | approximately 12.50% |

The control-flush reading explains most of the gap between the ideal 100 MIPS and the measured 87 MIPS fixed-clock result.

Phase 17 separates three performance questions:

- Board-measured 100 MHz MIPS: what the Basys 3 physically displays with the fixed board clock.
- Timing-estimated peak MIPS: what post-route timing suggests if the design is clocked faster.
- Future high-frequency measured MIPS: what a later MMCM/Clocking Wizard board experiment could physically measure above 100 MHz.

Planned Phase 17 flow:

| Phase | Purpose |
| --- | --- |
| Phase 17A | Add a Phase 13 hardware profiler with MIPS and CPI x100 display modes |
| Phase 17B | Expand hardware display modes for load-use, control-flush, fetch-wait and memory-wait bottleneck readings |
| Phase 17C | Tested a direct EX-stage branch-target request optimisation in a separate CPU copy |
| Phase 17D | Swept the original Phase 13 forward-timing path above 100 MHz |
| Phase 17E | Plan a future high-frequency hardware measurement |

The Phase 17C experiment improved aggregate simulation CPI slightly, from 1.339 to 1.329, but failed post-route 10 ns timing with WNS -0.552 ns and TNS -2.159 ns. The original Phase 13 core already had ID-stage fast-JUMP handling, so the experiment instead tried a direct EX-stage redirect target request. That path was too timing-expensive and is therefore not accepted as a hardware performance improvement. Phase 13E/13I remains the preferred five-stage CPU implementation.

The existing Phase 13I timing-clean result of 115.607 MHz is important for Phase 17D. If the confirmed board-implied CPI of about 1.15 holds at that higher clock, the estimated throughput is:

```text
115.607 MHz / 1.15 CPI = approximately 100.5 MIPS
```

Phase 17D ran the next important target, 8.500 ns, on the original Phase 13 forward-timing CPU. The result was:

| Period | Frequency | Strategy | WNS | TNS | WHS | Status | Estimated MIPS using CPI 1.15 |
| ---: | ---: | --- | ---: | ---: | ---: | --- | ---: |
| 8.650 ns | 115.607 MHz | fanout_opt | +0.059 ns | 0.000 ns | +0.057 ns | pass | 100.5 |
| 8.500 ns | 117.647 MHz | fanout_opt | -0.412 ns | -36.784 ns | +0.009 ns | failed setup | invalid |

This means 100 MIPS is timing-supported for the original Phase 13 CPU, but beating the Phase 14G estimated 101.8 MIPS is not timing-supported by Phase 17D. This is still a timing estimate, not a physical high-frequency board measurement. A future MMCM/Clocking Wizard hardware test is needed to prove it on the Basys 3.

## Simulation Comparison

Representative simulation results from the project are below. These are not all measured on the same hardware wrapper; they are primarily useful for comparing CPI trends during architecture development.

| CPU path | Simulation cycles | Retired/completed instructions | CPI | MIPS at 100 MHz from simulation CPI |
| --- | ---: | ---: | ---: | ---: |
| Original single-cycle-style CPU | 54 | 54 | 1.000 | 100.000 |
| Phase 8 multi-cycle CPU | 202 | 54 | 3.741 | 26.733 |
| Phase 10G BRAM-aware multi-cycle CPU | 271 | 58 | 4.672 | 21.402 |
| Phase 11B BRAM prefetch CPU | 179 | 58 | 3.086 | 32.402 |
| Phase 11D control-flow optimised prefetch CPU | 173 | 58 | 2.983 | 33.526 |
| Phase 12 five-stage pipeline | 457 | 319 | 1.433 | 69.803 |
| Phase 13A fast-JUMP pipeline | 427 | 319 | 1.339 | 74.707 |
| Phase 13B BEQ-prefetch pipeline | 424 | 319 | 1.329 | 75.236 |
| Phase 13E / 13I forwarding-timing pipeline | 427 | 319 | 1.339 | 74.707 |
| Phase 17C direct EX redirect experiment | 424 | 319 | 1.329 | 75.236 |
| Phase 14F / 14G six-stage pipeline | 95 | 58 | 1.638 | 61.050 |

The original single-cycle-style CPU has excellent simulated CPI, but the early FPGA implementation did not meet 100 MHz timing. Later designs trade CPI, timing closure and BRAM structure against each other.

## Phase 15A / 15B Hardware Evidence

Phase 15A added a Basys 3 slow-enable bring-up wrapper for the Phase 14G CPU:

- SW0 is run enable.
- SW1 selects slow mode.
- BTNC is reset.
- `LED[3:0]` shows fetch PC word index.
- `LED[8:4]` shows pipeline valid bits.

Phase 15B made the event LEDs useful for physical evidence by adding sticky capture:

- `LD10` latches when a branch/jump redirect occurs.
- `LD11` latches when an instruction retires.
- `LD12` latches when a register write occurs.
- Sticky LEDs remain on when SW0 is turned off, proving pause/freeze while preserving evidence.
- BTNC reset clears the sticky LEDs.

## Phase 16A Hardware MIPS Measurement

Phase 16A added a hardware MIPS counter and Basys 3 7-segment display output.

The FPGA counts retired instructions using the CPU `retire_valid` debug signal. It also counts a one-second measurement window using the 100 MHz board clock. MIPS is calculated as:

```text
MIPS = retired instructions in one second / 1,000,000
```

The 7-segment display showed:

```text
0063
```

This corresponds to approximately 63 MIPS at the 100 MHz board clock:

```text
CPI = 100 / 63 = approximately 1.59
```

That is close to the Phase 14F/14G simulation CPI estimate of approximately 1.638.

The 63 MIPS value is a direct hardware measurement at the 100 MHz Basys 3 board clock. It should not be confused with the Phase 14G post-route timing estimate of approximately 101.8 MIPS, which assumes a 166.667 MHz clock.

## Limitations

- The hardware MIPS counter currently measures at the 100 MHz board clock.
- The Phase 16A measurement does not prove 166.667 MHz physical operation.
- The measured MIPS depends on the benchmark program loaded into instruction memory.
- The 7-segment display currently shows integer MIPS, so fractional precision is lost.
- Future work could add an MMCM or Clocking Wizard experiment to measure at higher hardware frequencies.
- Future work could use a benchmark program identical to the simulation benchmark for stricter comparison.

## Recommended Future Work

- Phase 16B: benchmark alignment so simulation and hardware use the same workload.
- Phase 16C: optional MMCM or Clocking Wizard high-frequency hardware MIPS test.
- Phase 16D: UART or ILA output for detailed performance counters.
- Final report: architecture diagrams, pipeline diagrams, performance plots and board evidence photos.
