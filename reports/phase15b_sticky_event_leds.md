# Phase 15B Sticky Event LEDs

## Purpose

Phase 15B improves the Basys 3 Phase 15A bring-up wrapper by making event LEDs visible to a human observer.

In Phase 15A, LEDs 9 through 13 were mapped directly to short event pulses:

- stall/load-use stall
- redirect
- retire
- register write
- memory write

In slow mode, the CPU advances with a one-clock-cycle enable pulse. These event signals can therefore be high for only one 100 MHz clock cycle, or about 10 ns. That is too short to see on physical LEDs.

## Change

The top module remains:

- `fpga_top_pipeline6_bringup`

The wrapper now captures event pulses into sticky registers:

- `stall_seen`
- `redirect_seen`
- `retire_seen`
- `reg_write_seen`
- `mem_write_seen`

These sticky flags are cleared only by synchronized BTNC reset. They are not cleared by pausing the CPU with SW0 and are not cleared by disabling slow mode.

No CPU core RTL was modified.

## Updated LED Map

| LED | Phase 15B signal |
| --- | --- |
| `led[3:0]` | fetch PC word index, `fetch_pc[5:2]` |
| `led[4]` | IF/ID valid |
| `led[5]` | ID/OP valid |
| `led[6]` | OP/EX valid |
| `led[7]` | EX/MEM valid |
| `led[8]` | MEM/WB valid |
| `led[9]` | sticky `stall_seen` |
| `led[10]` | sticky `redirect_seen` |
| `led[11]` | sticky `retire_seen` |
| `led[12]` | sticky `reg_write_seen` |
| `led[13]` | sticky `mem_write_seen` |
| `led[14]` | slow mode active, synchronized SW1 |
| `led[15]` | run enable active, synchronized SW0 |

## Reset And Pause Behavior

| Condition | Sticky LED behavior |
| --- | --- |
| BTNC reset asserted | Clears LEDs 9-13 |
| SW0 set low | CPU pauses; sticky LEDs remain unchanged |
| SW0 set high | CPU resumes; new events can set sticky LEDs |
| SW1 changed | Slow/full-speed mode changes; sticky LEDs remain unchanged |

## Vivado Implementation

The existing Phase 15A bring-up implementation script was reused:

- `scripts/run_vivado_impl_pipeline6_bringup.tcl`

The script generated a new bitstream from the updated wrapper.

Bitstream path:

- `reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit`

Implementation result:

| Metric | Result |
| --- | ---: |
| Target period | 10.000 ns |
| WNS | +1.472 ns |
| TNS | 0.000 ns |
| WHS | +0.039 ns |
| THS | 0.000 ns |
| LUTs | 1,323 |
| FFs | 1,638 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total on-chip power estimate | 0.083 W |
| Bitstream generation | Passed |

## Hardware Test Procedure

1. Program the Basys 3 with:
   - `reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit`
2. Set `SW0 = 0`.
3. Set `SW1 = 1` for slow mode.
4. Press and release BTNC reset.
5. Confirm LEDs 9-13 are initially off.
6. Set `SW0 = 1`.
7. Watch `led[3:0]` and `led[8:4]` step through the sequence.
8. Confirm `led[11]` turns on after at least one instruction retires.
9. Confirm `led[12]` turns on after at least one register write occurs, if the loaded program writes a register.
10. Confirm `led[13]` turns on after a store occurs, if the loaded program contains a store.
11. Confirm `led[10]` turns on after a branch or jump redirect occurs, if the loaded program contains one.
12. Turn `SW0` off and confirm the CPU freezes while sticky event LEDs remain on.
13. Press BTNC reset and confirm sticky event LEDs clear.

## Limitations

- Phase 15B is a hardware observability improvement, not a performance measurement.
- Sticky LEDs show that an event occurred at least once since reset; they do not show how often it occurred.
- This does not prove physical operation at the Phase 14G 166.667 MHz timing point.
- No ILA or UART trace is included.

## Recommended Next Step

Phase 15C should capture physical evidence from the Basys 3: DONE status, reset clearing LEDs 9-13, slow stepping, sticky event LEDs turning on, SW0 pause/freeze and reset clearing the sticky flags.
