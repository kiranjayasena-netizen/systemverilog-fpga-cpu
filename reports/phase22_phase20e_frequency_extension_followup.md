# Phase 22 Phase 20E Frequency Extension Follow-Up

## Purpose

Phase 22F records the optional MHz-only follow-up to the Phase 20E original-CPU path. This is not the main Phase 22 optimisation, and it was not run in this pass.

## Baseline

| Metric | Value |
| --- | ---: |
| Best physical result | Phase 20E |
| CPU | Original Phase 13 forward-timing CPU |
| Clock | 119.000 MHz |
| Board display | `0104` |
| Timing | WNS +0.003 ns, TNS 0.000 ns, WHS +0.086 ns |

Phase 20E had very small positive slack at 119 MHz. Further MHz-only improvement is therefore risky and should be tested selectively.

## Candidate Targets

| Target clock | Purpose | Status |
| ---: | --- | --- |
| 119.5 MHz | tiny extension beyond Phase 20E | not run |
| 120.0 MHz | possible `0104`/`0105` display if timing passes | not run |
| 120.5 MHz | higher-risk extension | not run |
| 121.0 MHz | high-risk extension | not run |

## Rule for Any Future Test

A result is valid only if:

- WNS >= 0;
- TNS = 0;
- WHS >= 0;
- THS = 0;
- bitstream generation succeeds;
- the Basys 3 board physically displays the result with the correct `CPU_CLOCK_HZ`.

No Phase 22 frequency-extension board result is claimed.
