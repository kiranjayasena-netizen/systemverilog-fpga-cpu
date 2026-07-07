# Phase 3 Checklist

## Purpose

This checklist tracks the Phase 3 FPGA preparation work for the Basys 3 target. It separates completed pre-hardware work from tasks that are blocked until the physical FPGA board is available.

No physical hardware validation has been performed yet.

## Phase 3A: FPGA Wrapper And Constraints

| Task | Status | Evidence | Notes |
| --- | --- | --- | --- |
| `fpga_top` wrapper | Done | `rtl/fpga_top.sv` | Instantiates `cpu_core` and exposes clock, reset, enable switch and LED debug outputs. |
| Basys 3 constraints | Done | `constraints/basys3.xdc`, `reports/basys3_xdc_review.md` | Uses the Basys 3 part flow and maps only the required ports. Final check against official board files is still recommended before programming. |
| LED debug mapping | Done | `rtl/fpga_top.sv`, `docs/fpga_led_expected_sequence.md` | Maps PC, opcode, control signals and ALU result bits to `led[15:0]`. |
| `fpga_led_demo.mem` | Done | `programs/fpga_led_demo.mem`, `docs/fpga_led_expected_sequence.md` | Provides a small looping program for visible PC and opcode changes. |
| `fpga_top` testbench | Done | `tb/fpga_top_tb.sv` | Self-checking wrapper simulation checks known LED activity. |
| XSim regression | Done | `docs/verification.md`, `scripts/run_xsim_regression.ps1` | Existing module and integration testbenches are covered by the local XSim regression script. |

## Phase 3B: Slow Tick And Pre-Hardware Synthesis

| Task | Status | Evidence | Notes |
| --- | --- | --- | --- |
| `slow_tick_generator` | Done | `rtl/slow_tick_generator.sv`, `tb/slow_tick_generator_tb.sv` | Generates a one-cycle clock-enable pulse. It does not create a divided clock. |
| Slow LED-visible stepping | Done | `rtl/fpga_top.sv` | CPU advances when `enable_sw && slow_tick` is true. |
| Vivado synthesis | Done | `reports/phase3b_slow_tick_synthesis_summary.md` | Confirms the slow-tick wrapper can be synthesized for the Basys 3 target. |
| Timing analysis | Done | `reports/phase3a_timing_analysis.md`, `reports/phase3c_implementation_summary.md` | 100 MHz setup timing is not met; the slow tick helps observation but does not close the internal single-cycle timing path. |
| Resource analysis | Done | `reports/phase3b_slow_tick_synthesis_summary.md`, `reports/phase3c_implementation_summary.md` | Resource use is documented from Vivado reports. |

## Phase 3C: Routed Implementation And Bitstream Generation

| Task | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Vivado implementation | Done | `reports/phase3c_implementation_summary.md` | Synthesis, optimisation, placement and routing completed locally. |
| Bitstream generation | Done | `reports/phase3c_implementation_summary.md` | `reports/bitstreams/fpga_top.bit` was generated locally. The `.bit` file is ignored and should not be committed. |
| Build reproducibility | Done | `reports/phase3_build_reproducibility.md` | Records tool version, target part, commands, generated outputs and known timing result. |
| Vivado script review | Done | `reports/phase3_vivado_script_review.md` | Confirms the synthesis and implementation scripts are complete enough for pre-hardware use. |
| Pre-hardware validation report | Done | `reports/phase3_prehardware_validation.md` | Separates simulation, synthesis and implementation evidence from pending hardware evidence. |
| Expected LED sequence | Done | `docs/fpga_led_expected_sequence.md` | Defines the expected LED pattern derived from the demo program and RTL mapping. |
| Bring-up checklist | Done | `docs/basys3_bringup_checklist.md` | Step-by-step checklist for the first physical board session. |

## Phase 3D: Hardware Bring-Up

| Task | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Board programming | Blocked until FPGA | `reports/phase3d_hardware_bringup_template.md` | Requires the physical Basys 3 board. |
| Reset validation on board | Blocked until FPGA | `reports/phase3d_hardware_bringup_template.md` | Must be observed on hardware. |
| Enable switch validation on board | Blocked until FPGA | `reports/phase3d_hardware_bringup_template.md` | Must confirm SW0 controls visible CPU stepping. |
| LED sequence validation on board | Blocked until FPGA | `docs/fpga_led_expected_sequence.md`, `reports/phase3d_hardware_bringup_template.md` | Must compare observed PC and opcode LED sequence against the expected sequence. |
| Evidence capture | Blocked until FPGA | `docs/basys3_bringup_checklist.md`, `reports/phase3d_hardware_bringup_template.md` | Should include photos, short video, date/time, commit hash and notes. |

## Summary

Phase 3A, Phase 3B and Phase 3C are complete at the pre-hardware level. Phase 3D is intentionally blocked until the Basys 3 board is available. Hardware behaviour must not be claimed until the board has been programmed and observed.

