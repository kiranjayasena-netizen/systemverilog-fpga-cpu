# Phase 16A Hardware MIPS Counter With 7-Segment Display

## Purpose

Phase 16A adds a separate Basys 3 top-level wrapper that measures instruction throughput in real FPGA hardware and displays an integer MIPS value on the four-digit 7-segment display.

This phase is a hardware measurement and observability phase. It does not change `cpu_core_pipeline6.sv`, instruction encodings, the Phase 13E/13I RTL, or the Phase 14G timing/performance evidence.

## Current Performance Context

Phase 14G remains the current post-route performance result:

| Metric | Phase 14G |
| --- | ---: |
| Best verified period | 6.000 ns |
| Post-route Fmax | 166.667 MHz |
| Simulation CPI used | 1.638 |
| Practical estimated throughput | ~101.8 MIPS |

The Phase 16A wrapper runs from the normal Basys 3 100 MHz board clock. It is intended to measure hardware throughput at 100 MHz. It does not prove physical operation at 166.667 MHz.

## Files Added

- `rtl/fpga_top_pipeline6_perf7seg.sv`
- `scripts/run_vivado_impl_pipeline6_perf7seg.tcl`
- `reports/phase16a_hardware_mips_7seg.md`

## Top Module

Top module:

- `fpga_top_pipeline6_perf7seg`

External ports:

```systemverilog
input  logic        clk;
input  logic        rst_btn;
input  logic [1:0]  sw;
output logic [15:0] led;
output logic [6:0]  seg;
output logic [3:0]  an;
output logic        dp;
```

The wrapper instantiates `cpu_core_pipeline6` with:

```systemverilog
IMEM_INIT_FILE = "programs/fpga_led_demo.mem"
IMEM_DEPTH     = 256
```

## Switch And Reset Mapping

| Board control | Top-level port | Function |
| --- | --- | --- |
| BTNC / U18 | `rst_btn` | Synchronized reset |
| SW0 / V17 | `sw[0]` | Full-speed run enable |
| SW1 / V16 | `sw[1]` | Reserved for later display/debug selection |

When SW0 is low, the CPU enable is low and the measured MIPS value remains latched. When SW0 is high, the CPU runs at one enabled CPU cycle per 100 MHz board-clock cycle.

## Hardware MIPS Measurement

The wrapper uses `debug_retire_valid` from `cpu_core_pipeline6` as the retired-instruction event.

One measurement window is exactly 100,000,000 board-clock cycles:

```text
Measurement window = 100,000,000 cycles at 100 MHz = 1 second
```

At the end of each one-second window:

- the retired-instruction count is latched into `last_retired_count`;
- the displayed integer MIPS value is latched;
- the counters reset for the next one-second window.

Formula:

```text
MIPS = retired instructions in one second / 1,000,000
```

The implementation avoids a wide runtime divider by accumulating one MIPS count for each million retired instructions during the active measurement window.

Using the Phase 14F simulation CPI as a rough expectation:

```text
100 MHz / 1.638 CPI = 61.05 MIPS
```

Therefore the display is expected to show approximately:

```text
0061
```

The exact hardware value depends on the loaded program in instruction memory. Phase 16A currently uses `programs/fpga_led_demo.mem`, so it is a board-clock hardware measurement of that loaded program, not a direct re-run of the Phase 14F benchmark program.

## Physical Board Measurement

The Phase 16A bitstream was programmed on the Basys 3 and the four-digit display showed:

```text
0063
```

This is a direct 100 MHz board-clock measurement:

```text
Hardware MIPS = 63
CPI = 100 / 63 = approximately 1.59
```

This measured CPI is close to the Phase 14F/14G simulation CPI estimate of approximately 1.638. The board result should not be confused with the Phase 14G post-route timing estimate of approximately 101.8 MIPS, which assumes the design is clocked at the timing-clean 166.667 MHz point rather than the fixed 100 MHz Basys 3 board clock.

## 7-Segment Display

The Basys 3 display outputs are active low:

- `seg[6:0]`
- `an[3:0]`
- `dp`

The wrapper displays the integer MIPS value as four decimal digits:

| Example | Meaning |
| --- | --- |
| `0000` | reset or no completed one-second window |
| `0061` | about 61 MIPS at the 100 MHz board clock |
| `0102` | about 102 MIPS if a later higher-clock hardware test supports it |

The decimal point is held off:

```systemverilog
dp = 1'b1;
```

The display uses a refresh counter driven by the 100 MHz board clock. No fabric-derived clock is created.

## LED Mapping

| LED | Signal |
| --- | --- |
| `led[3:0]` | `fetch_pc[5:2]`, low fetch PC word index |
| `led[4]` | IF/ID valid |
| `led[5]` | ID/OP valid |
| `led[6]` | OP/EX valid |
| `led[7]` | EX/MEM valid |
| `led[8]` | MEM/WB valid |
| `led[9]` | sticky one-second measurement window completed |
| `led[10]` | sticky redirect observed |
| `led[11]` | sticky retire observed |
| `led[12]` | sticky register-write observed |
| `led[13]` | sticky memory-write observed |
| `led[14]` | measurement active |
| `led[15]` | run enable |

Sticky LEDs are cleared by BTNC reset. Pausing with SW0 low does not clear the sticky event flags.

## Vivado Implementation

Script:

- `scripts/run_vivado_impl_pipeline6_perf7seg.tcl`

Target:

- Board: Basys 3
- FPGA: `xc7a35tcpg236-1`
- Clock: 10.000 ns / 100 MHz
- Top: `fpga_top_pipeline6_perf7seg`

The script writes generated implementation artifacts under:

- `reports/phase16a_perf7seg_impl/`

These generated reports, checkpoints and bitstreams should not be committed wholesale.

## Implementation Result

Vivado implementation and bitstream generation were run successfully.

| Metric | Result |
| --- | ---: |
| Target period | 10.000 ns |
| WNS | +2.336 ns |
| TNS | 0.000 ns |
| WHS | +0.038 ns |
| THS | 0.000 ns |
| LUTs | 1,388 |
| FFs | 1,719 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total on-chip power estimate | 0.099 W |
| Bitstream generation | Passed |

Route status:

- All routable nets fully routed.
- No route errors reported.

Bitstream path:

- `reports/phase16a_perf7seg_impl/bitstreams/fpga_top_pipeline6_perf7seg.bit`

## Hardware Test Procedure

1. Program the Basys 3 with:
   - `reports/phase16a_perf7seg_impl/bitstreams/fpga_top_pipeline6_perf7seg.bit`
2. Confirm DONE/startup status is high.
3. Set `SW0 = 0`.
4. Press and release BTNC reset.
5. Confirm the 7-segment display shows `0000` or the reset value.
6. Set `SW0 = 1`.
7. Wait at least two seconds so at least one full measurement window completes.
8. Observe the 7-segment MIPS value.
9. Check whether the value is close to the expected 100 MHz result, likely around `0061`, depending on program behavior.
10. Set `SW0 = 0`.
11. Confirm the displayed value remains latched.
12. Press BTNC reset and confirm the display clears.

## Limitations

- Phase 16A measures the CPU at the Basys 3 100 MHz board clock.
- It does not prove physical operation at the Phase 14G 166.667 MHz timing point.
- The measured MIPS depends on the instruction program loaded into the CPU.
- `programs/fpga_led_demo.mem` may not produce the same CPI as the Phase 14F full-program benchmark.
- The display reports integer MIPS only, so fractional precision is lost.
- SW1 is reserved for a future display/debug mode in this first version.

## Recommended Next Phases

- Phase 16B: add a hardware benchmark program that better matches the Phase 14F full-program workload.
- Phase 16C: optional MMCM or Clocking Wizard experiment for higher-frequency hardware measurement.
- Phase 16D: add UART output or ILA counters for more detailed hardware performance evidence.
