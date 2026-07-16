# Phase 17E High-Frequency Hardware Test Plan

## Purpose

Phase 17E defines a future hardware experiment for measuring the Phase 13 forward-timing CPU above the fixed 100 MHz Basys 3 board clock.

This phase is planning only. It does not add an MMCM, Clocking Wizard, new CPU RTL, branch prediction, target buffers or benchmark changes.

## Baseline

Current confirmed board result:

| Metric | Value |
| --- | ---: |
| CPU | Phase 13 forward-timing five-stage pipeline |
| Board clock | 100 MHz |
| Hardware MIPS | 87 |
| Implied CPI | ~1.15 |
| Ideal single-issue 100 MHz limit | 100 MIPS |

At 100 MHz, single-issue throughput cannot exceed 100 MIPS. The confirmed 87 MIPS result means the next two paths are:

- reduce CPI at 100 MHz, or
- run the same low-CPI Phase 13 CPU above 100 MHz.

## Frequency Targets

Using the confirmed board-implied CPI of about 1.15:

| Goal | Required frequency |
| --- | ---: |
| Reach 100 MIPS | ~115 MHz |
| Beat Phase 14G estimated 101.8 MIPS | ~117.1 MHz |

The existing Phase 13I timing result closed at 8.650 ns, or 115.607 MHz. If the board workload keeps CPI near 1.15 at that frequency, the timing estimate is:

```text
115.607 MHz / 1.15 CPI = 100.5 MIPS
```

That is not yet a physical hardware measurement.

## Proposed Hardware Method

A future Phase 17E implementation should:

1. Add a separate high-frequency wrapper for the Phase 13 forward-timing CPU.
2. Use an MMCM or Clocking Wizard to generate a faster CPU clock from the 100 MHz board oscillator.
3. Keep the seven-segment display and human-facing control logic either in the 100 MHz clock domain or correctly synchronised.
4. Synchronise BTNC reset and switches into the CPU clock domain.
5. Reuse the hardware MIPS counter, adjusted so the measurement window uses the actual CPU clock frequency.
6. Add correct generated-clock timing constraints.
7. Build separate bitstreams for candidate CPU clocks such as 115 MHz, 117 MHz and 120 MHz.

## Constraints Requirements

The implementation must include:

- a generated clock constraint for the MMCM output;
- timing paths checked in the CPU clock domain;
- reset and switch synchronisers for the CPU clock domain;
- either clock-domain crossing synchronisers or a single-domain display/counter design;
- no false-path or multicycle exceptions unless they are architecturally justified.

## Measurement

The hardware MIPS counter should still use:

```text
MIPS = retired instructions in one measured second / 1,000,000
```

At a faster CPU clock, the one-second window must be based on the CPU clock frequency, not assumed to be 100,000,000 cycles.

## Risks

- The design may pass timing in Vivado but behave unstably on the physical board if clocks or resets are constrained incorrectly.
- The display and MIPS counter can be wrong if the CPU clock and display clock domains are mixed without synchronisation.
- A higher frequency may expose marginal routing or hold issues.
- The measured CPI may change if the benchmark or measurement wrapper changes.
- The board measurement still depends on the instruction program loaded into instruction memory.

## Recommendation

Run Phase 17B first and record the bottleneck display values. If CPI loss is small and the bottleneck is not obvious, Phase 17E is worth implementing because the existing Phase 13I timing result already suggests the Phase 13 CPU may reach about 100 MIPS if physically clocked near 115 MHz.
