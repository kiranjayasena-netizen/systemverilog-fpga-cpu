# Timing-Optimised MAC8 Post-Route Boundary Sweep

- Date: 6 August 2026
- Tool: AMD Vivado 2026.1
- Part: `xc7a35tcpg236-1` (Digilent Basys 3)
- Clock: `sys_clk_pin`

## Outcome

The default implementation flow passes 104 MHz in five of five fresh,
deterministic executions and fails 105 MHz in five of five. All ten boundary
runs routed fully, passed hold timing and generated bitstreams. The repeatable
post-route boundary for this exact flow is therefore:

```text
104 MHz passes repeatably; 105 MHz fails consistently
```

The highest observed pass is 105 MHz, but only in two single-run controlled
directive variations. `place_design -directive ExtraNetDelay_high` passed at
`+0.034 ns`; `route_design -directive AggressiveExplore` passed at
`+0.106 ns`. These intentionally varied results are exploratory and are not
part of the deterministic repeatability claim.

The recommended conservative operating frequency remains 100 MHz. Its prior
repeatable default-flow evidence has `+0.198 ns` WNS, whereas the highest
repeatable point, 104 MHz, has only `+0.062 ns`. The latter is below the
approximately `0.1 ns` margin threshold for treating a larger single-cycle
packed datapath as low risk.

No CPU RTL, ISA, pipeline stage, hazard rule or cycle behavior changed during
this characterization.

## Exact flow

- top: `fpga_top_pipeline_mac8_timingopt`;
- sources: `rtl/cpu_defs_pkg.sv`, `rtl/bram_instr_mem.sv`,
  `rtl/bram_data_mem.sv`, `rtl/cpu_core_pipeline_mac8_timingopt.sv`, and
  `rtl/fpga_top_pipeline_mac8_timingopt.sv`;
- program image: `programs/ai_dot_product_mac.mem`;
- part: `xc7a35tcpg236-1`;
- board constraints: `constraints/basys3.xdc`;
- clock override: `create_clock -name sys_clk_pin -period 1000/frequency`
  with a 50% waveform;
- synthesis: `synth_design` default strategy;
- optimization: `opt_design` default strategy;
- placement: `place_design` default strategy;
- routing: `route_design` default strategy;
- no `phys_opt_design` in the repeatability flow;
- authoritative reports: post-route timing summary, 25
  full-clock-expanded setup paths with pins/nets, 10 hold paths, route status,
  utilization and the extracted worst-path objects;
- a bitstream is attempted after every fully routed implementation, including
  setup-failing runs.

Each run uses a fresh Vivado process and a separate output directory. No
checkpoint is reused. Repetition numbers are deterministic execution labels,
not placement seeds; every row records `seed_applied=false`. The controller
updates `reports/ai_mac8_boundary_sweep/results.csv` after every run and can
resume completed routed identifiers with `-Resume`.

## Default-flow results

The initial grid tested 104, 105, 106, 107 and 108 MHz. Because 108 MHz
failed, 109 and 110 MHz were not run. Because 104 MHz passed, the 100/102 MHz
diagnostic fallback was not needed.

| Frequency | Runs | Pass/fail | Min WNS | Max WNS | Mean WNS | Range | Sample std. dev. | Worst data delay |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 104 MHz | 5 | 5 / 0 | +0.062 ns | +0.062 ns | +0.062 ns | 0.000 ns | 0.000 ns | 9.559 ns |
| 105 MHz | 5 | 0 / 5 | -0.148 ns | -0.148 ns | -0.148 ns | 0.000 ns | 0.000 ns | 9.583 ns |
| 106 MHz | 1 | 0 / 1 | -0.081 ns | -0.081 ns | -0.081 ns | n/a | n/a | 9.294 ns |
| 107 MHz | 1 | 0 / 1 | -0.379 ns | -0.379 ns | -0.379 ns | n/a | n/a | 9.644 ns |
| 108 MHz | 1 | 0 / 1 | -0.416 ns | -0.416 ns | -0.416 ns | n/a | n/a | 9.029 ns |

All default-flow runs passed hold timing, had zero hold failing endpoints,
routed successfully and generated bitstreams. At 104 MHz, each passing route
has a slack-derived estimated Fmax of `104.679 MHz`. This is a calculation
from the routed period and WNS, not a directly tested operating point.

| Frequency | Setup TNS | Setup endpoints | Hold WNS | LUT / FF / DSP / BRAM |
| ---: | ---: | ---: | ---: | --- |
| 104 MHz | 0.000 ns | 0 | +0.055 ns | 1,457 / 1,507 / 1 / 1 |
| 105 MHz | -0.640 ns | 12 | +0.139 ns | 1,457 / 1,507 / 1 / 1 |
| 106 MHz | -0.815 ns | 13 | +0.033 ns | 1,457 / 1,507 / 1 / 1 |
| 107 MHz | -15.682 ns | 155 | +0.034 ns | 1,457 / 1,507 / 1 / 1 |
| 108 MHz | -20.318 ns | 104 | +0.035 ns | 1,456 / 1,507 / 1 / 1 |

Small LUT-count changes across targets are constraint-driven synthesis and
implementation variation. Every run retains exactly one DSP48E1 and one BRAM
tile.

## Controlled directive study

These runs use identical RTL, part, clock and report commands. Each varies
exactly one documented implementation directive at 105 MHz and is deliberately
kept separate from the default repeatability set.

| Strategy | Changed command | Setup WNS | Hold WNS | Setup endpoints | Worst path | Result |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Placement variation | `place_design -directive ExtraNetDelay_high` | +0.034 ns | +0.057 ns | 0 | BRAM/writeback/forwarding/DSP to EX/MEM | observed pass |
| Routing variation | `route_design -directive AggressiveExplore` | +0.106 ns | +0.139 ns | 0 | BRAM/writeback/branch control to ID/EX reset | observed pass |

The placement result has a calculated Fmax of `105.374 MHz`; the routing
result calculates to `106.180 MHz`. Neither value is a tested operating point,
and neither single-run strategy result establishes repeatability.

## Post-route critical paths

### 104 MHz: repeatable-pass limiter

All five 104 MHz runs have the same worst path, WNS and placement. The path is
frontend/control related but is not the removed invalid-payload reset path:

- startpoint: `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK` at
  `RAMB18_X0Y4`;
- endpoint: `cpu_inst/redirect_pending_target_reg[30]/D`;
- data delay: `9.559 ns` = `5.574 ns` logic + `3.985 ns` routing;
- 16 levels: one LUT3 writeback mux, one LUT5 forwarding mux, one LUT6 and
  three CARRY4 levels for BEQ, one LUT4 redirect term, one LUT5 target term,
  then eight CARRY4 levels for the redirect-target addition;
- important nets: `wb_write_data[4]` with fanout 38,
  `ex_branch_taken046_in` with fanout 17, and
  `redirect_pending_target[31]_i_3_n_0` with fanout 34.

This path is data BRAM -> LOAD writeback -> MEM/WB-to-EX forwarding -> BEQ
comparison -> redirect control -> redirect-target addition. It does not pass
through the DSP48E1.

### 105 MHz: first consistent-fail limiter

All five default 105 MHz runs have the same worst path and `-0.148 ns` WNS:

- startpoint: `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK` at
  `RAMB18_X0Y2`;
- endpoint: `cpu_inst/ex_mem_reg_reg[alu_result][25]/D`;
- data delay: `9.583 ns` = `6.667 ns` logic + `2.916 ns` routing;
- four levels: LUT3 writeback mux -> LUT5 rs1 forwarding mux -> DSP48E1 ->
  LUT6 result select;
- important nets: `wb_write_data[7]` with fanout 38 and
  `ex_operand_a[7]` with fanout 31;
- DSP cell: `cpu_inst/ex_alu_result0`, placed at `DSP48_X0Y4`.

The next failing path family at 105 MHz is still frontend-related: data BRAM
through writeback, forwarding, BEQ comparison and control to ID/EX reset
endpoints at `-0.069 ns`. The boundary therefore has two genuine bottlenecks,
not one path that can be hidden with a constraint.

### Higher-frequency path changes

The absolute limiter is not identical at every constraint:

- 106 MHz: BRAM/writeback/BEQ/redirect to
  `fetch_buffer_instruction_reg[27]/CE`, `-0.081 ns`;
- 107 MHz: BRAM/writeback/forwarding/DSP to
  `ex_mem_reg_reg[alu_result][3]/D`, `-0.379 ns`;
- 108 MHz: BRAM/writeback/BEQ/control to
  `id_ex_reg_reg[operand_a][13]/R`, `-0.416 ns`.

The valid-only change successfully removed the original critical endpoint,
`fetch_buffer_instruction_reg[15]/R`, which was driven by dynamic payload
clearing in the baseline. The previous optimized 104 and 106 MHz critical
paths are reproduced unchanged. The new 105 MHz point resolves the actual
boundary and shows that the unregistered MAC/DSP path becomes dominant there.

## Retained-invalid-payload safety review

The optimized core retains invalid IF/ID and fetch-buffer payload values, but
every architectural effect remains validity-gated:

- register writes and writeback forwarding producers require
  `mem_wb_reg.valid`;
- memory reads/writes require `ex_mem_reg.valid`;
- retirement and retired-instruction counting require `mem_wb_reg.valid`;
- EX branch/jump redirects require `id_ex_reg.valid`, while the fast ID jump
  requires `if_id_reg.valid` and a valid opcode;
- load-use and accumulator hazards require valid IF/ID and ID/EX entries;
- EX/MEM and MEM/WB forwarding producers require their matching valid bits;
- branch, jump, hazard, flush and retirement counters increment only from the
  corresponding valid-gated event;
- invalid IF/ID contents cannot enter ID/EX because decode admission requires
  `if_id_reg.valid && if_id_opcode_valid`.

The existing Phase 12 suite checks wrong-path retirement, wrong-path stores,
invalid opcodes, register/memory write unknowns, `x0`, branch/jump behavior,
load-use hazards and all performance totals. Additional assertions were not
added because the gates are explicit and the existing 2,793-check contract
already exercises these effects without changing its count.

## Functional verification

Before the sweep, the timing-optimized core passed:

- focused MAC8: 83 checks, zero failures, dot products `0xfffffff2`, and
  baseline/MAC8 cycle counts 29/19;
- Phase 12 full regression: 2,793 checks, zero failures, 457 aggregate cycles
  and 319 retired instructions.

After the sweep, the focused MAC8 test again passed 83 checks with zero
failures and the Phase 12 test again passed 2,793 checks with zero failures.
The dot product remained `0xfffffff2`; aggregate totals remained 457 cycles
and 319 retired instructions. The complete repository XSim regression then
completed with exit code 0. The sweep changes only scripts, ignored generated
runs and evidence files.

## DOT4ACC implication and decision

The core has enough evidence to begin architecture planning, but not enough
margin to justify a single-cycle combinational DOT4ACC. At 104 MHz the worst
repeatable WNS is only `+0.062 ns`, and at 105 MHz the current single-lane
MAC8 DSP path already fails. Four products plus an adder tree on that same EX
path would directly worsen a demonstrated boundary limiter.

The only next-step recommendation is: **plan a pipelined DOT4ACC
implementation**. The planning must isolate or register the packed
multiply/adder tree so it does not extend the current BRAM/writeback/
forwarding-to-DSP path. No DOT4ACC RTL or architectural change is part of this
characterization.

## Remaining risks

- The five-run sets demonstrate exact-flow determinism, not placement-seed
  variability; Vivado exposes no supported seed in this flow.
- Both 105 MHz directive variations passed only once and require their own
  repeatability study before either could become a preferred implementation
  strategy.
- The conservative 100 MHz recommendation relies on the already preserved
  repeatable `+0.198 ns` evidence rather than rerunning 100 MHz in this focused
  sweep, because the required 104 MHz point did not fail.
- Multiple near-critical families remain: frontend/branch control,
  high-fanout writeback/forwarding, and the unregistered DSP path.
- Retained invalid payloads remain safe only while every consumer preserves
  the current valid-bit discipline.

Compact per-run data is in `ai_mac8_boundary_sweep/results.csv`; detailed
checkpoints, bitstreams, journals, logs and reports remain under the ignored
`ai_mac8_boundary_sweep/runs/` tree.
