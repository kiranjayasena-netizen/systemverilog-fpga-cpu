# Phase 24 FPGA Timing Results

## Purpose

This report records Vivado implementation results for the Phase 24 frontend-split copied CPU. These are timing experiments only. No Phase 24 physical board MIPS result is claimed.

## Source Files

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_forwardtiming_phase24.sv`
- `rtl/fpga_top_phase24_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase24_forwardtiming_mmcm_targets.sv`

## Implementation Commands Run

```powershell
vivado -mode batch -source scripts\run_vivado_impl_phase24_forwardtiming_mmcm_100.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase24_forwardtiming_mmcm_105.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase24_forwardtiming_mmcm_110.tcl
```

The 115, 117 and 119 MHz scripts were prepared but not run because 110 MHz failed setup timing and the XSim CPI result was already below the performance target.

## Timing and Utilisation

| Clock | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Bitstream | Board status |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 100 MHz | +0.107 ns | 0.000 ns | +0.034 ns | 0.000 ns | 1,642 | 2,074 | 1 Block RAM Tile | 0 | generated | not tested |
| 105 MHz | +0.059 ns | 0.000 ns | +0.034 ns | 0.000 ns | 1,647 | 2,076 | 1 Block RAM Tile | 0 | generated | not tested |
| 110 MHz | -0.574 ns | -162.224 ns | +0.113 ns | 0.000 ns | 1,658 | 2,075 | 1 Block RAM Tile | 0 | not generated | invalid |

Timing-clean bitstream paths:

```text
reports/phase24_forwardtiming_mmcm_impl/100/bitstreams/fpga_top_phase24_forwardtiming_mmcm_100.bit
reports/phase24_forwardtiming_mmcm_impl/105/bitstreams/fpga_top_phase24_forwardtiming_mmcm_105.bit
```

These generated bitstreams are implementation artifacts and should not be committed.

## 110 MHz Critical Path

The 110 MHz implementation failed setup timing:

- Slack: -0.574 ns
- Requirement: 9.091 ns
- Data path delay: 9.569 ns
- Logic delay: 5.329 ns
- Route delay: 4.240 ns
- Logic levels: 13
- Source: `impl/cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`
- Destination: `impl/cpu_inst/redirect_pending_target_reg[30]/D`

The failed path still involves redirect target generation and the pending redirect target register. Phase 24 moved the immediate instruction-request path behind a register, but the redirect target calculation remains too long at 110 MHz in this implementation.

## Decision

Phase 24 produced timing-clean 100 and 105 MHz candidates, but the aligned-benchmark CPI is 1.508978. Even at 105 MHz, predicted throughput is only about 69.6 MIPS:

```text
105 / 1.508978 = approximately 69.6 MIPS
```

The timing-clean bitstreams are therefore not useful performance candidates. Phase 20E remains the best confirmed physical FPGA result at approximately 104 MIPS.
