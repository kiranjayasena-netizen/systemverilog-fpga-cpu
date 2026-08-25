# Reproducibility Guide

This guide reproduces or locates the final evidence for the frozen CPU. It
does not change RTL, constraints, or benchmark architecture.

## Environment and frozen design

- Windows PowerShell
- Vivado 2026.1: `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`
- Basys 3, `xc7a35tcpg236-1`
- Development branch: `feature/phase12-mac8-ai`
- Core: `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Wrapper: `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Constraints: `constraints/basys3.xdc`

The highest repeatably validated clock is 93 MHz, PASS 5/5. The retained
final evidence is under `reports/dot4acc_stage_h/final_t2_93mhz/`; 94 MHz is
the nearest tested failure and 100 MHz is not closed.

## Evidence map

| Area | Location |
|---|---|
| Architecture specification | `reports/final_cpu_architecture.md` |
| Stage H history/results | `reports/dot4acc_stage_h_memory_feed.md`, `reports/dot4acc_stage_h/` |
| Stage I measurement | `reports/dot4acc_stage_i_scalar_overlap.md` |
| Stage J workload | `reports/dot4acc_stage_j_ai_workload.md` |
| Stage K characterisation | `reports/dot4acc_stage_k_final_characterisation.md` |
| Stage L comparison | `reports/dot4acc_stage_l_final_comparison.md`, `reports/dot4acc_stage_l/results.csv` |
| Final summary/tables | `reports/final_project_results.md`, `reports/final_project_results.csv` |

Existing self-checking testbenches in `tb/` are the authoritative simulation
entry points. The Stage L comparison can be rebuilt with the repository's
Vivado XSim tools by compiling `rtl/cpu_defs_pkg.sv`, the BRAM/DOT modules,
the frozen T2 core, and `tb/tb_dot4acc_stage_l_comparison.sv`, then elaborating
and running `tb_dot4acc_stage_l_comparison`. The expected valid outputs are:

- Stage H memory-fed N=128: 263 cycles, 8K+7, 31/31/31/31 ownership counts.
- Stage J J1 N=128: 358 cycles, `0x000028e5`.
- Stage J J2 2x64: 331 cycles, `0x000024e5` and `0x0000bf7b`.
- Stage L MAC8: 134 cycles, `0x00004f25`.
- Stage L DOT4ACC: 43 cycles, `0x00004f25`.

The Stage L four-lane pattern is `A=[3,-2,1,-1]`, `B=[127,-128,0,5]`,
accumulator 37, repeated 32 times. Thus it is 32 four-lane DOT operations,
or 128 total signed-int8 products—not merely four products.

## Physical-flow caveat

Previous Vivado Tclapp initialization failures (`Could not open 'C' for
writing`) were avoided by launching with temporary clean `APPDATA`,
`LOCALAPPDATA`, and `XILINX_LOCAL_USER_DATA` directories while preserving the
user's normal environment. Do not delete or overwrite normal Vivado settings.

## Expected final headline

H1.3b reduced the memory-fed N=128 kernel from 294 to 263 cycles. The frozen
CPU is validated at 93 MHz and delivers 45.26 MMAC/s on that kernel,
33.2514 MMAC/s on the complete J1 N=128 program, and 35.9637 MMAC/s on J2.
On equivalent register-resident work, DOT4ACC completes 128 useful MACs in
43 cycles versus 134 for MAC8 (3.1163x). No scalar same-workload speedup is
claimed because the frozen scalar ISA lacks general multiply/byte extraction.
