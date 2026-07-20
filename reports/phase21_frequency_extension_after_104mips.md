# Phase 21 Frequency Extension After 104 MIPS

## Purpose

Phase 21E prepares a small follow-up frequency sweep for the original Phase 13 / Phase 20E hardware path. This is secondary to CPI optimisation and does not modify the original CPU RTL.

The goal is to check whether the proven Phase 20E path can be pushed beyond 119.000 MHz. A new measured record can only be claimed after clean timing and physical board observation.

## Baseline

| Metric | Value |
| --- | ---: |
| Current best physical result | Phase 20E |
| CPU | Original Phase 13 forward-timing CPU |
| Clock | 119.000 MHz |
| Board display | `0104` |
| Timing | WNS +0.003 ns, TNS 0.000 ns, WHS +0.086 ns |

## Prepared Targets

The following wrapper target file was added:

- `rtl/fpga_top_phase21_phase20e_frequency_targets.sv`

It instantiates the existing Phase 19A/20E-style original-CPU MIPS wrapper with new MMCM parameters and matching `CPU_CLOCK_HZ` values.

Prepared implementation scripts:

```powershell
vivado -mode batch -source scripts\run_vivado_impl_phase21_phase20e_119p5.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase21_phase20e_120p0.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase21_phase20e_120p5.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase21_phase20e_121p0.tcl
```

Expected output folders:

- `reports/phase21_phase20e_frequency_extension_impl/119p5/`
- `reports/phase21_phase20e_frequency_extension_impl/120p0/`
- `reports/phase21_phase20e_frequency_extension_impl/120p5/`
- `reports/phase21_phase20e_frequency_extension_impl/121p0/`

## Sweep Table

| Target clock | CPU_CLOCK_HZ | WNS | TNS | WHS | THS | Bitstream | Valid for board test | Board MIPS |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |
| 119.500 MHz | 119,500,000 | not run | not run | not run | not run | not generated | not yet | not tested |
| 120.000 MHz | 120,000,000 | not run | not run | not run | not run | not generated | not yet | not tested |
| 120.500 MHz | 120,500,000 | not run | not run | not run | not run | not generated | not yet | not tested |
| 121.000 MHz | 121,000,000 | not run | not run | not run | not run | not generated | not yet | not tested |

## Expected Displays If Timing Passes

These are rough expectations only, assuming CPI remains close to the Phase 20E demo-workload behaviour:

| Clock | Possible display |
| ---: | ---: |
| 119.5 MHz | `0104` or `0105` |
| 120.0 MHz | `0104` or `0105` |
| 120.5 MHz | around `0105` |
| 121.0 MHz | around `0105` |

These are not measured results.

## Board-Test Rule

Only test a frequency on the board if:

- WNS >= 0;
- TNS = 0;
- WHS >= 0;
- THS = 0;
- route completes cleanly;
- bitstream generation succeeds.

Then use SW3:SW1 = `000` for MIPS mode and record the physical 7-segment display.

## Decision

No Phase 21E frequency-extension result is claimed yet. Phase 20E remains the best physical result until a higher timing-clean bitstream is physically tested.
