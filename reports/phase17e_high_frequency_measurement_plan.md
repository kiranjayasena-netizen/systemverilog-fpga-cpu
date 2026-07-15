# Phase 17E High-Frequency Hardware Measurement Plan

## Purpose

Phase 17E is a planning step for measuring Phase 13 hardware MIPS above the fixed 100 MHz Basys 3 board clock.

No MMCM, Clocking Wizard, generated clock or new high-frequency bitstream is implemented in this phase.

## Motivation

The Phase 13 forward-timing CPU is currently the best measured design at the fixed 100 MHz board clock:

- Hardware-measured MIPS: approximately 87.
- Implied CPI: approximately 1.15.

If Phase 13 can run physically above 115 MHz while preserving that CPI, it could reach approximately 100 MIPS on the board:

```text
115 MHz / 1.15 CPI = 100 MIPS
```

To beat the Phase 14G post-route estimated peak of approximately 101.8 MIPS, Phase 13 would need roughly:

```text
101.8 MIPS * 1.15 CPI = 117.1 MHz
```

## Future Hardware Experiment

A future phase could add:

- MMCM or Clocking Wizard clock generation;
- generated-clock constraints;
- a selectable 100 MHz / high-frequency measurement mode;
- the Phase 17A MIPS/CPI counter wrapper;
- careful timing reports for the generated CPU clock;
- board validation at each selected frequency.

## Required Care

This is not just a display change. A real high-frequency measurement requires:

- correct generated-clock constraints;
- no fabric-derived clock;
- timing closure on the actual generated CPU clock;
- reset synchronization across any clocking boundary;
- proof that the MIPS counter uses the correct measurement-window frequency;
- board testing at each claimed frequency.

## Recommendation

Do not start Phase 17E implementation until:

1. Phase 17A has captured hardware profiling data.
2. Phase 17D has identified a timing-clean target frequency worth testing.
3. The desired generated clock frequency is chosen based on the timing sweep.
