# Phase 23 FPGA Timing Results

## Purpose

This report records the Vivado timing results for the Phase 23 retimed JUMP-cache copied CPU.

Phase 23 is only a valid board-test candidate if post-route setup and hold timing are clean and a bitstream is generated. That did not happen for the tested frequencies.

## Implementation Inputs

CPU:

- `rtl/cpu_core_pipeline_forwardtiming_phase23.sv`

Wrapper:

- `rtl/fpga_top_phase23_forwardtiming_mmcm_benchmark.sv`
- `rtl/fpga_top_phase23_forwardtiming_mmcm_targets.sv`

Benchmark:

- `programs/final_benchmark.mem`

Board:

- Digilent Basys 3
- `xc7a35tcpg236-1`

## Commands Run

```powershell
vivado -mode batch -source scripts\run_vivado_impl_phase23_forwardtiming_mmcm_119.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase23_forwardtiming_mmcm_117.tcl
vivado -mode batch -source scripts\run_vivado_impl_phase23_forwardtiming_mmcm_115.tcl
```

The 120 MHz script was prepared but not run because 119 MHz, 117 MHz and 115 MHz all failed timing.

## Timing Table

| Clock | Period | WNS | TNS | WHS | THS | LUTs | FFs | BRAM | DSP | Bitstream | Board status |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 119.000 MHz | 8.403 ns | -0.981 ns | -234.451 ns | +0.132 ns | 0.000 ns | 1,914 | 2,179 | 1 | 0 | not generated | invalid |
| 117.000 MHz | 8.547 ns | -0.895 ns | -162.582 ns | +0.034 ns | 0.000 ns | 1,932 | 2,179 | 1 | 0 | not generated | invalid |
| 115.000 MHz | 8.696 ns | -0.679 ns | -122.466 ns | +0.077 ns | 0.000 ns | 1,903 | 2,179 | 1 | 0 | not generated | invalid |
| 120.000 MHz | 8.333 ns | not run | not run | not run | not run | not run | not run | not run | not run | not generated | not tested |

## Critical Path Summary

Worst 119 MHz path:

- source: `impl/cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`
- destination: `impl/cpu_inst/if_id_reg_reg[pc][30]/D`
- data path delay: 9.290 ns
- logic delay: 5.190 ns
- route delay: 4.100 ns
- logic levels: 13

The path still includes frontend/control update logic after the predictor retiming. Several reported paths also involve high-fanout control and instruction BRAM address/reset logic.

## Comparison With Phase 22

| Design | 119 MHz WNS | 119 MHz TNS | Bitstream |
| --- | ---: | ---: | --- |
| Phase 22 JUMP cache | -1.258 ns | -246.378 ns | not generated |
| Phase 23 retimed JUMP cache | -0.981 ns | -234.451 ns | not generated |

The retiming improved WNS by about 0.277 ns, but the design still misses setup timing by too much to be a hardware candidate.

## Decision

No Phase 23 bitstream should be programmed or used as a performance result. Phase 20E remains the best confirmed physical FPGA measurement at approximately 104 MIPS.

