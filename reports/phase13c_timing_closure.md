# Phase 13C Timing Closure

## Purpose

Phase 13C investigates post-route timing closure for the fastest verified pipelined CPU path. The goal is to improve practical estimated MIPS by increasing routed clock frequency while preserving the verified instruction count, CPI and architectural behaviour.

The performance metric is:

```text
Practical estimated MIPS = post-route Fmax in MHz / measured aggregate CPI
```

## Local Implementations Inspected

| Implementation | Simulation evidence | Post-route evidence | Aggregate CPI | Post-route Fmax | Practical MIPS | Notes |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Phase 12 pipeline | Passed | Passed | 1.433 | ~101.9 MHz | ~71.1 | First full pipelined CPU path. |
| Phase 13A jumpfast | Passed | Passed | 1.339 | ~101.9 MHz | ~76.1 | Best verified starting point before Phase 13C. |
| Phase 13B BEQ target prefetch | Passed | Passed | 1.329 | ~100.1 MHz | ~75.3 | Better CPI, but lower Fmax and higher BRAM use. |

Phase 13A was selected as the Phase 13C baseline because it had the highest verified practical estimated MIPS before this phase.

## Phase 13A Baseline

| Metric | Phase 13A |
| --- | ---: |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Post-route WNS at 10.000 ns | +0.182 ns |
| Post-route TNS | 0.000 ns |
| Estimated Fmax | ~101.9 MHz |
| Practical estimated MIPS | ~76.1 |
| LUTs | 1,233 |
| FFs | 1,507 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |

Baseline top setup paths were dominated by paths from the data BRAM clocked memory output to frontend PC/fetch-buffer registers. The worst path was:

```text
Source:      cpu_inst/data_mem_inst/mem_reg/CLKBWRCLK
Destination: cpu_inst/if_id_reg_reg[pc][14]/R
Slack:       +0.182 ns at 10.000 ns
Data delay:  9.170 ns
Logic delay: 3.993 ns
Route delay: 5.177 ns
Logic levels: 8
```

The top ten baseline setup paths had a common pattern: data-memory and pipeline control influenced wide frontend invalidation/reset paths, especially IF/ID PC and fetch-buffer PC registers. Route delay was slightly larger than logic delay, suggesting high-fanout control and reset/flush muxing were part of the timing cost.

## Optimisation Hypotheses

The timing reports supported these small RTL experiments:

1. Reduce dynamic reset/flush muxing on wide frontend data registers.
2. Keep invalid frontend entries as bubbles by clearing valid bits rather than clearing all wide data fields.
3. Reduce dynamic clearing of wide ID/EX data fields when a bubble is inserted.

These changes preserve correctness because all architectural side effects are already gated by pipeline valid bits and control bits.

## Accepted RTL Changes

Phase 13C adds a separate implementation path:

- `rtl/cpu_core_pipeline_timingopt.sv`
- `rtl/fpga_top_pipeline_timingopt.sv`
- `tb/tb_cpu_core_pipeline_timingopt.sv`
- `scripts/run_vivado_synth_pipeline_timingopt.tcl`
- `scripts/run_vivado_impl_pipeline_timingopt.tcl`
- `scripts/run_vivado_fmax_sweep_pipeline_timingopt.tcl`

The Phase 13A and Phase 13B paths remain unchanged.

Two RTL optimisations were accepted:

| Optimisation | Behaviour impact | Verification | Timing result |
| --- | --- | --- | --- |
| Frontend valid-only dynamic bubbles | No CPI or architectural change | Focused and full regression passed | WNS improved to +0.219 ns at 10.000 ns |
| ID/EX bubble task clears valid/control only | No CPI or architectural change | Focused and full regression passed | WNS improved to +0.759 ns at 10.000 ns |

Reset still initializes wide pipeline data fields. Dynamic bubbles clear valid and side-effect control state, while stale data fields are ignored when valid is low.

No instruction encoding, ISA behaviour, benchmark boundary or CPU architectural rule was changed.

## Simulation Result

Final full regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase13c_final_xsim_regression_20260712_140137.txt`

Phase 13C focused benchmark result:

| Metric | Value |
| --- | ---: |
| Tests run | 3,232 |
| Tests failed | 0 |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Aggregate MIPS at 100 MHz | 74.707 |

The full local XSim regression completed successfully. A known `xelab` object-directory cleanup warning appeared after successful snapshot builds; `xsim` still ran and the self-checking tests passed.

## Implementation Result at 10.000 ns

Command:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_timingopt.tcl
```

Result:

| Metric | Phase 13C at 10.000 ns |
| --- | ---: |
| WNS | +0.759 ns |
| TNS | 0.000 ns |
| WHS | +0.037 ns |
| THS | 0.000 ns |
| LUTs | 1,217 |
| FFs | 1,503 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Power | 0.091 W |
| Bitstream | Passed |

Worst setup path at 10.000 ns:

```text
Source:      cpu_inst/data_mem_inst/mem_reg/CLKARDCLK
Destination: cpu_inst/id_ex_reg_reg[operand_a][25]/R
Data delay:  8.605 ns
Logic delay: 4.212 ns
Route delay: 4.393 ns
Logic levels: 8
```

The critical path moved away from the Phase 13A frontend PC path and toward data-memory output / operand forwarding / ID/EX operand capture logic.

## Clock-Period Sweep

The sweep script runs separate implementation attempts under `reports/phase13c_timing/sweep/` using generated per-period XDC files. The original Basys 3 constraints are not modified.

| Period | Requested Freq. | WNS | TNS | WHS | THS | Setup status |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 9.500 ns | 105.263 MHz | +0.199 ns | 0.000 ns | +0.035 ns | 0.000 ns | Passed |
| 9.250 ns | 108.108 MHz | +0.009 ns | 0.000 ns | +0.091 ns | 0.000 ns | Passed |
| 9.240 ns | 108.225 MHz | +0.259 ns | 0.000 ns | +0.057 ns | 0.000 ns | Passed |
| 9.100 ns | 109.890 MHz | -0.194 ns | -3.157 ns | +0.059 ns | 0.000 ns | Failed setup |
| 9.000 ns | 111.111 MHz | -0.175 ns | -1.574 ns | +0.034 ns | 0.000 ns | Failed setup |

The tightest verified passing period tested was 9.240 ns, so Phase 13C uses 108.225 MHz as the measured post-route Fmax evidence.

At 9.240 ns:

| Metric | Value |
| --- | ---: |
| LUTs | 1,239 / 20,800, 5.96% |
| FFs | 1,503 / 41,600, 3.61% |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total power | 0.093 W |
| Power confidence | Medium |
| Bitstream | Passed |

Worst path at 9.240 ns:

```text
Source:      cpu_inst/data_mem_inst/mem_reg/CLKARDCLK
Destination: cpu_inst/id_ex_reg_reg[operand_b][23]/R
Slack:       +0.259 ns
Data delay:  8.338 ns
Logic delay: 4.003 ns
Route delay: 4.335 ns
Logic levels: 8
```

The top paths at the tightest passing period are mostly variants of the same path family:

- data BRAM output to `id_ex_reg.operand_a`;
- data BRAM output to `id_ex_reg.operand_b`;
- data BRAM output through frontend/fetch-buffer clock-enable control;
- roughly balanced logic and route delay;
- no loss of BRAM inference.

## Performance Calculation

| Metric | Phase 13A | Phase 13C |
| --- | ---: | ---: |
| Aggregate cycles | 427 | 427 |
| Retired instructions | 319 | 319 |
| Aggregate CPI | 1.339 | 1.339 |
| Verified post-route Fmax | ~101.9 MHz | 108.225 MHz |
| Practical estimated MIPS | ~76.1 | ~80.8 |
| LUTs | 1,233 | 1,239 |
| FFs | 1,507 | 1,503 |
| BRAM | 1 tile / 2 RAMB18 | 1 tile / 2 RAMB18 |
| DSP | 0 | 0 |

Calculation:

```text
108.225 MHz / 1.339 CPI = 80.8 practical estimated MIPS
```

Phase 13C improves practical estimated MIPS by about 6.2% over Phase 13A.

## Interpretation

Phase 13C is a useful timing-closure improvement. It preserves the Phase 13A CPI and instruction retirement count while increasing verified post-route Fmax.

It does not reach the 90 MIPS primary target. Using the project classification:

```text
80-89.9 MIPS: strong result, close to target
```

Phase 13C is therefore a strong result, but not a 90 MIPS result.

## Remaining Bottleneck

The remaining critical path is no longer the Phase 13A frontend PC path. The dominant remaining timing family is data BRAM output through operand forwarding/control into ID/EX operand registers.

Possible Phase 13D work:

- isolate data-memory response forwarding from frontend and decode control;
- reduce remaining dynamic reset/control muxing on ID/EX operand fields;
- examine load-to-branch and load-to-ALU interlock logic for route-heavy fanout;
- test whether a registered load-result path improves Fmax enough to offset any CPI penalty;
- run tighter period sweeps after each single optimisation.

## Acceptance Criteria

| Criterion | Result |
| --- | --- |
| Baseline remains available | Passed |
| Full XSim regression passes | Passed |
| Retired count remains correct | Passed |
| No instruction lost, duplicated or incorrectly retired | Passed |
| BRAM inference retained | Passed |
| Post-route routing completes | Passed |
| TNS zero at claimed frequency | Passed at 9.240 ns |
| Hold timing passes | Passed |
| Bitstream generation passes | Passed |
| Practical MIPS exceeds Phase 13A | Passed |
| Resource changes reported | Passed |
| 90 MIPS reached | Not reached |

## Recommendation

Retain Phase 13C as the preferred timing-optimised pipeline path, while keeping Phase 13A as the comparison baseline. The recommended next phase is Phase 13D, focused on the remaining data-memory-to-ID/EX operand timing family.
