# Phase 7E Basys 3 Bring-Up Report

## Purpose

Phase 7E is the planned first physical-board bring-up stage for the Basys 3 target. The goal is to program the generated `fpga_top` bitstream, check reset and enable controls, observe the LED debug sequence, and record evidence.

This report is currently a planning and evidence-capture template. It must not be treated as proof of hardware validation until the Basys 3 has actually been programmed and observed.

## Session Details

- Target board: Digilent Basys 3
- FPGA part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Bitstream path: `reports/bitstreams/fpga_top.bit`
- Vivado version: Vivado 2026.1
- Git commit hash: TODO
- Date/time: TODO
- Tester: TODO
- Location: TODO

## Setup Checklist

- [ ] Confirm the physical board is a Digilent Basys 3.
- [ ] Confirm the repository checkout is on the intended commit.
- [ ] Confirm no unexpected RTL or constraint changes are present.
- [ ] Confirm `reports/bitstreams/fpga_top.bit` exists locally.
- [ ] Confirm `constraints/basys3.xdc` is the constraints file used for the bitstream.
- [ ] Confirm the board is connected using a USB data cable.
- [ ] Confirm the board is powered and visible to the operating system.
- [ ] Open Vivado 2026.1.
- [ ] Open Hardware Manager.
- [ ] Auto-connect to the Basys 3 target.

## Programming Checklist

- [ ] Select the detected Artix-7 device in Vivado Hardware Manager.
- [ ] Select `reports/bitstreams/fpga_top.bit`.
- [ ] Program the device.
- [ ] Record whether programming completed successfully.
- [ ] Record any Vivado warnings or errors.

Successful programming alone is not enough to claim CPU hardware validation. Reset, enable and LED behaviour must also be checked.

## Reset Test Checklist

- [ ] Press the mapped reset button.
- [ ] Release the reset button.
- [ ] Confirm the visible LED state returns to the expected start of the demo program.
- [ ] Record whether reset behaviour is repeatable.
- [ ] Record any unexpected LED states while reset is pressed or released.

## Enable Switch Test Checklist

- [ ] Set SW0 low.
- [ ] Confirm the visible CPU state does not advance while disabled.
- [ ] Set SW0 high.
- [ ] Confirm the visible CPU state advances slowly.
- [ ] Set SW0 low again.
- [ ] Confirm the visible CPU state holds again.
- [ ] Record whether the enable behaviour is repeatable.

The CPU still uses the real 100 MHz Basys 3 clock. SW0 and the slow tick control the CPU enable path; they do not create a divided clock.

## LED Observation Checklist

Expected LED reference: `docs/fpga_led_expected_sequence.md`

Primary observations:

- [ ] Observe `led[3:0]` for PC word index.
- [ ] Observe `led[7:4]` for opcode.
- [ ] Observe `led[8]` for `valid_instr`.
- [ ] Observe `led[9]` for `reg_write`.
- [ ] Observe `led[10]` for `use_imm`.
- [ ] Observe `led[13:11]` for `alu_op`.
- [ ] Treat `led[15:14]` as secondary ALU-result evidence.

Expected PC word-index loop:

```text
0, 1, 2, 3, 4, 5, 6, 0, ...
```

Expected opcode loop:

```text
6, 6, 1, 5, 9, 6, A, 6, ...
```

## Photo And Video Evidence

- Photo of board connected: TODO
- Vivado Hardware Manager screenshot: TODO
- Programming success screenshot: TODO
- Short video of LED stepping: TODO
- Notes comparing observed LEDs with expected sequence: TODO
- Any issue photos/videos: TODO

Evidence should include enough context to identify the board, bitstream, date/time and commit used for testing.

## Result Table

| Check | Status | Evidence/notes |
| --- | --- | --- |
| Vivado detects Basys 3 | NOT TESTED | TODO |
| FPGA part identified correctly | NOT TESTED | TODO |
| Bitstream programs successfully | NOT TESTED | TODO |
| Reset button returns visible state to start | NOT TESTED | TODO |
| SW0 low holds visible state | NOT TESTED | TODO |
| SW0 high advances visible state | NOT TESTED | TODO |
| LED PC sequence matches expected | NOT TESTED | TODO |
| LED opcode sequence matches expected | NOT TESTED | TODO |
| Key control LEDs match expected | NOT TESTED | TODO |
| Photos captured | NOT TESTED | TODO |
| Video captured | NOT TESTED | TODO |
| Issues recorded | NOT TESTED | TODO |

Use `PASS`, `FAIL` or `NOT TESTED` in the status column after the board session.

## Known Timing Limitation

Phase 7D documented that the design fits in the Basys 3 and that bitstream generation passed, but post-route setup timing does not meet the 100 MHz target:

- WNS: -1.551 ns
- TNS: -5707.315 ns
- Hold timing: met
- Worst path: single-cycle-style PC/fetch/decode/execute/writeback path
- Estimated maximum frequency from worst slack: approximately 86.6 MHz

Phase 7E must not claim 100 MHz timing closure. Any successful board observation should be described as functional bring-up evidence under the known timing limitation.

## Conclusion

Hardware bring-up result: NOT TESTED

TODO: After the Basys 3 session, state whether board programming, reset behaviour, enable switch behaviour and LED sequence observation passed, partially passed or failed.

## Next Action

Before hardware testing:

- Confirm the intended commit and bitstream.
- Program the Basys 3.
- Record evidence using this report.

After hardware testing:

- Update the result table.
- Add photo/video references.
- Document any mismatch.
- Decide whether to proceed with timing-closure redesign, such as a multi-cycle CPU implementation.
