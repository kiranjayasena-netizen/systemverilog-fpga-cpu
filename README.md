# systemverilog-fpga-cpu

SystemVerilog FPGA soft-core processor summer project.

## Project Aim

The aim of this repository is to build a simple FPGA soft-core processor in SystemVerilog and use it as a practical study of digital design, verification, FPGA implementation, timing closure, resource usage and maximum clock frequency.

The project starts with small, verified RTL blocks and builds toward an integrated CPU core that can be simulated, synthesized and analysed in Vivado.

## Current Status

- Vivado 2026.1 is installed and licensed with Vivado Basic.
- Vivado XSim is the main simulator.
- GitHub is connected to ChatGPT.
- Codex CLI is installed.
- `rtl/cpu_defs_pkg.sv` defines shared opcode and ALU operation constants without changing the instruction encodings.
- `rtl/alu.sv` contains the first RTL module: a parameterised combinational ALU that defaults to the 32-bit CPU datapath width.
- `tb/alu_tb.sv` contains a self-checking 32-bit ALU testbench.
- The parameterised 32-bit ALU simulation has passed in Vivado XSim.
- `rtl/register_file.sv` contains a 32-register, 32-bit register file.
- `tb/register_file_tb.sv` contains a self-checking register file testbench.
- The register file simulation has passed in Vivado XSim.
- `rtl/program_counter.sv` contains the 32-bit program counter.
- `tb/program_counter_tb.sv` contains a self-checking program counter testbench.
- The program counter simulation has passed in Vivado XSim.
- `rtl/instruction_memory.sv` contains the combinational instruction memory.
- `tb/instruction_memory_tb.sv` contains a self-checking instruction memory testbench.
- The instruction memory simulation has passed in Vivado XSim.
- `rtl/data_memory.sv` contains the standalone data memory block used by the CPU core for LOAD and STORE support.
- `tb/data_memory_tb.sv` contains a self-checking data memory testbench.
- The data memory simulation has passed in Vivado XSim.
- `rtl/fetch_unit.sv` integrates the program counter and parameterised instruction memory.
- `tb/fetch_unit_tb.sv` contains a self-checking fetch unit testbench.
- The fetch unit simulation has passed in Vivado XSim.
- `rtl/instruction_decoder.sv` decodes the 32-bit instruction fields for opcode, register indexes and signed immediate values.
- `tb/instruction_decoder_tb.sv` contains a self-checking instruction decoder testbench.
- The instruction decoder simulation has passed in Vivado XSim.
- `rtl/control_unit.sv` maps decoded instruction opcodes to register write, immediate select, ALU operation, memory access, branch, jump and validity control signals.
- `tb/control_unit_tb.sv` contains a self-checking control unit testbench.
- The control unit simulation has passed in Vivado XSim.
- `rtl/cpu_core.sv` integrates fetch, decode, control, register file, ALU and data memory blocks into the first simple CPU core, with instruction memory depth and init-file parameters exposed for program loading.
- `tb/cpu_core_tb.sv` contains a strengthened self-checking CPU core integration testbench.
- The CPU core simulation has passed in Vivado XSim, including LOAD, STORE, BEQ and JUMP integration.
- `programs/load_store_test.mem` contains a file-loadable LOAD/STORE CPU test program.
- `tb/cpu_core_program_tb.sv` contains a self-checking CPU core testbench that loads `programs/load_store_test.mem` through the instruction memory `INIT_FILE` path.
- The file-loaded CPU core program simulation has passed in Vivado XSim.
- `programs/branch_jump_test.mem` contains a file-loadable BEQ/JUMP CPU test program.
- `tb/cpu_core_branch_tb.sv` and `tb/cpu_core_branch_program_tb.sv` contain self-checking branch/jump CPU core testbenches.
- The branch/jump CPU core simulations have passed in Vivado XSim.
- `rtl/fpga_top.sv` provides the first FPGA-facing wrapper around `cpu_core`.
- `programs/fpga_led_demo.mem` contains a small instruction program for LED debug bring-up.
- Phase 3 targets the Digilent Basys 3 board with FPGA part `xc7a35tcpg236-1`.
- `constraints/basys3.xdc` maps the current wrapper ports to the Basys 3 clock, reset button, enable switch and LEDs.
- `tb/fpga_top_tb.sv` contains a self-checking simulation for the FPGA wrapper LED debug outputs.
- `scripts/run_vivado_synth.tcl` and `scripts/run_vivado_impl.tcl` provide baseline Vivado build scripts for the Basys 3 target.
- Phase 5 memory system and program execution support is complete in simulation.
- `rtl/instr_mem.sv` and `rtl/data_mem.sv` provide standalone Phase 5 instruction and data memory modules.
- `rtl/cpu_top.sv` provides a runnable CPU system wrapper around the existing integrated `cpu_core`.
- `programs/add_test.mem` contains a file-loaded custom-ISA program that computes `5 + 7` and stores the result in data memory.
- `tb/tb_instr_mem.sv`, `tb/tb_data_mem.sv` and `tb/tb_program_execution.sv` contain self-checking Phase 5 testbenches.
- The Phase 5 program execution simulation has passed in Vivado XSim.
- Phase 6 expanded custom-ISA program verification is complete through Phase 6F.
- The full local Vivado XSim regression passes through Phase 6F.
- Phase 6 program-level tests cover arithmetic edge cases, memory offsets, branch taken/not-taken control flow, jump control, simple loop execution and invalid opcode safety.
- Phase 7A simulation baseline freeze is complete.
- Phase 7B synthesis evidence has been captured for the Basys 3 target.
- Phase 7C implementation and bitstream evidence has been captured for the Basys 3 target.
- Phase 7D post-route timing analysis is documented; the design fits in the Basys 3 but does not meet 100 MHz setup timing.
- Phase 7E Basys 3 bring-up planning is prepared; physical board testing has not been recorded yet.
- Phase 8A multi-cycle CPU redesign planning is documented as the recommended timing-improvement direction.
- Phase 8B has started with a separate multi-cycle CPU FSM skeleton; the existing `rtl/cpu_core.sv` baseline has not been replaced.
- The Phase 8B FSM skeleton simulation has passed in Vivado XSim.
- Phase 8C arithmetic execution for the separate multi-cycle CPU has passed in Vivado XSim.
- Phase 8D LOAD/STORE memory execution for the separate multi-cycle CPU has passed in Vivado XSim.
- Phase 8E BEQ/JUMP control-flow execution for the separate multi-cycle CPU has passed in Vivado XSim.
- Phase 8F full custom-ISA program verification for the separate multi-cycle CPU has passed in Vivado XSim.
- The full local Vivado XSim regression now passes through the Phase 13G registered target-buffer experiment.
- Phase 8G synthesis and implementation comparison for the separate multi-cycle FPGA top has passed; the multi-cycle path meets the 100 MHz post-route timing target.
- Phase 10A simulation-based performance benchmarking for the separate multi-cycle CPU has passed in Vivado XSim.
- Phase 10B single-cycle-style versus multi-cycle architecture trade-off comparison has passed in Vivado XSim.
- Phase 10C standalone BRAM-style instruction and data memory prototype simulations have passed in Vivado XSim.
- Phase 10D BRAM integration planning is documented for the future BRAM-aware CPU path.
- Phase 10F adds a separate BRAM-aware multi-cycle CPU variant with a focused basic simulation passing in Vivado XSim.
- Phase 10G full custom-ISA verification for the separate BRAM-aware multi-cycle CPU has passed in Vivado XSim.
- Phase 10H BRAM-aware synthesis, implementation, bitstream generation and timing comparison have passed for the separate BRAM-aware FPGA top.
- Phase 11A adds a separate BRAM-aware instruction prefetch CPU prototype; the focused basic prefetch simulation has passed in Vivado XSim.
- Phase 11B full custom-ISA verification for the BRAM-aware prefetch CPU has passed in Vivado XSim, reducing aggregate CPI from 4.672 to 3.086 versus the Phase 10G BRAM-aware baseline.
- Phase 11C synthesis, implementation and bitstream generation have passed for the separate BRAM-aware prefetch FPGA top; it meets 100 MHz timing with WNS +1.247 ns.
- Phase 11D adds a separate control-flow-optimised prefetch CPU variant; simulation passes and aggregate CPI improves from 3.086 to 2.983 versus Phase 11B.
- Phase 11E synthesis, implementation and bitstream generation have passed for the separate control-flow-optimised prefetch FPGA top; it meets 100 MHz timing with WNS +1.128 ns.
- Phase 12A pipeline architecture planning is documented as the next major performance direction.
- Phase 12 adds a separate full pipelined CPU path with synchronous instruction/data BRAM, forwarding, load-use stalls, branch/jump flush handling and architectural retirement.
- The Phase 12 pipeline passes the full custom-ISA XSim test and Basys 3 post-route 100 MHz timing, but reaches about 71.1 practical estimated MIPS, so the 90 MIPS target remains future optimisation work.
- Phase 13A adds a separate jumpfast pipeline variant that requests unconditional JUMP targets directly from ID; full regression and implementation pass, improving practical estimated throughput to about 76.1 MIPS while still below the 90 MIPS target.
- Phase 13B adds a separate BEQ target-prefetch experiment; full regression and implementation pass, but practical estimated throughput is about 75.3 MIPS, so Phase 13A remains the preferred pipeline variant.
- Phase 13C adds a separate timing-optimised jumpfast pipeline path; full regression passes, routed implementation passes at a verified 9.100 ns period with Vivado performance directives, and practical estimated throughput improves to about 82.1 MIPS. The 90 MIPS target is not yet reached.
- Phase 13D tests a separate load-forwarding timing experiment; full regression and implementation pass, but extra stalls reduce practical estimated throughput to about 80.7 MIPS, so it did not replace Phase 13C.
- Phase 13E tests a separate forwarding-path restructuring experiment; full regression passes, routed implementation passes at a final verified 8.850 ns period after the Phase 13H sweep, and practical estimated throughput improves to about 84.4 MIPS. Phase 13E is the preferred measured pipeline path.
- Phase 13G tests a separate registered target-buffer experiment; the focused test and routed 8.900 ns implementation pass, but aggregate CPI and Fmax match Phase 13E while resources increase, so Phase 13E remains preferred.
- Phase 13H consolidates the Phase 13 optimisation study and confirms Phase 13E as the preferred measured implementation. The 90 MIPS target has not yet been reached.
- Phase 13I tests Vivado implementation strategies for the unchanged Phase 13E RTL; the fanout-focused strategy closes timing at 8.650 ns and improves practical estimated throughput to about 86.4 MIPS. The 90 MIPS target is still not reached.
- Phase 14A plans a deeper six-stage pipeline as a future route toward 90+ MIPS; no RTL has been changed for this planning phase.
- Phase 14B adds a separate six-stage pipeline skeleton; the focused XSim test and full local regression pass, but no performance improvement is claimed yet.
- Phase 14C adds arithmetic execution to the separate six-stage pipeline; ADD/SUB/AND/OR/XOR/ADDI pass focused XSim verification, with Phase 13I still the preferred measured result.
- Phase 14D adds LOAD/STORE execution to the separate six-stage pipeline; focused memory XSim and full local regression pass, with Phase 13I still the preferred measured result.
- Phase 14E adds BEQ/JUMP redirects and wrong-path protection to the separate six-stage pipeline; focused control-flow XSim and full local regression pass, with Phase 13I still the preferred measured result.
- Phase 14F adds full custom-ISA style program verification and CPI measurement for the separate six-stage pipeline; focused XSim and full local regression pass with 95 cycles, 58 retired instructions and CPI 1.638. No Phase 14 MIPS result is claimed until Phase 14G timing evidence exists.
- Phase 14G implements the separate six-stage pipeline on the Basys 3 target and passes post-route timing at 6.000 ns. Using the Phase 14F CPI of 1.638, the measured practical estimated throughput is about 101.8 MIPS, so Phase 14G is now the preferred measured implementation result.
- Phase 15A adds a separate Basys 3 slow-enable bring-up wrapper for the Phase 14G CPU. It maps SW0 to run enable, SW1 to slow mode and LEDs to fetch/pipeline/side-effect debug signals; the 100 MHz bring-up bitstream has been generated.
- ALU, register file, program counter, instruction memory, fetch unit, instruction decoder, control unit and Phase 5 waveform images have been generated.
- Documentation scaffolding has been added under `docs/`.

## Documentation

- [ISA reference](docs/isa.md) documents the custom 32-bit instruction format, opcode map, immediate sign extension and branch/jump target calculation.
- [Architecture overview](docs/architecture.md) explains the CPU datapath at a beginner-friendly level.
- [Architecture notes](docs/architecture_notes.md) track lower-level design notes as the implementation evolves.
- [Phase 5 plan](docs/phase5_plan.md) explains the memory system and program execution simulation.
- [Phase 6 plan](docs/phase6_plan.md) explains the expanded custom-ISA program verification suite.
- [Phase 7 plan](docs/phase7_plan.md) defines the simulation baseline freeze, FPGA implementation plan, timing analysis plan and Basys 3 bring-up plan.
- [Phase 7B synthesis summary](reports/phase7b_synthesis_summary.md) records the Basys 3 synthesis result, utilisation, timing and warnings.
- [Phase 7C implementation summary](reports/phase7c_implementation_summary.md) records the Basys 3 implementation result, bitstream status, post-route timing and warnings.
- [Phase 7D timing analysis](reports/phase7d_timing_analysis.md) explains the 100 MHz setup timing miss and critical path.
- [Phase 7E Basys 3 bring-up report](reports/phase7e_basys3_bringup.md) is the planning and evidence-capture report for the first physical board session.
- [Phase 8 multi-cycle redesign plan](docs/phase8_multicycle_redesign_plan.md) proposes a future FSM-based CPU redesign to improve timing closure while preserving the custom ISA.
- [Phase 8G multi-cycle timing comparison](reports/phase8g_multicycle_timing_comparison.md) compares the Phase 7 single-cycle-style FPGA baseline with the separate multi-cycle FPGA implementation path.
- [Phase 10A performance benchmarking](reports/phase10a_performance_benchmarking.md) records simulation-based CPI, MIPS and runtime estimates for the separate multi-cycle CPU.
- [Phase 10B architecture trade-off comparison](reports/phase10b_architecture_tradeoff_comparison.md) compares the original single-cycle-style CPU with the timing-clean multi-cycle CPU implementation.
- [Phase 10C BRAM memory study](reports/phase10c_bram_memory_study.md) documents standalone synchronous-read BRAM-style instruction and data memory prototypes.
- [Phase 10D BRAM integration plan](reports/phase10d_bram_integration_plan.md) defines the future FSM, verification and timing-comparison plan for integrating BRAM-style memories into a separate multi-cycle CPU path.
- [Phase 10F BRAM-aware CPU variant](reports/phase10f_bram_cpu_variant.md) documents the first separate BRAM-aware multi-cycle CPU implementation and focused basic simulation.
- [Phase 10G BRAM-aware full verification](reports/phase10g_bram_cpu_full_verification.md) records full custom-ISA program verification, CPI and estimated MIPS for the BRAM-aware CPU variant.
- [Phase 10H BRAM-aware timing comparison](reports/phase10h_bram_timing_comparison.md) records the separate BRAM-aware FPGA build result and comparison against the Phase 8G multi-cycle baseline.
- [Phase 11A BRAM prefetch prototype](reports/phase11a_bram_prefetch_plan_and_basic_test.md) documents the separate instruction-prefetch CPU variant and focused basic simulation result.
- [Phase 11B BRAM prefetch full verification](reports/phase11b_bram_prefetch_full_verification.md) records full custom-ISA simulation, CPI and estimated MIPS for the BRAM-aware prefetch CPU variant.
- [Phase 11C BRAM prefetch timing comparison](reports/phase11c_prefetch_timing_comparison.md) records synthesis, implementation, timing and practical estimated MIPS for the separate prefetch FPGA top.
- [Phase 11D control-flow prefetch optimisation](reports/phase11d_control_flow_prefetch_optimisation.md) records the separate control-flow-optimised prefetch CPU simulation and CPI comparison.
- [Phase 11E control-flow prefetch timing comparison](reports/phase11e_ctrlopt_timing_comparison.md) records synthesis, implementation, timing and practical estimated MIPS for the separate control-flow-optimised prefetch FPGA top.
- [Phase 12A pipeline architecture plan](reports/phase12a_pipeline_architecture_plan.md) defines the proposed five-stage pipeline, hazard strategy, verification roadmap and future comparison plan.
- [Phase 12B pipeline skeleton](reports/phase12b_pipeline_skeleton.md) documents the separate pipelined CPU skeleton, synchronous instruction-BRAM timing, IF/ID valid-bit behaviour and focused XSim result.
- [Phase 12 pipeline performance comparison](reports/phase12_pipeline_performance_comparison.md) records the full pipelined CPU simulation, post-route timing, practical estimated MIPS and comparison against Phase 11E.
- [Phase 13A jump target request](reports/phase13a_jump_target_request.md) records the timing-safe fast JUMP target request variant, full regression, post-route timing and measured practical MIPS improvement.
- [Phase 13B BEQ target prefetch](reports/phase13b_beq_target_prefetch.md) records the dual-read instruction-memory branch-prefetch experiment, full regression, post-route timing and why it remains experimental rather than replacing Phase 13A.
- [Phase 13C timing closure](reports/phase13c_timing_closure.md) records the separate timing-optimised pipeline path, routed period sweep, critical-path shift and measured practical MIPS improvement to about 82.1 MIPS.
- [Phase 13D load-forwarding timing experiment](reports/phase13d_load_forwarding_timing.md) records the WB-to-ID bypass removal experiment and why it does not replace Phase 13C.
- [Phase 13E forwarding-path timing experiment](reports/phase13e_forwarding_timing.md) records the WB/load forwarding-path restructuring experiment, full regression, routed 8.900 ns implementation and measured practical MIPS improvement to about 83.9 MIPS.
- [Phase 13G registered target-buffer experiment](reports/phase13g_registered_target_buffer.md) records the timing-safe registered target-buffer experiment and why it does not replace Phase 13E.
- [Phase 13H preferred pipeline summary](reports/phase13h_preferred_pipeline_summary.md) records the final Phase 13E timing sweep, final practical MIPS result and supervisor-ready comparison of Phase 12 through Phase 13G.
- [Phase 13I implementation strategy sweep](reports/phase13i_strategy_sweep.md) records the fanout-focused Vivado strategy sweep that improves the preferred Phase 13E RTL to about 86.4 practical estimated MIPS.
- [Phase 14A deeper pipeline plan](reports/phase14a_deeper_pipeline_plan.md) proposes a future IF/ID/OP/EX/MEM/WB pipeline and defines the verification and timing criteria required before it could replace Phase 13I.
- [Phase 14B six-stage pipeline skeleton](reports/phase14b_pipeline6_skeleton.md) documents the separate IF/ID/OP/EX/MEM/WB skeleton, focused XSim result and current limitations.
- [Phase 14C six-stage pipeline arithmetic](reports/phase14c_pipeline6_arithmetic.md) documents arithmetic execution, x0 protection, simple forwarding and focused XSim verification for the separate Phase 14 pipeline path.
- [Phase 14D six-stage pipeline memory](reports/phase14d_pipeline6_memory.md) documents LOAD/STORE execution, synchronous data-memory timing, load-use stalls and focused XSim verification for the separate Phase 14 pipeline path.
- [Phase 14E six-stage pipeline control flow](reports/phase14e_pipeline6_control.md) documents BEQ/JUMP redirects, stale fetch-response invalidation, wrong-path protection and focused XSim verification for the separate Phase 14 pipeline path.
- [Phase 14F six-stage pipeline full verification](reports/phase14f_pipeline6_full_verification.md) documents full custom-ISA style program verification, final architectural checks and measured simulation CPI for the separate Phase 14 pipeline path.
- [Phase 14G six-stage pipeline timing comparison](reports/phase14g_pipeline6_timing.md) records the Basys 3 implementation sweep, best verified 6.000 ns period and measured practical estimated throughput of about 101.8 MIPS.
- [Phase 15A Basys 3 bring-up](reports/phase15a_basys3_bringup.md) documents the slow-enable FPGA wrapper, switch/LED mapping, bitstream path and board test procedure.
- [FPGA implementation plan](docs/fpga_implementation_plan.md) explains the Phase 3 FPGA wrapper, LED debug mapping and Vivado build scripts.
- [Phase 3 checklist](docs/phase3_checklist.md) tracks Phase 3A through Phase 3D status and evidence.
- [Supervisor Phase 3 summary](docs/supervisor_phase3_summary.md) summarises the pre-hardware FPGA work and remaining hardware validation.
- [Basys 3 bring-up checklist](docs/basys3_bringup_checklist.md) gives the step-by-step first-board programming and evidence checklist.
- [FPGA LED expected sequence](docs/fpga_led_expected_sequence.md) describes the expected Basys 3 LED pattern for the demo program before hardware testing.
- [Basys 3 XDC review](reports/basys3_xdc_review.md) reviews the current board constraints against the wrapper ports.
- [Phase 3 build reproducibility](reports/phase3_build_reproducibility.md) records the Vivado version, target, build commands and expected outputs.
- [Phase 3D hardware bring-up template](reports/phase3d_hardware_bringup_template.md) is the fill-in report for the first physical board session.
- [Vivado script review](reports/phase3_vivado_script_review.md) confirms the Phase 3 synthesis and implementation scripts are complete for pre-hardware use.
- [Verification notes](docs/verification.md) record XSim results and coverage points.

## How To Run Regression Tests

Open a Vivado-enabled PowerShell from the repository root and run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

The script runs the current Vivado XSim testbenches for the RTL modules and CPU integration programs. It is intended for local developer use; CI is not assumed yet.

## Phase 3 FPGA Implementation Preparation

Phase 3 prepares the CPU for the Digilent Basys 3 without changing CPU behaviour. Phase 3A covers the FPGA wrapper and constraints, Phase 3B covers slow LED-visible stepping and pre-hardware synthesis, Phase 3C covers routed implementation and bitstream generation, and Phase 3D is hardware bring-up, pending until the physical board arrives.

- `rtl/fpga_top.sv` instantiates `cpu_core` and maps PC, opcode, control and ALU debug signals onto `led[15:0]`.
- `programs/fpga_led_demo.mem` provides a small looping demo program for LED bring-up.
- `constraints/basys3.xdc` targets the Basys 3 100 MHz clock, one reset button, one enable switch and all 16 LEDs.
- `tb/fpga_top_tb.sv` checks that the wrapper exposes changing CPU debug state on the LEDs.
- `docs/basys3_bringup_checklist.md` provides the practical first-board programming and validation checklist.
- `scripts/run_vivado_synth.tcl` runs synthesis for `xc7a35tcpg236-1`.
- `scripts/run_vivado_impl.tcl` runs implementation and writes a bitstream only after the Basys 3 constraints are checked.
- `reports/phase3a_timing_analysis.md` records the baseline post-synthesis timing miss and critical-path analysis.
- `rtl/slow_tick_generator.sv` adds slow LED-visible CPU stepping while keeping the Basys 3 100 MHz clock as the only clock.
- `docs/fpga_led_expected_sequence.md` provides a pre-hardware LED checklist for the demo program.
- `reports/phase3b_slow_tick_synthesis_summary.md` records the slow-tick wrapper synthesis result.
- `reports/phase3c_implementation_summary.md` records the first routed implementation and bitstream-generation result.
- `reports/phase3_prehardware_validation.md` separates completed pre-board evidence from pending physical hardware validation.
- `docs/phase3_checklist.md` tracks completed pre-hardware tasks and Phase 3D hardware tasks that remain blocked until the board arrives.
- `reports/phase3_build_reproducibility.md` records the commands and generated outputs needed to reproduce the Phase 3 builds.

Hardware validation has not been completed yet. The board still needs to be programmed and observed before reset, enable switch and LED behaviour can be claimed on real hardware.

See [FPGA implementation plan](docs/fpga_implementation_plan.md) for the detailed Phase 3 checklist and acceptance criteria.

## Phase 5: Memory System and Program Execution

Phase 5 turns the integrated CPU work into a runnable processor system in simulation. It adds:

- `rtl/instr_mem.sv`: standalone 256-word instruction memory with byte addressing and `$readmemh` program loading.
- `rtl/data_mem.sv`: standalone 256-word data memory with synchronous writes and combinational reads.
- `rtl/cpu_top.sv`: runnable CPU system wrapper for program execution simulations.
- `programs/add_test.mem`: file-loaded custom-ISA test program.
- `tb/tb_instr_mem.sv`, `tb/tb_data_mem.sv` and `tb/tb_program_execution.sv`: self-checking Phase 5 testbenches.

The Phase 5 demo program is:

```text
ADDI  x1, x0, 5
ADDI  x2, x0, 7
ADD   x3, x1, x2
STORE x3, [x0 + 0]
NOP
```

Expected final result:

- `x1 = 5`
- `x2 = 7`
- `x3 = 12`
- data memory word 0 = `32'd12`

The design choice is intentionally conservative. `cpu_top.sv` wraps the existing integrated `cpu_core`; the existing core already contains the fetch, instruction-memory and data-memory path through the earlier `fetch_unit`, `instruction_memory` and `data_memory` modules. The new `instr_mem.sv` and `data_mem.sv` modules are standalone Phase 5 memory blocks tested independently. This documents and verifies the memory-system concepts without refactoring working CPU behaviour.

The Phase 5 XSim regression passed, and waveform evidence is saved under `docs/images/`:

- `docs/images/phase5_instr_mem_waveform.png`
- `docs/images/phase5_data_mem_waveform.png`
- `docs/images/phase5_program_execution_waveform.png`

## Phase 6: Expanded ISA Verification

Phase 6 extends program-level verification beyond the Phase 5 add/store demo. It keeps the existing custom ISA and CPU RTL unchanged, then runs a wider set of file-loaded programs through the same `cpu_top` execution path.

Completed Phase 6 tests:

- Phase 6A arithmetic edge program: ADDI, ADD, SUB, negative immediate sign extension and `x0` write protection.
- Phase 6B memory offset program: LOAD/STORE base-plus-offset addressing and negative offset load.
- Phase 6C branch control program: BEQ taken and BEQ not-taken behaviour.
- Phase 6D jump control program: unconditional JUMP skipping unwanted instructions.
- Phase 6E simple loop program: ADDI, ADD, SUB, BEQ, JUMP, STORE and NOP loop execution.
- Phase 6F invalid opcode safety program: invalid opcodes are marked invalid and do not write registers or data memory.

The full local Vivado XSim regression passes through Phase 6F. This is the frozen simulation baseline for starting Phase 7 FPGA implementation and timing-closure preparation.

See [Phase 6 plan](docs/phase6_plan.md) and [verification notes](docs/verification.md) for the tested programs, encoded instruction words, transcript paths and pass/fail results.

## Completed Modules And Next Work

Completed work:

- ALU
- Register file
- Program counter
- Instruction memory and data memory
- Fetch unit
- Instruction decoder and control unit
- Integrated CPU core with ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ and JUMP support
- File-loaded CPU test programs
- Basys 3 FPGA wrapper, constraints, synthesis, routed implementation and bitstream generation
- Phase 7C implementation and bitstream evidence for the frozen simulation baseline
- Phase 7D post-route timing analysis and critical-path investigation
- Phase 7E Basys 3 bring-up planning and evidence-capture template
- Phase 8A multi-cycle CPU redesign planning
- Phase 8B separate multi-cycle CPU FSM skeleton and focused FSM testbench
- Phase 8C arithmetic execution support and focused arithmetic testbench for the separate multi-cycle CPU
- Phase 8D LOAD/STORE memory execution support and focused memory testbench for the separate multi-cycle CPU
- Phase 8E BEQ/JUMP control-flow support and focused branch/jump testbench for the separate multi-cycle CPU
- Phase 8F full-program custom-ISA verification for the separate multi-cycle CPU
- Phase 8G separate multi-cycle FPGA top-level wrapper, Vivado build scripts, bitstream generation and timing comparison
- Phase 10A simulation-based multi-cycle CPU performance benchmarking
- Phase 10B architecture trade-off comparison between the original single-cycle-style and separate multi-cycle CPU paths
- Phase 10C standalone BRAM-style memory prototypes and tests
- Phase 10D BRAM integration planning for a future separate multi-cycle CPU path
- Phase 10F separate BRAM-aware multi-cycle CPU variant and focused basic test
- Phase 10G full custom-ISA verification for the separate BRAM-aware multi-cycle CPU variant
- Phase 10H separate BRAM-aware FPGA top-level wrapper, Vivado build scripts, synthesis, implementation and bitstream result
- Phase 11A separate BRAM-aware instruction prefetch CPU prototype and focused basic simulation
- Phase 11B full custom-ISA verification for the separate BRAM-aware instruction prefetch CPU prototype
- Phase 11C separate BRAM-aware prefetch FPGA top-level wrapper, Vivado build scripts, implementation and timing comparison
- Phase 11D separate control-flow-optimised prefetch CPU variant and simulation comparison
- Phase 11E separate control-flow-optimised prefetch FPGA top-level wrapper, Vivado build scripts, implementation and timing comparison
- Phase 12A pipelined CPU architecture planning
- Phase 12B separate pipelined CPU skeleton and focused XSim test
- Phase 12 full separate pipelined CPU custom-ISA verification, Basys 3 implementation, timing result and performance comparison
- Phase 13A separate jumpfast pipeline variant, full regression, Basys 3 implementation and performance comparison
- Phase 13B separate BEQ target-prefetch pipeline experiment, full regression, Basys 3 implementation and trade-off comparison
- Phase 13C separate timing-optimised pipeline path, full regression, Basys 3 implementation, routed period sweep and timing-closure comparison
- Phase 13D separate load-forwarding timing experiment, full regression and Basys 3 implementation comparison
- Phase 13E separate forwarding-path timing experiment, full regression, Basys 3 implementation and updated preferred measured pipeline comparison
- Phase 13G separate registered target-buffer experiment, focused simulation, Basys 3 implementation and neutral comparison against Phase 13E
- Phase 13H preferred pipeline consolidation, full regression rerun and final Phase 13E timing sweep
- Phase 13I Vivado implementation strategy sweep for the unchanged preferred Phase 13E RTL
- Phase 14A deeper pipeline architecture plan
- Phase 14B separate six-stage pipeline skeleton and focused XSim verification
- Phase 14C arithmetic execution and focused XSim verification for the separate six-stage pipeline path
- Phase 14D LOAD/STORE execution, load-use hazard handling and focused XSim verification for the separate six-stage pipeline path
- Phase 14E BEQ/JUMP redirects, wrong-path protection and focused XSim verification for the separate six-stage pipeline path
- Phase 14F full custom-ISA style program verification and CPI measurement for the separate six-stage pipeline path
- Phase 14G Vivado implementation, timing sweep and practical MIPS comparison for the separate six-stage pipeline path
- Phase 15A slow-enable Basys 3 bring-up wrapper and bitstream for visible LED stepping
- Phase 5 memory system
- CPU top-level program execution wrapper
- File-loaded Phase 5 program execution test
- Phase 5 waveform evidence
- Phase 6 expanded custom-ISA program-level verification through Phase 6F
- Frozen simulation baseline ready for Phase 7 FPGA implementation work

Next planned work:

- Physical Basys 3 programming and evidence capture
- Reset, enable switch and LED sequence validation on the real board
- Phase 15B physical Basys 3 evidence capture for the Phase 15A slow-enable bitstream
- Supervisor-facing conclusion on the Phase 14G/15A six-stage pipeline result
- Supervisor review of whether the Phase 8 multi-cycle FPGA path should become the preferred implementation path

## Repository Structure

- `rtl/` - synthesizable SystemVerilog RTL modules.
- `tb/` - self-checking SystemVerilog testbenches.
- `docs/` - project notes, setup notes, verification logs and planning documents.
- `docs/images/` - screenshots and waveform images used by the documentation.
- `constraints/` - FPGA board constraint files.
- `programs/` - CPU test programs.
- `reports/` - timing, utilisation and power reports.
- `scripts/` - helper scripts for simulation, synthesis or report generation.
- `vivado/` - Vivado project files. Generated Vivado outputs should not be committed.

## Tools

- Vivado 2026.1
- Vivado Basic licence
- Vivado XSim for simulation
- SystemVerilog for RTL and testbenches
- Git and GitHub for version control
- Codex CLI and ChatGPT for assisted development and documentation

## Verification Approach

Each RTL block should have a matching self-checking testbench. Simulation results, major test coverage points and waveform notes should be recorded in `docs/verification.md`.

Generated files such as `.vcd`, `.wdb`, `.sim`, `.cache`, `obj_dir/` and executables should be ignored and not committed.
