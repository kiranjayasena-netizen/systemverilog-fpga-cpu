# Phase 17A Forward-Timing Hardware Profiler

## Purpose

Phase 17A adds a hardware profiling wrapper around the Phase 13 forward-timing five-stage pipeline. Phase 13 is currently the best fixed-100 MHz board-measured CPU path, at approximately 87 MIPS on the Basys 3.

This phase does not modify CPU logic. It adds a board-facing wrapper that measures throughput and exposes profiling evidence so later Phase 17 work can optimise the measured bottleneck rather than guessing.

## Top Module

- `fpga_top_pipeline_forwardtiming_profile`

The wrapper instantiates:

- `cpu_core_pipeline_forwardtiming`

Source files:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming_profile.sv`

## Files Created

- `rtl/fpga_top_pipeline_forwardtiming_profile.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl`
- `reports/phase17a_forwardtiming_profile.md`

## Switch Mapping

| Board control | Function |
| --- | --- |
| BTNC | Synchronized reset |
| SW0 | Full-speed run enable |
| SW1 | Reserved; display remains MIPS |

Display modes:

| SW1 | 7-segment display |
| ---: | --- |
| 0 | Integer MIPS, for example `0087` |
| 1 | Integer MIPS, same as SW1 = 0 |

## LED Mapping

| LED | Signal |
| --- | --- |
| `led[3:0]` | Fetch PC word index, `fetch_pc[5:2]` |
| `led[7:4]` | Decoded opcode |
| `led[8]` | IF/ID valid |
| `led[9]` | Sticky retire observed |
| `led[10]` | Sticky register write observed |
| `led[11]` | Sticky memory write observed |
| `led[12]` | Sticky redirect observed |
| `led[15:13]` | `{ID/EX valid, EX/MEM valid, MEM/WB valid}` |

Sticky LEDs are cleared by BTNC reset. Pausing with SW0 does not clear them.

## Measurement Method

The wrapper uses the existing Phase 13 performance/debug outputs where possible:

- `retire_valid`
- `total_cycles`
- `retired_instructions`
- `data_hazard_stall_cycles`
- `load_use_stall_cycles`
- `control_hazard_flush_cycles`
- `instruction_fetch_wait_cycles`
- `memory_wait_cycles`
- `taken_branches`
- `not_taken_branches`
- `jumps`
- `wrong_path_instructions_flushed`

The wrapper counts a one-second measurement window using the 100 MHz board clock:

```text
MIPS = retired instructions in one second / 1,000,000
CPI  = total cycles / retired instructions
```

The first implementation attempted an optional CPI x100 display, but that created a variable-divider timing path and failed 100 MHz timing. The final bitstream keeps the display timing-safe by showing integer MIPS only. CPI is calculated manually from the displayed value:

```text
CPI ~= 100 / displayed MIPS
```

## Expected Result

The current Phase 13 board measurement is approximately:

| Metric | Expected |
| --- | ---: |
| Hardware MIPS at 100 MHz | ~87 |
| Implied CPI | ~1.15 |
| Display, SW1 = 0 | `0087` |
| Display, SW1 = 1 | `0087` |

## Vivado Script

Script:

```powershell
vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl
```

Generated output root:

- `reports/phase17a_forwardtiming_profile_impl/`

Expected bitstream path:

- `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`

The generated implementation folder should remain local and should not be committed wholesale.

## Vivado Result

Vivado implementation and bitstream generation passed after removing the optional CPI divider from the display path.

Front-end compile/elaboration check:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_pipeline_forwardtiming.sv rtl\fpga_top_pipeline_forwardtiming_profile.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat fpga_top_pipeline_forwardtiming_profile -s fpga_top_pipeline_forwardtiming_profile_elab2
```

Result: passed. The first sandboxed `xelab` invocation built the snapshot but hit the known XSim object-directory cleanup access warning. The rerun with normal filesystem access completed successfully.

| Metric | Value |
| --- | ---: |
| Target period | 10.000 ns |
| WNS | +0.391 ns |
| TNS | 0.000 ns |
| WHS | +0.089 ns |
| THS | 0.000 ns |
| LUTs | 1,489 |
| FFs | 1,614 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total on-chip power estimate | 0.104 W |
| Bitstream generation | Passed |

Bitstream path:

- `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`

## Hardware Test Procedure

1. Run `scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl`.
2. Program `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`.
3. Press and release BTNC reset.
4. Set SW0 on.
5. Wait at least two one-second measurement windows.
6. Read the displayed MIPS value.
7. Calculate CPI as `100 / displayed MIPS`.
8. Record photo/video evidence for the display and sticky LEDs.

## Limitations

- The on-board display gives coarse integer MIPS only.
- CPI must be calculated manually from the displayed MIPS value.
- Detailed per-window bottleneck counters are latched internally for future ILA/UART exposure but are not all visible on the first 7-segment wrapper.
- The measurement is at the fixed 100 MHz board clock.
- The result depends on the instruction program loaded into instruction memory.

## Recommended Next Step

Run the Phase 17A bitstream on the board and fill in the Phase 17B bottleneck table. Do not start Phase 17C RTL optimisation until the dominant lost-cycle source is known.
