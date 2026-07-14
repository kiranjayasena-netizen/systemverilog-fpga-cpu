# Phase 15A Basys 3 Slow-Enable Bring-Up Wrapper

## Purpose

Phase 15A adds a separate Basys 3 bring-up wrapper for the Phase 14G six-stage CPU. The Phase 14G CPU runs too quickly for useful LED observation in normal full-speed mode, so this wrapper adds a switch-controlled slow-enable mode while keeping the CPU on the real 100 MHz board clock.

This phase is for hardware observability. It does not change the Phase 14G CPU core, instruction encodings or measured Phase 14G performance result.

## Current Performance Baseline

Phase 14G remains the current best measured implementation result:

| Metric | Phase 14G |
| --- | ---: |
| Verified period | 6.000 ns |
| Fmax | 166.667 MHz |
| CPI | 1.638 |
| Practical estimated throughput | ~101.8 MIPS |

The Phase 15A bring-up wrapper is built for the Basys 3 100 MHz board clock and is not a new performance claim.

## Files Added

- `rtl/fpga_top_pipeline6_bringup.sv`
- `scripts/run_vivado_impl_pipeline6_bringup.tcl`
- `reports/phase15a_basys3_bringup.md`

## Top Module

Top module:

- `fpga_top_pipeline6_bringup`

External ports:

```systemverilog
input  logic        clk;
input  logic        rst_btn;
input  logic [1:0]  sw;
output logic [15:0] led;
```

The wrapper instantiates `cpu_core_pipeline6` directly.

## Switch And Reset Mapping

| Board control | Top-level port | Function |
| --- | --- | --- |
| BTNC / U18 | `rst_btn` | Synchronized CPU reset |
| SW0 / V17 | `sw[0]` | Run enable |
| SW1 / V16 | `sw[1]` | Slow mode select |

Switch behavior:

| SW0 | SW1 | CPU enable behavior |
| ---: | ---: | --- |
| 0 | X | CPU held paused |
| 1 | 0 | Full-speed enable, one CPU cycle per 100 MHz board clock |
| 1 | 1 | Slow enable pulse from local divider |

The clock remains the real 100 MHz board clock in all modes. The wrapper only changes the CPU clock-enable input.

## Slow Enable

Default divider:

```systemverilog
SLOW_DIVIDE_CYCLES = 25_000_000
```

At 100 MHz this creates one CPU enable pulse every 25,000,000 board-clock cycles:

```text
25,000,000 / 100,000,000 Hz = 0.25 s
```

Expected visible rate:

- Approximately one CPU step every 0.25 seconds.
- Approximately four CPU enable pulses per second.

## Synchronization

The wrapper uses simple two-stage synchronizers for:

- `rst_btn`
- `sw[0]`
- `sw[1]`

This keeps button/switch inputs from directly driving CPU state.

## LED Mapping

| LED | Signal |
| --- | --- |
| `led[3:0]` | `fetch_pc[5:2]`, low fetch PC word index |
| `led[4]` | IF/ID valid |
| `led[5]` | ID/OP valid |
| `led[6]` | OP/EX valid |
| `led[7]` | EX/MEM valid |
| `led[8]` | MEM/WB valid |
| `led[9]` | stall or load-use stall |
| `led[10]` | redirect pulse |
| `led[11]` | retire pulse |
| `led[12]` | register-write pulse |
| `led[13]` | memory-write pulse |
| `led[14]` | slow mode active, synchronized SW1 |
| `led[15]` | run enable active, synchronized SW0 |

This mapping prioritizes visibility of fetch progress, pipeline occupancy and side-effect pulses.

## Vivado Implementation

Script:

- `scripts/run_vivado_impl_pipeline6_bringup.tcl`

Target:

- Board: Basys 3
- FPGA: `xc7a35tcpg236-1`
- Clock: 10.000 ns / 100 MHz
- Top: `fpga_top_pipeline6_bringup`

The script generates a bring-up XDC under:

- `reports/phase15a_bringup_impl/constraints/pipeline6_bringup_basys3.xdc`

Generated reports and bitstream are under:

- `reports/phase15a_bringup_impl/`

These generated artifacts should not be committed wholesale.

## Implementation Result

Vivado implementation and bitstream generation were run successfully.

| Metric | Result |
| --- | ---: |
| Target period | 10.000 ns |
| WNS | +2.444 ns |
| TNS | 0.000 ns |
| WHS | +0.062 ns |
| THS | 0.000 ns |
| LUTs | 1,321 |
| FFs | 1,633 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total on-chip power estimate | 0.084 W |
| Bitstream generation | Passed |

Bitstream path:

- `reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit`

Warnings reviewed:

- Vivado removed unused sequential debug elements after optimization.
- Low address bits on BRAM address ports are unconnected because the memories use word-aligned indexing.
- No warning requires a CPU behavior or instruction encoding change for Phase 15A.

## Hardware Test Procedure

1. Open Vivado Hardware Manager.
2. Program the Basys 3 with:
   - `reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit`
3. Confirm DONE/startup status is high.
4. Set `SW0 = 0` to hold the CPU paused.
5. Set `SW1 = 1` for slow mode.
6. Press and release BTNC reset.
7. Set `SW0 = 1` to allow slow stepping.
8. Observe LEDs:
   - `led[3:0]` should step as fetch PC changes.
   - `led[8:4]` should show pipeline valid movement.
   - `led[11]`, `led[12]` and `led[13]` may pulse during retire, register write and memory write events.
9. Set `SW0 = 0` again to freeze state.
10. Capture photo or video evidence showing:
    - programmed DONE state,
    - switch positions,
    - slow LED stepping,
    - paused LED state when `SW0 = 0`.

## Limitations

- This wrapper is for visibility and bring-up, not performance measurement.
- Slow mode does not prove 166.667 MHz physical operation.
- Full-speed mode uses the 100 MHz board clock unless a later clocking/MMCM design is added.
- No ILA core is included in Phase 15A.
- Board-level observation still depends on the loaded LED demo program and the user's physical hardware setup.

## Recommended Next Phase

Phase 15B should record physical board evidence: programmed bitstream, DONE status, reset behavior, slow-mode LED stepping, pause/freeze behavior and any observed LED sequence. If LED-only observation is insufficient, a later phase can add an ILA/debug-core wrapper without changing the CPU core.
