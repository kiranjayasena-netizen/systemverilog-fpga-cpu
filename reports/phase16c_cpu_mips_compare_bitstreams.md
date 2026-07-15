# Phase 16C Full-Speed MIPS-Counter Comparison Bitstreams

## Purpose

Phase 16C adds a shared full-speed Basys 3 MIPS-counter wrapper for representative CPU families so their board throughput can be read on the four-digit 7-segment display.

The old comparison bitstreams remain available, but most of them are LED/debug wrappers. These Phase 16C bitstreams are the ones to use when you want to see a MIPS value on the board.

## What Changed

New top:

- `rtl/fpga_top_cpu_mips_compare.sv`

New scripts:

- `scripts/run_vivado_impl_cpu_mips_compare.tcl`
- `scripts/build_cpu_mips_compare_bitstreams.ps1`

The CPU cores were not modified. The wrapper selects a CPU implementation at synthesis time with `CPU_SELECT`.

## Display And Switches

| Control | Function |
| --- | --- |
| BTNC | reset |
| SW0 | run enable |
| SW1 = 0 | display integer MIPS |
| SW1 = 1 | display static CPU ID |

The CPU runs full-speed from the normal 100 MHz Basys 3 board clock when SW0 is high. There is no slow stepping and no fabric-derived clock in the MIPS measurement wrapper.

## Measurement Formula

```text
MIPS = completed or retired instructions in one second / 1,000,000
```

Pipeline CPUs use their `retire_valid` pulse. Multi-cycle CPUs use a wrapper-derived completion pulse at the safe architectural completion state for each opcode.

## Bitstream Folder

Use this flat folder for programming:

- `reports/phase16c_cpu_mips_compare_bitstreams/`

The original generated Vivado outputs are under:

- `reports/phase16c_cpu_mips_compare_impl/<cpu-name>/`

## Generated Bitstreams

| CPU ID | Bitstream | CPU path | 100 MHz timing |
| ---: | --- | --- | --- |
| 0 | `phase08_multicycle_perf7seg.bit` | Phase 8G multi-cycle CPU | Pass |
| 1 | `phase10h_bram_multicycle_perf7seg.bit` | Phase 10H BRAM multi-cycle CPU | Pass |
| 2 | `phase11e_ctrlopt_prefetch_perf7seg.bit` | Phase 11E control-flow optimised BRAM prefetch CPU | Pass |
| 3 | `phase12_pipeline_perf7seg.bit` | Phase 12 five-stage pipeline | Pass |
| 4 | `phase13e_13i_forwardtiming_perf7seg.bit` | Phase 13E/13I forwarding-timing pipeline | Pass |
| 5 | `phase14g_pipeline6_perf7seg.bit` | Phase 14G six-stage pipeline | Pass |

## Timing Results At 100 MHz

| CPU | WNS | TNS | WHS | THS |
| --- | ---: | ---: | ---: | ---: |
| Phase 8G multi-cycle | +0.581 ns | 0.000 ns | +0.046 ns | 0.000 ns |
| Phase 10H BRAM multi-cycle | +2.799 ns | 0.000 ns | +0.104 ns | 0.000 ns |
| Phase 11E ctrlopt prefetch | +0.334 ns | 0.000 ns | +0.133 ns | 0.000 ns |
| Phase 12 pipeline | +0.099 ns | 0.000 ns | +0.035 ns | 0.000 ns |
| Phase 13E/13I forwardtiming | +0.256 ns | 0.000 ns | +0.038 ns | 0.000 ns |
| Phase 14G pipeline6 | +2.253 ns | 0.000 ns | +0.056 ns | 0.000 ns |

All six comparison MIPS-counter bitstreams generated successfully.

## Board Test Procedure

1. Program one `.bit` file from `reports/phase16c_cpu_mips_compare_bitstreams/`.
2. Set `SW0 = 0`.
3. Press and release BTNC reset.
4. Set `SW1 = 1` and confirm the display shows the CPU ID from the table.
5. Set `SW1 = 0`.
6. Set `SW0 = 1`.
7. Wait at least two seconds so one full one-second measurement window completes.
8. Record the displayed MIPS value.
9. Set `SW0 = 0` to pause; the displayed value remains latched.
10. Repeat for the next bitstream.

## Interpreting Results

These bitstreams all use `programs/fpga_led_demo.mem`, so the board readings compare the CPUs using that loaded hardware demo program. The values may differ from earlier report-table MIPS estimates, because those estimates often used different simulation benchmark programs and post-route Fmax values.

Your Phase 16A board reading of about 63 MIPS for the six-stage CPU is consistent with the expected 100 MHz hardware measurement scale.

## Recommended Next Step

Record the displayed MIPS value for each Phase 16C bitstream. If you need a stricter academic comparison, Phase 16D should replace `fpga_led_demo.mem` with a single benchmark program intentionally designed for all CPU families, then regenerate these MIPS-counter bitstreams.
