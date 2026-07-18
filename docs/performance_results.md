# Performance Results

This page summarises the current CPU verification, FPGA implementation and hardware performance evidence for the `systemverilog-fpga-cpu` project.

The project now has three distinct kinds of performance evidence:

- Self-checking Vivado XSim simulations prove custom-ISA correctness and measure CPI.
- Vivado post-route timing reports show the highest timing-clean clock frequencies reached by each FPGA implementation path.
- Basys 3 hardware measurements use FPGA-resident counters and the 7-segment display to measure real board throughput, first at the fixed 100 MHz board clock and later with MMCM-generated higher CPU clocks.

The main performance formula is:

```text
MIPS = clock frequency in MHz / CPI
```

## Current Best Results

| Category | Result |
| --- | ---: |
| Best physical FPGA-measured MIPS | Phase 20E, approximately 104 MIPS at 119.000 MHz |
| Best 100 MHz board-measured MIPS | Phase 13, approximately 87 MIPS |
| Phase 14G board-measured MIPS at 100 MHz | approximately 63 MIPS |
| Phase 14G high-frequency board-measured MIPS | Phase 19B, approximately 101 MIPS at 160.000 MHz |
| Phase 14G timing-estimated peak practical MIPS | approximately 101.8 MIPS |
| Phase 20E 7-seg measured value | `0104` |
| Phase 19A 7-seg measured value | `0102` |
| Phase 19B 7-seg measured value | `0101` |
| Phase 17E 7-seg measured value | `0100` |
| Target FPGA board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |

The project now reports fixed-100 MHz board throughput, high-frequency MMCM board throughput and post-route timing-estimated peak throughput. These are intentionally separate because they answer different questions.

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

## Phase 17E Hardware-Measured 100 MIPS Result

Phase 17E physically confirmed the 100 MIPS milestone on the Basys 3.

| Item | Value |
| --- | ---: |
| CPU | Original Phase 13 forward-timing five-stage pipeline |
| Clock source | RTL-instantiated MMCM |
| Generated CPU clock | 115.000 MHz |
| Measurement window | 115,000,000 generated CPU-clock cycles |
| Display mode | SW3:SW1 = `000` |
| Observed 7-seg value | `0100` |
| Interpretation | approximately 100 MIPS |

This confirms the Phase 17D timing-supported estimate. Phase 17D showed that the original Phase 13 path passed timing at 8.650 ns / 115.607 MHz, giving approximately 100.5 MIPS using the board-measured CPI of 1.15. Phase 17E then tested the same idea physically using a 115 MHz MMCM-generated CPU clock.

The Phase 17E value was the first physical 100 MIPS board result. Phase 19A later extended the same original Phase 13 CPU path to approximately 102 MIPS at 117 MHz.

## Phase 19A Hardware-Measured 102 MIPS Result

Phase 19A extended the Phase 17E high-frequency hardware wrapper for the original Phase 13 CPU and physically measured a higher integer MIPS value.

| Item | Value |
| --- | ---: |
| CPU | Original Phase 13 forward-timing five-stage pipeline |
| Clock source | RTL-instantiated MMCM |
| Generated CPU clock | 117.000 MHz |
| Measurement window | 117,000,000 generated CPU-clock cycles |
| Display mode | SW3:SW1 = `000` |
| Observed 7-seg value | `0102` |
| Interpretation | approximately 102 MIPS |
| Timing result | WNS +0.016 ns, TNS 0.000 ns, WHS +0.114 ns, THS 0.000 ns |

This was the best physical FPGA-measured result at the end of Phase 19A. Phase 20E later extended the same original Phase 13 CPU path to `0104`, approximately 104 MIPS. The display is integer MIPS, so these results should not be stated as exact fractional values.

## Phase 20E Hardware-Measured 104 MIPS Result

Phase 20E extended the original Phase 13 / Phase 19A path to higher MMCM frequencies without changing the original CPU RTL.

| Item | Value |
| --- | ---: |
| CPU | Original Phase 13 forward-timing CPU |
| Clock source | RTL-instantiated MMCM |
| CPU clock | 119.000 MHz |
| MIPS counter window | 119,000,000 CPU-clock cycles |
| Display mode | SW3:SW1 = `000` |
| Observed 7-seg value | `0104` |
| Interpretation | approximately 104 MIPS |

Timing for the tested passing Phase 20E candidates:

| CPU clock | WNS | TNS | WHS | THS | Board display |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 118.500 MHz | +0.004 ns | 0.000 ns | +0.035 ns | 0.000 ns | `0103` |
| 119.000 MHz | +0.003 ns | 0.000 ns | +0.086 ns | 0.000 ns | `0104` |

Phase 20E is now the strongest physical FPGA-measured project result.

## Phase 19B High-Frequency Six-Stage Hardware Result

Phase 19B physically measured the Phase 14G six-stage CPU above the fixed 100 MHz board clock.

| Item | Value |
| --- | ---: |
| CPU | Phase 14G six-stage pipeline |
| Clock source | RTL-instantiated MMCM |
| Generated CPU clock | 160.000 MHz |
| Measurement window | 160,000,000 generated CPU-clock cycles |
| Display mode | SW3:SW1 = `000` |
| Observed 7-seg value | `0101` |
| Interpretation | approximately 101 MIPS |
| Timing result | WNS +0.139 ns, TNS 0.000 ns, WHS +0.038 ns, THS 0.000 ns |

This is the first physical high-frequency board measurement for the six-stage path. It does not prove the older Phase 14G 166.667 MHz / approximately 101.8 MIPS timing estimate, because the Phase 19B 166.667 MHz hardware-measurement wrapper failed setup timing.

## Phase 18 Benchmark Alignment

Phase 18 adds a fairness check between simulation and FPGA measurement by using the exact same program image in both environments:

- shared benchmark: `programs/final_benchmark.mem`;
- simulation testbench: `tb/tb_phase18_final_benchmark_forwardtiming.sv`;
- FPGA top: `fpga_top_phase18_forwardtiming_mmcm_benchmark`;
- report: `reports/phase18_sim_fpga_benchmark_alignment.md`.

The aligned benchmark is heavier than the earlier Phase 17E FPGA demo workload, so it is not expected to show `0100` MIPS. It is intended to answer whether simulation and hardware agree when the workload is identical.

| Metric | Value |
| --- | ---: |
| XSim enabled cycles | 20,000 |
| XSim retired instructions | 16,174 |
| XSim CPI | 1.236552 |
| Predicted MIPS at 100 MHz | 80.870 |
| Predicted MIPS at 115 MHz | 93.001 |
| Phase 18 Vivado WNS/TNS | +0.014 ns / 0.000 ns |
| Phase 18 Vivado WHS/THS | +0.036 ns / 0.000 ns |
| Phase 18 bitstream | generated |
| Phase 18 board MIPS | `0093`, approximately 93 MIPS |

The Phase 18 board test displayed `0093` in MIPS mode at 115 MHz. This matches the XSim prediction of 93.001 MIPS within the integer precision of the 7-segment display.

## Phase 19 Past-100-MIPS Results

Phase 19 created new high-frequency wrappers and produced two physical board measurements above 100 MIPS.

Phase 19A sweeps the original Phase 13 forward-timing CPU slightly above 115 MHz using separate MMCM wrappers:

| Target clock | WNS | TNS | WHS | THS | Bitstream | Board MIPS |
| ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 115.500 MHz | +0.015 ns | 0.000 ns | +0.034 ns | 0.000 ns | generated | not recorded |
| 116.000 MHz | +0.062 ns | 0.000 ns | +0.035 ns | 0.000 ns | generated | not recorded |
| 116.500 MHz | +0.013 ns | 0.000 ns | +0.094 ns | 0.000 ns | generated | not recorded |
| 117.000 MHz | +0.016 ns | 0.000 ns | +0.114 ns | 0.000 ns | generated | `0102` |

Phase 19B creates high-frequency hardware-test wrappers for the Phase 14G six-stage CPU:

| Target clock | WNS | TNS | WHS | THS | Bitstream | Board MIPS |
| ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 150.000 MHz | +0.182 ns | 0.000 ns | +0.033 ns | 0.000 ns | generated | not recorded |
| 155.000 MHz | +0.096 ns | 0.000 ns | +0.033 ns | 0.000 ns | generated | not recorded |
| 160.000 MHz | +0.139 ns | 0.000 ns | +0.038 ns | 0.000 ns | generated | `0101` |
| 166.667 MHz | -0.102 ns | -0.287 ns | +0.098 ns | 0.000 ns | skipped | invalid |

Phase 19C records the aligned-benchmark requirement: with Phase 18 CPI = 1.236552, the aligned benchmark needs 123.655 MHz to reach 100 MIPS. At 115 MHz, that same benchmark would need CPI 1.15 or better.

Phase 19 should be read with the benchmark/program clearly identified:

- Phase 19A 117 MHz is a confirmed physical Phase 13 demo-workload result: `0102`.
- Phase 19B 160 MHz is a confirmed physical Phase 14G demo-workload result: `0101`.
- The 166.667 MHz Phase 19B wrapper failed setup timing and is not valid hardware evidence.

## Phase 13 Versus Phase 14G

| Metric | Phase 13 five-stage pipeline | Phase 14G six-stage pipeline |
| --- | ---: | ---: |
| Hardware measured at 100 MHz | approximately 87 MIPS | approximately 63 MIPS |
| Implied hardware CPI | approximately 1.15 | approximately 1.59 |
| Best physical measured result | Phase 20E: approximately 104 MIPS at 119 MHz | Phase 19B: approximately 101 MIPS at 160 MHz |
| Post-route timing-clean frequency | 115.607 MHz in Phase 13I | 166.667 MHz |
| Simulation CPI used for timing estimate | 1.339 | 1.638 |
| Historical simulation-CPI timing estimate | approximately 86.4 MIPS | approximately 101.8 MIPS |

Phase 13 is the strongest physically measured result after the Phase 20E MMCM test. Phase 14G is physically measured at approximately 101 MIPS in Phase 19B, but its older 166.667 MHz / approximately 101.8 MIPS estimate has not been demonstrated on the board because the 166.667 MHz Phase 19B measurement wrapper failed timing.

Break-even calculation for Phase 14G versus the Phase 13 board-measured result:

```text
required frequency = 87 MIPS * 1.638 CPI = 142.5 MHz
```

Since Phase 14G closed timing at 166.667 MHz in its earlier implementation path, the timing estimate suggested it could exceed the 100 MHz Phase 13 result if the board implementation were clocked above approximately 142.5 MHz. Phase 19B physically tested the six-stage CPU at 160 MHz and displayed `0101`, but the 166.667 MHz measurement wrapper did not close timing.

Conclusion:

- At the fixed 100 MHz board clock, Phase 13 is the best hardware-measured design.
- Across all physical FPGA measurements so far, Phase 20E's 119 MHz Phase 13 result is the best real board result at about 104 MIPS.
- Phase 19B gives the best six-stage physical measurement so far at about 101 MIPS.
- The older Phase 14G 166.667 MHz / 101.8 MIPS result remains timing-estimated only.
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
- High-frequency measured MIPS: what the Phase 17E MMCM board experiment physically measures above 100 MHz.

Phase 17 flow:

| Phase | Purpose |
| --- | --- |
| Phase 17A | Add a Phase 13 hardware profiler with MIPS and CPI x100 display modes |
| Phase 17B | Expand hardware display modes for load-use, control-flush, fetch-wait and memory-wait bottleneck readings |
| Phase 17C | Tested a direct EX-stage branch-target request optimisation in a separate CPU copy |
| Phase 17D | Swept the original Phase 13 forward-timing path above 100 MHz |
| Phase 17E | Confirmed approximately 100 MIPS on hardware with a 115 MHz MMCM-driven Phase 13 CPU |

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

This means 100 MIPS is timing-supported for the original Phase 13 CPU, but beating the Phase 14G estimated 101.8 MIPS is not timing-supported by Phase 17D. This is still a timing estimate, not a physical high-frequency board measurement.

Phase 17E converted that estimate into a board-tested bitstream. It uses an RTL-instantiated MMCM to generate a 115.000 MHz CPU clock from the 100 MHz Basys 3 clock, keeps the original Phase 13 CPU RTL unchanged, and displays measured MIPS on the 7-segment display. The implementation is timing-clean:

| CPU clock | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Bitstream |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |
| 115.000 MHz | +0.008 ns | 0.000 ns | +0.035 ns | 0.000 ns | 1,829 | 2,072 | 1 tile / 2 RAMB18 | 0 | generated |

Confirmed board readings for Phase 17E:

| Display mode | Value | Meaning |
| --- | ---: | --- |
| MIPS | `0100` | approximately 100 MIPS |
| CPI x100 | `0115` | approximately 1.15 CPI |
| Control flush x100 | `1250` | approximately 12.50% |

The Phase 17E physical board result confirms approximately 100 MIPS on the original Phase 13 forward-timing CPU.

## Phase 20 Performance Improvement Pass

Phase 20 begins the next improvement pass after the confirmed Phase 19A `0102` / approximately 102 MIPS board result. The copied CPU CPI experiment does not improve the aligned benchmark, but the Phase 20E original-CPU frequency extension does replace Phase 19A as the best physical board result.

The Phase 20 copied CPU path adds conservative static backward-BEQ prediction in `rtl/cpu_core_pipeline_forwardtiming_phase20.sv`. Focused XSim correctness passed with 26 checks and 0 failures. The aligned benchmark CPI did not improve:

| Design | Benchmark | CPI | Predicted MIPS at 115 MHz | Predicted MIPS at 117 MHz |
| --- | --- | ---: | ---: | ---: |
| Phase 18 baseline | `final_benchmark.mem` | 1.236552 | 93.001 | 94.618 |
| Phase 20 copied CPU | `final_benchmark.mem` | 1.236552 | 93.001 | 94.618 |

The result is useful because it shows the first safe branch-prediction attempt did not help this particular benchmark: the hot loop already uses the early JUMP path and forward BEQs, so backward-BEQ prediction does not reduce the main loop cost.

Phase 20 also prepares:

- original-CPU Phase 19A frequency-extension scripts for 117.5, 118.0, 118.5, 119.0 and 120.0 MHz;
- Phase 20 copied-CPU MMCM benchmark scripts for 115, 117, 118, 119 and 120 MHz;
- a six-stage Phase 19B 166.667 MHz timing analysis report.

The original-CPU Phase 20E frequency extension physically displayed `0103` at 118.5 MHz and `0104` at 119.0 MHz. The `0104` result is now the best physical board result.

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

- The Phase 16A measurement does not prove 166.667 MHz physical operation.
- The measured MIPS depends on the benchmark program loaded into instruction memory.
- The 7-segment display currently shows integer MIPS, so fractional precision is lost.
- Phase 16A measured at the 100 MHz board clock; Phase 17E added a 115 MHz MMCM-generated hardware measurement for the Phase 13 CPU; Phase 19A extended that path to 117 MHz; Phase 20E extended it to 119 MHz.
- Future work could test additional MMCM frequencies or use UART/ILA for richer counter output.
- Future work could use a benchmark program identical to the simulation benchmark for stricter comparison.

## Recommended Future Work

- Capture photo/video evidence for the Phase 20E `0104`, Phase 19A `0102` and Phase 19B `0101` board displays.
- Consider a stricter benchmark-aligned Phase 19 follow-up if the final benchmark, rather than the demo workload, must exceed 100 MIPS.
- UART or ILA output for detailed hardware performance counters.
- Final report: architecture diagrams, pipeline diagrams, performance plots and board evidence photos.
