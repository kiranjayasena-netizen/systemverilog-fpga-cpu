# Basys 3 Bring-Up Checklist

## Purpose

This checklist is for the first physical Basys 3 board test of the `fpga_top` design. It assumes the design has already passed simulation and Vivado implementation, but has not yet been validated on real hardware.

Do not treat this checklist as proof of hardware validation until the board has actually been programmed and observed.

## Required Equipment

- Digilent Basys 3 board.
- Micro-USB cable suitable for data, not charge-only.
- Computer with Vivado 2026.1 installed.
- Local repository checkout with the generated bitstream.
- Access to the expected LED sequence document: [FPGA LED expected sequence](fpga_led_expected_sequence.md).
- Phone or camera for photos and a short video.
- Notebook or text file for bring-up notes.

## Pre-Checks Before Programming

- [ ] Confirm the repository is on the expected branch and commit.
- [ ] Confirm no unexpected local RTL or constraint changes are present.
- [ ] Confirm the target board is Digilent Basys 3.
- [ ] Confirm the target FPGA part is `xc7a35tcpg236-1`.
- [ ] Confirm the top module is `fpga_top`.
- [ ] Confirm the design has not already been claimed as hardware-tested.

Useful commands:

```powershell
git status
git log --oneline --decorate -5
```

## Confirm Vivado Version

- [ ] Open a Vivado-enabled terminal or Vivado GUI.
- [ ] Confirm Vivado is version 2026.1.

Command-line check:

```powershell
vivado -version
```

## Confirm Target Bitstream Path

The expected local bitstream path is:

```text
reports/bitstreams/fpga_top.bit
```

- [ ] Confirm `fpga_top.bit` exists.
- [ ] Confirm this bitstream was generated from the current `fpga_top` implementation flow.
- [ ] Do not add or commit the `.bit` file to Git.

Command-line check:

```powershell
dir reports\bitstreams
```

## Confirm Constraints File

The expected constraints file is:

```text
constraints/basys3.xdc
```

- [ ] Confirm the XDC maps `clk` to the Basys 3 100 MHz clock.
- [ ] Confirm `rst_btn` maps to the chosen reset pushbutton.
- [ ] Confirm `enable_sw` maps to SW0.
- [ ] Confirm `led[15:0]` maps to LD0 through LD15.
- [ ] Confirm no unused board pins have been added accidentally.

## Connect The Board

- [ ] Connect the Basys 3 to the computer using the micro-USB cable.
- [ ] Set the board power jumper/switch correctly for USB power, if applicable.
- [ ] Turn the board on.
- [ ] Check that the board power LED is on.
- [ ] Wait for Windows/Vivado to recognise the USB/JTAG connection.

## Open Vivado Hardware Manager

1. Open Vivado.
2. Open **Hardware Manager**.
3. Select **Open Target**.
4. Select **Auto Connect**.
5. Confirm Vivado detects the Artix-7 FPGA on the Basys 3.

If Vivado does not detect the board, see the troubleshooting section.

## Program The Device

1. In Hardware Manager, select the detected FPGA device.
2. Choose **Program Device**.
3. Select:

```text
reports/bitstreams/fpga_top.bit
```

4. Program the FPGA.
5. Confirm Vivado reports programming success.

Do not claim hardware validation from successful programming alone. The LED behaviour must still be checked.

## Reset And Enable Test

- [ ] Press the mapped reset button.
- [ ] Release reset.
- [ ] Set SW0 low and confirm the visible CPU state holds.
- [ ] Toggle SW0 high to enable slow CPU stepping.
- [ ] Observe whether the LEDs begin changing slowly.
- [ ] Toggle SW0 low again and confirm the visible state stops advancing.

The CPU should use the real 100 MHz clock internally. SW0 and the slow tick only control the CPU enable path.

## Observe LEDs

Use the LED mapping below:

| LED bits | Expected signal |
| --- | --- |
| `led[3:0]` | `pc[5:2]` |
| `led[7:4]` | `opcode` |
| `led[8]` | `valid_instr` |
| `led[9]` | `reg_write` |
| `led[10]` | `use_imm` |
| `led[13:11]` | `alu_op` |
| `led[15:14]` | `alu_result[1:0]` |

- [ ] Compare the observed PC and opcode pattern with [FPGA LED expected sequence](fpga_led_expected_sequence.md).
- [ ] Confirm the expected loop is visible.
- [ ] Confirm the spare NOP word is not repeatedly reached during normal looping.
- [ ] Treat `led[15:14]` as secondary evidence because these bits depend on ALU result state.

Expected PC word-index loop:

```text
0, 1, 2, 3, 4, 5, 6, 0, ...
```

Expected opcode loop:

```text
6, 6, 1, 5, 9, 6, A, 6, ...
```

## Record Evidence

Record enough evidence that the test can be reviewed later:

- [ ] Date and time of test.
- [ ] Git commit hash used for the bitstream.
- [ ] Vivado version.
- [ ] Board name and FPGA part.
- [ ] Photo of the connected board.
- [ ] Photo or screenshot showing successful programming in Vivado.
- [ ] Short video of the LEDs stepping.
- [ ] Notes describing reset button behaviour.
- [ ] Notes describing SW0 enable switch behaviour.
- [ ] Notes comparing observed LED sequence to the expected sequence.
- [ ] Any unexpected behaviour or warnings.

Suggested evidence note format:

```text
Date/time:
Git commit:
Vivado version:
Bitstream path:
Programming result:
Reset behaviour:
Enable switch behaviour:
LED sequence observed:
Matches expected sequence:
Issues:
Next action:
```

## What Counts As Successful Phase 3 Hardware Validation

Phase 3 hardware validation can be counted as successful when:

- The Basys 3 is detected by Vivado Hardware Manager.
- `reports/bitstreams/fpga_top.bit` programs successfully.
- Pressing reset returns the visible CPU state to the expected start state.
- SW0 low holds the visible CPU state.
- SW0 high allows the visible CPU state to advance slowly.
- The PC and opcode LEDs follow the expected demo-program loop.
- Evidence is recorded with photos, short video, notes, date/time and commit hash.

Successful Phase 3 hardware validation does not mean 100 MHz timing closure has been achieved. The Phase 3C routed report currently records a 100 MHz setup timing miss.

## Troubleshooting

### Vivado Cannot Detect Board

- Check that the USB cable supports data.
- Check the board power switch.
- Check the board power jumper setting.
- Try a different USB port.
- Reopen Hardware Manager and run Auto Connect again.
- Check Windows Device Manager for the Digilent USB/JTAG device.
- Reinstall or repair Digilent cable drivers if needed.

### No LEDs Turn On Or Change

- Confirm the bitstream was programmed successfully.
- Confirm the correct bitstream file was selected.
- Press and release reset.
- Toggle SW0 high.
- Check the Basys 3 power LED.
- Confirm `constraints/basys3.xdc` maps `led[15:0]` to the Basys 3 LEDs.

### Reset Button Does Nothing

- Confirm the reset button used on the board matches `rst_btn` in `constraints/basys3.xdc`.
- Hold reset briefly, then release it.
- Check whether the LEDs return to the expected start pattern.
- If reset still has no visible effect, review the reset polarity and XDC pin mapping.

### Enable Switch Does Nothing

- Confirm SW0 is mapped to `enable_sw` in `constraints/basys3.xdc`.
- Confirm the switch is fully toggled high.
- Wait long enough for the slow tick to advance the CPU.
- If LEDs never advance, check `slow_tick_generator` synthesis and the `fpga_top` enable path.

### LED Pattern Does Not Match Expected

- Compare the observed sequence against [FPGA LED expected sequence](fpga_led_expected_sequence.md).
- Focus first on `led[3:0]` for PC word index and `led[7:4]` for opcode.
- Check whether reset was applied before observation.
- Check whether SW0 was high long enough for several slow ticks.
- Confirm `programs/fpga_led_demo.mem` was used when generating the bitstream.
- Record the mismatch before changing anything.

### Programming Succeeds But Behaviour Is Unstable

- Recheck the Phase 3C timing report.
- Remember that the current routed design does not meet 100 MHz setup timing.
- Record the behaviour honestly.
- Consider a future timing-improvement phase before claiming robust hardware operation.
