# Phase 17E MMCM High-Frequency MIPS Test

## Purpose

Phase 17E creates a Basys 3 hardware test bitstream that runs the original Phase 13 forward-timing CPU above the fixed 100 MHz board clock and displays the measured MIPS value on the 7-segment display.

This phase does not modify the CPU core. It adds a separate FPGA top wrapper with an RTL-instantiated 7-series MMCM.

## Baseline

Confirmed Phase 17A/17B board readings at 100 MHz:

| Metric | Display | Meaning |
| --- | ---: | --- |
| MIPS | `0087` | approximately 87 MIPS |
| CPI x100 | `0115` | approximately 1.15 CPI |
| Control flush x100 | `1250` | approximately 12.50% |

Phase 17D timing-supported estimate:

| Metric | Value |
| --- | ---: |
| Best passing period | 8.650 ns |
| Frequency | 115.607 MHz |
| WNS/TNS/WHS/THS | +0.059 / 0.000 / +0.057 / 0.000 |
| Estimated MIPS using CPI 1.15 | approximately 100.5 |

## MMCM Clock Choice

Phase 17E targets 115.000 MHz instead of pushing to 117+ MHz.

Reason:

- 115 MHz is slightly below the 115.607 MHz timing-supported point.
- 115 MHz / 1.15 CPI is approximately 100 MIPS.
- Phase 17D showed 8.500 ns / 117.647 MHz failed setup timing.

MMCM configuration:

| Item | Value |
| --- | ---: |
| Input clock | 100 MHz |
| DIVCLK_DIVIDE | 5 |
| CLKFBOUT_MULT_F | 46.000 |
| VCO | 920 MHz |
| CLKOUT0_DIVIDE_F | 8.000 |
| Generated CPU clock | 115.000 MHz |
| Generated period | 8.696 ns |

Vivado auto-derived the generated clock `cpu_clk_unbuf` from the MMCM.

## Files Created

- `rtl/fpga_top_pipeline_forwardtiming_mmcm_mips.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming_mmcm_mips.tcl`
- `reports/phase17e_mmcm_high_frequency_mips_test.md`

## Top Module

Top module:

- `fpga_top_pipeline_forwardtiming_mmcm_mips`

Ports:

- `clk`: Basys 3 100 MHz board clock
- `rst_btn`: BTNC reset
- `sw[0]`: run enable
- `sw[3:1]`: display mode
- `led[15:0]`: debug/status LEDs
- `seg[6:0]`, `an[3:0]`, `dp`: active-low 7-segment display

## Measurement

The CPU and measurement logic run in the 115 MHz generated CPU clock domain.

Measurement formula:

```text
MIPS = retired instructions in one real second / 1,000,000
```

The one-second window is calibrated to:

```text
CPU_CLOCK_HZ = 115,000,000
```

CPI x100 uses the generated-clock window:

```text
CPI x100 = 11500 / integer_MIPS
```

For example, if the MIPS display is `0100`, CPI x100 should be close to `0115`.

## Display Modes

| SW3:SW1 | Display |
| ---: | --- |
| 000 | measured integer MIPS, expected around `0100` |
| 001 | CPI x100, expected around `0115` |
| 010 | load-use stall percentage x100 |
| 011 | control-flush percentage x100, expected around `1250` if workload behaviour is similar |
| 100 | instruction-fetch wait percentage x100 |
| 101 | memory-wait percentage x100 |
| 110 | generated-clock debug value `0115` |
| 111 | measured integer MIPS |

## LED Mapping

| LED | Signal |
| ---: | --- |
| 0 | MMCM locked |
| 1 | synchronized CPU run enable |
| 2 | measurement window has completed at least once |
| 3 | CPU reset active |
| 7:4 | decoded opcode |
| 8 | IF/ID valid |
| 9 | sticky retire observed |
| 10 | sticky register write observed |
| 11 | sticky memory write observed |
| 12 | sticky redirect observed |
| 15:13 | `{ID/EX, EX/MEM, MEM/WB}` valid bits |

Sticky event LEDs clear on reset and remain set while SW0 is off.

## Vivado Result

Script:

```powershell
vivado -mode batch -source scripts\run_vivado_impl_pipeline_forwardtiming_mmcm_mips.tcl
```

Post-route timing:

| Metric | Value |
| --- | ---: |
| Input clock | 10.000 ns / 100.000 MHz |
| CPU clock | 8.696 ns / 115.000 MHz |
| WNS | +0.008 ns |
| TNS | 0.000 ns |
| WHS | +0.035 ns |
| THS | 0.000 ns |
| Route status | fully routed, 0 routing errors |
| Bitstream generation | passed |

Utilisation:

| Resource | Value |
| --- | ---: |
| LUTs | 1,829 |
| FFs | 2,072 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| MMCM | 1 |
| Power estimate | 0.213 W |

Worst setup path:

| Item | Value |
| --- | --- |
| Source | `cpu_inst/mem_wb_reg_reg[rd][2]/C` |
| Destination | `cpu_inst/id_ex_reg_reg[operand_b][22]/R` |
| Slack | +0.008 ns |
| Data path delay | 7.989 ns |
| Logic delay | 2.369 ns, 29.651% |
| Route delay | 5.620 ns, 70.349% |
| Logic levels | 10 |

Bitstream path:

- `reports/phase17e_mmcm_mips_impl/bitstreams/fpga_top_pipeline_forwardtiming_mmcm_mips.bit`

## Hardware Test Procedure

1. Run `scripts/run_vivado_impl_pipeline_forwardtiming_mmcm_mips.tcl`.
2. Confirm post-route timing is clean.
3. Program `reports/phase17e_mmcm_mips_impl/bitstreams/fpga_top_pipeline_forwardtiming_mmcm_mips.bit`.
4. Press and release BTNC reset.
5. Confirm LED0 is on, meaning the MMCM is locked.
6. Set SW0 = 1 to run the CPU.
7. Wait at least two one-second measurement windows.
8. Set SW3:SW1 = `000` and record MIPS. Expected value is around `0100`.
9. Set SW3:SW1 = `001` and record CPI x100. Expected value is around `0115`.
10. Set SW3:SW1 = `011` and record control-flush x100. Expected value is around `1250` if workload behaviour is similar.
11. Capture photo/video evidence of the 7-segment display.

## Limitations

- The bitstream is timing-clean, but the final MIPS value still needs board observation.
- The expected `0100` assumes the 100 MHz board CPI remains close to 1.15 at 115 MHz.
- The measurement program is still the FPGA demo program used by the Phase 13/17 hardware wrappers.
- The 7-segment display shows integer MIPS, so fractional precision is lost.

## Recommended Next Step

Program the Phase 17E bitstream on the Basys 3 and record:

- MIPS mode `000`
- CPI x100 mode `001`
- control-flush x100 mode `011`

If the board displays around `0100`, Phase 17E becomes the first physical hardware evidence for approximately 100 MIPS on this project.
