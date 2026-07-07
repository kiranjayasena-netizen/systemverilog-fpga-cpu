# Phase 3D Hardware Bring-Up Template

Use this template when the physical Basys 3 board is available. Do not fill in hardware results until the board has actually been programmed and observed.

## Session Details

- Date/time:
- Git commit hash:
- Vivado version:
- Board model:
- FPGA part:
- Bitstream path:

## Programming Result

- Vivado Hardware Manager detected board: TODO
- Device identified correctly: TODO
- Bitstream programmed successfully: TODO
- Programming warnings or errors: TODO

## Reset Behaviour

- Reset button used:
- Behaviour while reset is pressed:
- Behaviour after reset is released:
- Does the visible state return to the expected start of the demo program: TODO
- Notes:

## Enable Switch Behaviour

- Enable switch used:
- Behaviour when switch is low:
- Behaviour when switch is high:
- Does the CPU appear to advance only when enabled: TODO
- Notes:

## Observed LED PC Sequence

Expected reference: `docs/fpga_led_expected_sequence.md`

```text
Observed led[3:0] sequence:
TODO
```

## Observed LED Opcode Sequence

Expected reference: `docs/fpga_led_expected_sequence.md`

```text
Observed led[7:4] sequence:
TODO
```

## Comparison With Expected LED Sequence

- PC sequence matches expected: TODO
- Opcode sequence matches expected: TODO
- Key control LEDs match expected: TODO
- Any repeated or unexpected NOP state: TODO
- Notes:

## Evidence Captured

- Photos captured:
- Short video captured:
- Screenshot of Vivado programming result:
- Notes file or lab notebook entry:

## Issues Found

- Issue 1:
- Issue 2:
- Issue 3:

## Conclusion

TODO: State whether Phase 3D hardware bring-up passed, partially passed or failed based on observed board evidence.

## Next Action

TODO: State the next practical step, such as repeat test, investigate mismatch, document successful bring-up, or start timing-improvement work.

