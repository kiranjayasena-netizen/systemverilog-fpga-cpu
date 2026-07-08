# Phase 7 Plan: FPGA Implementation And Timing Closure Preparation

## Goal

Phase 7 moves the project from a verified simulation baseline into FPGA implementation work. The starting point is the Phase 5 and Phase 6 custom-ISA CPU baseline, where file-loaded program execution has passed through Phase 6F in Vivado XSim.

Phase 7 must not change the custom instruction encoding or add new CPU behaviour unless a later timing-closure task explicitly justifies a design change. Phase 7A is documentation-only and freezes the verified simulation baseline before synthesis, implementation and hardware bring-up work continues.

## Phase 7A: Baseline Freeze Checklist

Purpose: record that the simulation baseline is ready for FPGA implementation work.

Checklist:

- Confirm Phase 5 program execution passed.
- Confirm Phase 6A arithmetic edge verification passed.
- Confirm Phase 6B memory offset verification passed.
- Confirm Phase 6C branch taken/not-taken verification passed.
- Confirm Phase 6D jump control verification passed.
- Confirm Phase 6E simple loop verification passed.
- Confirm Phase 6F invalid opcode safety verification passed.
- Run the full local Vivado XSim regression.
- Save a combined Phase 7A regression transcript under `reports/simulation_transcripts/`.
- Confirm no RTL, testbench, program or instruction-encoding changes are included in the baseline freeze.
- Update README status and documentation links.

Acceptance criteria:

- `scripts/run_xsim_regression.ps1` completes successfully.
- The Phase 7A transcript is saved.
- The working diff contains documentation/report updates only.
- No CPU RTL, testbench, program or `.mem` behaviour is changed.

## Known Vivado/XSim Cleanup Warning

Vivado XSim may report that `xelab` returned exit code 1 because an `obj` directory could not be removed after the snapshot was built. This has appeared as an object-directory cleanup warning in the local environment.

For this project, the warning is treated as non-blocking only when all of the following are true:

- The simulation snapshot is built.
- `xsim` starts and runs the testbench.
- The self-checking testbench reports PASS.
- The regression script completes successfully.

Real compile errors, elaboration errors, simulation runtime errors or self-checking test failures are still blocking failures and must fail the phase.

## Phase 7B: Synthesis Plan

Purpose: synthesize the frozen CPU/FPGA wrapper baseline for the Basys 3 target.

Status: completed for the Phase 7A baseline. See `reports/phase7b_synthesis_summary.md`.

Planned actions:

- Use Vivado 2026.1.
- Target the Digilent Basys 3 FPGA part `xc7a35tcpg236-1`.
- Use `fpga_top` as the top module.
- Use `constraints/basys3.xdc`.
- Run `scripts/run_vivado_synth.tcl`.
- Save or regenerate synthesis utilisation, timing and power reports under `reports/`.
- Check that generated binary and tool-output files remain ignored.

Acceptance criteria:

- Synthesis completes without fatal errors.
- Utilisation, timing summary, worst-path timing and power reports are generated.
- Any warnings are reviewed and documented.
- No physical hardware behaviour is claimed.

Phase 7B result:

- Date run: July 8, 2026
- Result: synthesis passed.
- Target part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Utilisation: 2,915 LUTs, 8,314 flip-flops, 0 BRAM tiles, 0 DSPs.
- Post-synthesis timing: 100 MHz setup timing not met, WNS -0.600 ns, TNS -3879.171 ns, hold timing met.
- Summary report: `reports/phase7b_synthesis_summary.md`
- CPU RTL/testbench/program changes in Phase 7B: none.

## Phase 7C: Implementation And Bitstream Plan

Purpose: place, route and generate a bitstream for the Basys 3 wrapper.

Status: completed for the Phase 7A baseline. See `reports/phase7c_implementation_summary.md`.

Planned actions:

- Run `scripts/run_vivado_impl.tcl`.
- Confirm the implementation flow runs synthesis, optimisation, placement and routing.
- Generate implementation utilisation, timing, worst-path timing and power reports.
- Generate an implementation checkpoint.
- Generate a bitstream only from the checked Basys 3 constraints.
- Keep `.bit`, `.bin`, `.dcp`, `.jou`, `.log`, `.wdb`, `.runs`, `.cache`, `.sim` and `.Xil` outputs out of Git unless explicitly requested.

Acceptance criteria:

- Implementation completes or the first real error is documented.
- Bitstream generation status is recorded.
- Resource and timing results are documented.
- The repository does not commit generated Vivado output folders or large binary artifacts.

Phase 7C result:

- Date run: July 8, 2026
- Result: implementation passed.
- Bitstream generation: passed.
- Target part: `xc7a35tcpg236-1`
- Top module: `fpga_top`
- Utilisation: 2,983 LUTs, 8,314 flip-flops, 0 BRAM tiles, 0 DSPs.
- Post-route timing: 100 MHz setup timing not met, WNS -1.551 ns, TNS -5707.315 ns, hold timing met with WHS 0.075 ns.
- Summary report: `reports/phase7c_implementation_summary.md`
- CPU RTL/testbench/program changes in Phase 7C: none.

## Phase 7D: Timing Analysis Plan

Purpose: analyse whether the implemented design meets the 100 MHz Basys 3 clock target and identify the critical path.

Status: completed for the Phase 7C routed implementation. See `reports/phase7d_timing_analysis.md`.

Planned actions:

- Review post-route timing summary.
- Record WNS, TNS, hold slack and target clock period.
- Estimate maximum frequency if setup timing is not met.
- Review worst-path timing report.
- Classify the critical path, for example fetch/decode/execute, memory/writeback, branch/PC, or another path.
- Compare timing against earlier Phase 3A to Phase 3C findings.
- Document whether the slow tick helps board observability only, rather than internal 100 MHz timing closure.

Acceptance criteria:

- Timing pass/fail is stated clearly.
- Worst path startpoint, endpoint and likely datapath category are recorded.
- The report distinguishes simulation correctness from hardware timing closure.
- Recommended timing-closure next steps are documented.

Phase 7D result:

- Date documented: July 8, 2026
- Result: post-route 100 MHz setup timing is not met.
- Hold timing: met.
- Worst setup slack: WNS -1.551 ns.
- Total setup violation: TNS -5707.315 ns.
- Estimated maximum frequency from worst slack: approximately 86.6 MHz.
- Critical path: `cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C` to `cpu_inst/reg_file_inst/regs_reg[2][12]/D`.
- Path classification: single-cycle-style PC/fetch/decode/execute/writeback path.
- Timing report: `reports/phase7d_timing_analysis.md`
- CPU RTL/testbench/program changes in Phase 7D: none.

## Phase 7E: Basys 3 Hardware Bring-Up Plan

Purpose: use the physical Basys 3 board to validate basic programming, reset, enable and LED-observable CPU behaviour.

Planned actions:

- Use the generated `fpga_top` bitstream after constraints have been reviewed.
- Connect the Basys 3 over USB.
- Open Vivado Hardware Manager.
- Program the device.
- Press reset.
- Toggle the enable switch.
- Observe `led[15:0]`.
- Compare observed LED behaviour with `docs/fpga_led_expected_sequence.md`.
- Capture photos, short video, date/time, commit hash and notes.
- Fill in `reports/phase3d_hardware_bringup_template.md` or a Phase 7 equivalent report.

Acceptance criteria:

- Board programming result is recorded.
- Reset button behaviour is observed and recorded.
- Enable switch behaviour is observed and recorded.
- LED sequence evidence is compared with the expected sequence.
- Any mismatch is documented with enough detail to reproduce.
- No hardware validation is claimed before the physical board is actually tested.

## Phase 7F: Supervisor-Facing Implementation Summary Plan

Purpose: produce a concise report suitable for review by a university supervisor.

Planned content:

- Project state at the start of Phase 7.
- Simulation evidence from Phase 5 and Phase 6.
- Synthesis result.
- Implementation result.
- Timing result and critical-path interpretation.
- Resource usage summary.
- Power estimate.
- Hardware bring-up status.
- Known limitations.
- Recommended next work, such as multi-cycle redesign, registered memory outputs or pipelining.

Acceptance criteria:

- The summary is academically honest.
- It separates simulation evidence, FPGA tool evidence and physical hardware evidence.
- It does not claim board validation until the board has actually been programmed and observed.
- It gives clear next actions for timing closure and final-year project direction.

## Phase 7A Baseline Statement

At the Phase 7A freeze point, the verified CPU behaviour is the custom-ISA simulation baseline through Phase 6F. The next work should focus on FPGA synthesis, implementation, timing analysis and hardware bring-up preparation without changing the CPU RTL or instruction encodings.

Phase 7A baseline regression result:

- Date run: July 8, 2026
- Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

- Result: passed.
- Transcript: `reports/simulation_transcripts/phase7a_baseline_xsim_regression_20260708_134230.txt`
- Behaviour frozen: Phase 5 program execution plus Phase 6A through Phase 6F program-level verification.
- RTL/testbench/program changes in Phase 7A: none.
