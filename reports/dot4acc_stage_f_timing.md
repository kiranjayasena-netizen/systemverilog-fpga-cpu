# DOT4ACC Stage F Post-Route Timing Characterisation

Date: 7 August 2026

## Result

The fixed Stage D/E DOT4ACC CPU does **not** close setup timing at the intended
100 MHz under the established default Vivado flow. Five fresh 100 MHz
implementations each reported `-0.348 ns` WNS. Hold and pulse-width timing pass.

The defensible default-flow boundary is:

- highest repeatable passing frequency: **98 MHz**, 5/5 passes;
- immediately higher repeatable failing frequency: **99 MHz**, 5/5 fails;
- best isolated passing frequency: **98 MHz**;
- conservative validated operating frequency: **98 MHz**.

This is post-route implementation evidence for a Basys 3
`xc7a35tcpg236-1`; it is not board-frequency or board-throughput measurement.
No CPU or arithmetic RTL was changed to obtain these results.

## DUT and controls

- CPU: unchanged `rtl/cpu_core_pipeline_dot4acc_wb.sv`.
- DOT arithmetic: unchanged `rtl/dot4acc_pipeline.sv`.
- Implementation top: `fpga_top_pipeline_dot4acc_wb`.
- Board part: `xc7a35tcpg236-1`.
- Tool: AMD Vivado 2026.1.
- Board constraints: `constraints/basys3.xdc`; physical clock input W5.
- Clock name: `sys_clk_pin`.
- Period: generated as `1000 / frequency_MHz`, with a 50% waveform, in an
  isolated per-run override XDC.
- Program image: `programs/dot4acc_stage_d.mem`.
- Each result is a new batch Vivado process and a separate implementation
  directory. No routed checkpoint is reused between repetitions.
- Repetition identifiers are not placement seeds. This default flow is
  deterministic, so repeatability means reproducibility across clean fresh
  processes, consistent with the historical MAC8 boundary method.

The dedicated FPGA wrapper changes no core behavior. It preserves the existing
Basys timing-wrapper reset, enable, and LED observation convention and exists
only because historical wrappers intentionally instantiate historical cores.

## Default Vivado flow

The primary sweep uses one fixed methodology at every frequency:

```text
read_verilog -sv
read_xdc constraints/basys3.xdc
read_xdc <per-run clock override>
synth_design -top fpga_top_pipeline_dot4acc_wb -part xc7a35tcpg236-1
opt_design
place_design
route_design
update_timing
write_bitstream
```

All commands use their `Default` directives. `phys_opt_design` is not run,
matching the published default MAC8 boundary flow. No special-directive rescue
experiment was performed.

The reusable flow is in
`scripts/run_vivado_impl_dot4acc_stage_f.tcl`; orchestration and CSV
consolidation are in `scripts/run_vivado_dot4acc_stage_f_sweep.ps1`; routed
checkpoint inspection is in `scripts/report_dot4acc_post_route_details.tcl`.
Generated projects, logs, journals, checkpoints, and bitstreams remain below
the ignored `reports/dot4acc_stage_f/runs/` tree.

## Timing definitions

A run passes only when routing and bitstream generation succeed, setup WNS and
hold WNS are nonnegative, pulse-width WNS is nonnegative, and all three failing
endpoint counts are zero. TNS and endpoint counts are retained even though WNS
alone is enough to locate the boundary.

## 100 MHz result and repeatability

| Run | Period | WNS | TNS | Setup endpoints | Hold WNS | Pulse WNS | Overall |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| 1 | 10.000 ns | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | FAIL |
| 2 | 10.000 ns | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | FAIL |
| 3 | 10.000 ns | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | FAIL |
| 4 | 10.000 ns | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | FAIL |
| 5 | 10.000 ns | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | FAIL |

Thus 100 MHz is a repeatable setup failure, not a marginal or mixed result.
Hold and pulse-width timing pass in every run.

## Bounded sweep and narrowed boundary

The prescribed ascending coarse sweep was stopped after the mandatory 100 MHz
proof failed. Running 102--110 MHz could not establish the lower pass boundary
and would add no acceptance evidence. The bounded search therefore moved down
to 98 MHz, then tested the intervening 99 MHz point. Both boundary candidates
were repeated five times.

| Frequency | Period | Runs passing | WNS | TNS | Setup endpoints | Hold WNS | Pulse WNS | Overall |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| 98 MHz | 10.204 ns | 5/5 | +0.341 ns | 0.000 ns | 0 | +0.129 ns | +4.602 ns | PASS |
| 99 MHz | 10.101 ns | 0/5 | -0.274 ns | -11.476 ns | 109 | +0.037 ns | +4.550 ns | FAIL |
| 100 MHz | 10.000 ns | 0/5 | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | FAIL |

The non-monotonic TNS and endpoint count are normal placement/routing effects;
the pass/fail decision uses the implemented timing at each exact constraint.
All 15 runs fully routed, passed hold and pulse-width checks, and generated a
bitstream. Results were identical across the five deterministic repetitions at
each frequency.

## Critical setup paths

| Frequency | Startpoint | Endpoint | Data delay | Logic / route | Levels | WNS | Category |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- |
| 98 MHz | data BRAM `CLKARDCLK` | `dot_chain_rd_reg[0]/R` | 9.296 ns | 4.261 / 5.035 ns | 9 | +0.341 ns | LOAD writeback/forwarding, BEQ/redirect cancellation, DOT chain-state reset |
| 99 MHz | `id_ex.rs2[2]` | `fetch_pc[5]/CE` | 10.097 ns | 2.563 / 7.534 ns | 12 | -0.274 ns | DOT dependency plus branch/redirect and frontend enable control |
| 100 MHz | data BRAM `CLKARDCLK` | `dot_chain_open_reg/R` | 9.776 ns | 4.289 / 5.487 ns | 9 | -0.348 ns | LOAD writeback/forwarding, BEQ/redirect cancellation, DOT chain-state reset |

Clock uncertainty is 0.035 ns for each listed path. The 98 and 100 MHz routes
start at the data BRAM output, pass through LOAD writeback/operand forwarding,
the BEQ comparison carry chain and redirect/cancellation logic, and terminate
on DOT chain-control reset pins. The 99 MHz route starts in ID/EX dependency
metadata, crosses dependency/branch/redirect control, and terminates on the
frontend PC clock enable. The detailed pin, cell, net, and placement reports
under `reports/dot4acc_stage_f/details/` support these classifications; names
under an absorbed hierarchy were not treated as proof by themselves.

The four-DSP DOT arithmetic is not on any absolute worst path. The worst path
through a DOT DSP has +0.726 ns slack at 98 MHz, +0.647 ns at 99 MHz, and
+0.693 ns at 100 MHz. DOT writeback result data is also absent from the worst
paths. DOT-specific chain/cancellation control does appear at the 98 and
100 MHz endpoints. At 99 MHz, the existing MAC8 DSP path also fails at
`-0.256 ns`, close behind the `-0.274 ns` absolute control-path failure.

## Critical hold paths

| Frequency | Startpoint | Endpoint | Hold slack | Category |
| ---: | --- | --- | ---: | --- |
| 98 MHz | `ex_mem.store_data[2]` | data BRAM `DIADI[2]` | +0.129 ns | STORE data into BRAM |
| 99 MHz | `ex_mem.store_data[23]` | data BRAM `DIBDI[5]` | +0.037 ns | STORE data into BRAM |
| 100 MHz | `ex_mem.store_data[23]` | data BRAM `DIBDI[5]` | +0.058 ns | STORE data into BRAM |

There are zero failing hold endpoints and zero hold TNS at every tested point.

## DSP implementation

Every inspected routed design contains five DSP48E1 blocks: one existing MAC8
DSP and four DOT DSPs. All four DOT DSPs retain `AREG=1` and `BREG=1`, confirming
that forwarding/control terminates at registered DSP inputs. The inferred
reduction maps into two pair DSP cells and two product DSP cells. Pair cells use
`MREG=1`, `PREG=1`; product cells use `MREG=0`, `PREG=1`.

| Frequency | MAC8 site | DOT sites |
| ---: | --- | --- |
| 98 MHz | `DSP48_X0Y6` | `DSP48_X0Y10`, `X0Y8`, `X0Y9`, `X0Y7` |
| 99 MHz | `DSP48_X0Y6` | `DSP48_X0Y8`, `X0Y5`, `X0Y7`, `X0Y4` |
| 100 MHz | `DSP48_X0Y8` | `DSP48_X0Y10`, `X0Y12`, `X0Y9`, `X0Y11` |

These sites describe the observed routes only; they are not placement
constraints or a claim of optimal placement.

## Routed resources

| Resource | Historical MAC8 | Stage D exposed-core synthesis | Stage F routed at 98 MHz |
| --- | ---: | ---: | ---: |
| Slice LUTs | 1,457 | 2,162 | 1,810 |
| Slice FFs | 1,507 | 2,471 | 1,705 |
| RAMB18E1 | 2 halves / 1 tile | 2 | 2 |
| RAMB36E1 | 0 | not reported | 0 |
| DSP48E1 | 1 | 5 | 5 |
| BUFG | not reported | not reported | 1 |
| Latches | 0 | 0 | 0 |

The routed wrapper exposes only board-visible state, so Vivado removes
verification-only observation/counter logic that was retained by exposed-core
synthesis. This accounts for much of the LUT/FF reduction. Small routed LUT
changes with constraint (1,810 at 98, 1,814 at 99, and 1,816 at 100 MHz) are
constraint-driven synthesis/implementation variation. BRAM and DSP counts are
stable.

## Constraints and warnings

- One `sys_clk_pin` clock is present and the applied period matches each run.
- `check_timing` reports zero no-clock pins, zero unconstrained internal
  endpoints, zero multiple-clock pins, zero generated-clock problems, zero
  combinational loops, and zero latch loops.
- The only missing I/O delays are two asynchronous board controls (`rst_btn`,
  `enable_sw`) and 16 LED outputs. They do not leave internal core paths
  unconstrained, but external I/O timing is outside this CPU Fmax claim.
- `report_methodology` records two `SYNTH-6` BRAM output-register warnings,
  18 `TIMING-18` board-I/O delay warnings, and one each of `XDCC-4` and
  `XDCC-8` because the sweep intentionally overrides the board XDC clock with
  the same name and source.
- The ordinary synthesis warnings include the established unused low BRAM
  word-address bits. No warning was silently treated as an implementation
  failure.
- Each recorded run has zero errors and zero critical warnings. Post-route DRC
  reports no related violations.

## Comparison with historical MAC8 timing

| Design | Highest repeatable pass | First repeatable fail | Near-boundary limiter | LUT / FF / DSP / BRAM context |
| --- | ---: | ---: | --- | --- |
| MAC8 timing-optimised | 104 MHz, 5/5 | 105 MHz, 5/5 | 104: BRAM/LOAD forwarding/BEQ/redirect; 105: MAC8 DSP path | 1,457 / 1,507 / 1 / 1 tile |
| DOT Stage D/E | 98 MHz, 5/5 | 99 MHz, 5/5 | chain/dependency plus branch/redirect/frontend control; MAC8 DSP also fails at 99 | 1,810 / 1,705 / 5 / 1 tile routed |

The repeatable DOT boundary is 6 MHz (5.77%) below the historical MAC8 pass
point. Path evidence does not support blaming the four-DSP DOT arithmetic: its
registered paths have positive margin at all three inspected frequencies.
Additional DOT chain/dependency/cancellation control and the inherited MAC8
path are the observed timing pressures.

## Frequency-scaled Stage E throughput estimates

Stage E cycle counts remain architectural simulation measurements. Scaling its
measured MACs/cycle by the 98 MHz repeatable post-route frequency gives:

| Benchmark | Stage E cycles | MACs/cycle | Derived throughput at 98 MHz |
| --- | ---: | ---: | ---: |
| N=64 neuron | 27 | 2.37037 | 232.30 MMAC/s |
| N=128 register-resident dot | 43 | 2.97674 | 291.72 MMAC/s |

These are **frequency-scaled throughput estimates using measured architectural
MACs/cycle and repeatable post-route Fmax**. They are not measured board
throughput.

## Functional preservation

Stage F introduces no CPU/DOT RTL changes. The pre-change Stage D focused test
passed 3,945 checks, Stage E passed 233 checks and produced 48 rows, and the
complete XSim regression passed. Post-change functional and publication results
are recorded in `docs/verification.md`; architectural cycle counts are
unchanged.

## Limitations and operating recommendation

- The flow is deterministic; repeat runs test clean-process reproducibility,
  not random-seed yield.
- Only the fixed default flow was used. No directive search or RTL change was
  attempted.
- Internal CPU timing is characterized; asynchronous input/output interface
  delays are intentionally not a board-I/O timing claim.
- Hardware behavior, board temperature/voltage margin, power, and board
  throughput were not measured.

The intended 100 MHz point is not timing-valid under this flow. Use **98 MHz as
the highest conservative validated operating frequency** for this exact DUT
and methodology. A lower guard-banded deployment clock may be chosen by a
board-validation stage, but no untested lower value is labelled validated here.

## Exact next-stage recommendation

The next stage should be a timing-focused architectural study, not immediate
memory-feed optimization. It should isolate and shorten the measured DOT
chain/dependency plus branch/redirect cancellation paths and the inherited
MAC8 DSP path, then re-prove functional behavior and repeatable 100 MHz closure.
Only after 100 MHz timing is recovered should a separate architecture stage act
on Stage E's memory-feed, LOAD-to-DOT scheduling, and conservative-hold
bottlenecks.

