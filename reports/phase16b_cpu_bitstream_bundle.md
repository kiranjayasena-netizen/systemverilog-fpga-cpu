# Phase 16B CPU Bitstream Comparison Bundle

## Purpose

This bundle collects the generated Basys 3 bitstreams for the major CPU implementation paths created during the project. It is intended to make board programming and side-by-side comparison easier.

The bundle does not create a new CPU architecture and does not change any CPU RTL. It copies existing generated `.bit` files into one folder with descriptive filenames.

## Output Folder

Generated bundle:

- `reports/phase16b_cpu_bitstream_bundle/`

Manifest:

- `reports/phase16b_cpu_bitstream_bundle/manifest.csv`

Bitstreams:

- `reports/phase16b_cpu_bitstream_bundle/bitstreams/`

Generated bundle outputs are local artifacts and should not be committed wholesale.

## Collection Script

Script:

- `scripts/collect_cpu_comparison_bitstreams.ps1`

Command used:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\collect_cpu_comparison_bitstreams.ps1
```

Result:

- 16 bitstreams were found and copied.
- No selected bitstreams were missing.

## Bundle Contents

| Phase | Bundle filename | Architecture | Notes |
| --- | --- | --- | --- |
| Phase 7 | `phase07_single_cycle_style_fpga_top.bit` | Original single-cycle-style CPU | LED/debug wrapper only |
| Phase 8G | `phase08_multicycle.bit` | Separate multi-cycle CPU | LED/debug wrapper, slow-enable top |
| Phase 10H | `phase10_bram_multicycle.bit` | BRAM-aware multi-cycle CPU | LED/debug wrapper, BRAM inferred |
| Phase 11C | `phase11_bram_prefetch.bit` | BRAM-aware prefetch multi-cycle CPU | LED/debug wrapper |
| Phase 11E | `phase11_ctrlopt_prefetch.bit` | Control-flow optimised BRAM prefetch multi-cycle CPU | LED/debug wrapper, best Phase 11 path |
| Phase 12 | `phase12_pipeline.bit` | Five-stage pipeline | LED/debug wrapper |
| Phase 13A | `phase13a_jumpfast_pipeline.bit` | Pipeline with fast JUMP target request | LED/debug wrapper |
| Phase 13B | `phase13b_beq_prefetch_pipeline.bit` | BEQ target-prefetch pipeline experiment | LED/debug wrapper, not preferred |
| Phase 13C | `phase13c_timingopt_pipeline.bit` | Timing-optimised pipeline | LED/debug wrapper |
| Phase 13D | `phase13d_loadtiming_pipeline.bit` | Load-forwarding timing experiment | LED/debug wrapper, not preferred |
| Phase 13E/13I | `phase13e_13i_forwardtiming_pipeline.bit` | Preferred Phase 13 forwarding-timing pipeline | LED/debug wrapper, best Phase 13 implementation strategy result |
| Phase 13F | `phase13f_targetbuf_pipeline_experimental.bit` | Target-buffer pipeline experiment | Experimental; timing failed at the recorded 8.900 ns constraint |
| Phase 13G | `phase13g_registered_targetbuf_pipeline.bit` | Registered target-buffer pipeline experiment | Timing-clean but not better than Phase 13E |
| Phase 14G | `phase14g_pipeline6.bit` | Six-stage pipeline | Current best timing/performance evidence |
| Phase 15B | `phase15b_pipeline6_bringup_sticky_leds.bit` | Six-stage pipeline bring-up wrapper | Slow-enable and sticky event LEDs |
| Phase 16A | `phase16a_pipeline6_perf7seg.bit` | Six-stage pipeline hardware MIPS counter | 7-seg MIPS counter; board measured about 63 MIPS |

## Important Measurement Note

Only this bitstream has the Phase 16A on-board 7-segment MIPS counter:

- `phase16a_pipeline6_perf7seg.bit`

The older CPU bitstreams are useful for programming the board and observing their LED/debug behavior, but they do not all include a hardware MIPS display. Their performance comparisons should still use the documented simulation CPI and Vivado timing reports unless a matching MIPS-counter wrapper is added for each architecture.

## Recommended Board Comparison Flow

1. Program one bitstream from `reports/phase16b_cpu_bitstream_bundle/bitstreams/`.
2. Record which filename was programmed.
3. For LED/debug wrappers, observe reset, enable and LED behavior.
4. For `phase16a_pipeline6_perf7seg.bit`, read the 7-segment MIPS display after at least one full one-second measurement window.
5. Keep screenshots or photos labelled with the bitstream filename.

## Current Hardware MIPS Reading

The Phase 16A 7-segment bitstream produced a board reading of about:

```text
63 MIPS
```

This is close to the expected 100 MHz estimate:

```text
100 MHz / 1.638 CPI = 61.05 MIPS
```

The difference is reasonable because the board bitstream currently uses `programs/fpga_led_demo.mem`, while the CPI estimate comes from the Phase 14F full-program simulation benchmark.

## Recommended Next Phase

Phase 16C should add comparable 7-segment MIPS-counter wrappers for selected earlier architectures if direct board-measured MIPS is required for each CPU. The most useful set would be:

- Phase 11E control-flow optimised BRAM prefetch CPU
- Phase 13E/13I forwarding-timing pipeline
- Phase 14G six-stage pipeline

Adding MIPS counters to every experimental CPU is possible but would create many wrappers; the better approach is to pick the representative winners from each architecture family.
