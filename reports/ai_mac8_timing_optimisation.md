# MAC8 Post-Route Timing Optimisation

Date: 5 August 2026  
Tool: AMD Vivado 2026.1  
Part: `xc7a35tcpg236-1` (Digilent Basys 3)  
Clock: `sys_clk_pin`

## Outcome

A small frontend validity change improved repeatable 100 MHz setup WNS from
`+0.031 ns` to `+0.198 ns`, closed 102 MHz at `+0.071 ns`, and passed 104 MHz
at `+0.062 ns`. Three identical deterministic executions passed at 104 MHz;
three failed at 106 MHz with `-0.081 ns`. The new tested boundary is:

```text
104 MHz <= Fmax < 106 MHz
```

MAC8 behaviour, encoding, forwarding, hazard handling, dot-product results,
cycle counts, and the original Phase 12 regression result are unchanged. One
DSP48E1 and one BRAM tile remain inferred. The accepted 100 MHz implementation
uses 1,457 LUTs and 1,507 FFs, a cost of three LUTs and no FF growth.

The verified baseline remains unchanged in `rtl/cpu_core_pipeline_full.sv`.
The accepted experiment is isolated in
`rtl/cpu_core_pipeline_mac8_timingopt.sv` and differs only in dynamic frontend
payload invalidation. This follows the repository convention of preserving
experimental CPU variants.

## Baseline critical-path evidence

The preserved baseline 100 MHz checkpoint reports this exact worst setup path:

- startpoint: `cpu_inst/data_mem_inst/mem_reg/CLKBWRCLK`, RAMB18E1 at
  `RAMB18_X0Y4`;
- endpoint: `cpu_inst/fetch_buffer_instruction_reg[15]/R`;
- clock: `sys_clk_pin`;
- slack: `+0.031 ns`;
- data-path delay: `9.339 ns`;
- logic delay: `4.113 ns` (`44.040%`);
- routing delay: `5.226 ns` (`55.960%`);
- logic levels: 9 (`LUT3`, `LUT5`, `LUT6`, two `CARRY4` cells, and four
  redirect/flush LUT levels).

The path is:

```text
data BRAM output
  -> write-back LOAD/ALU LUT3
  -> wb_write_data[21] (38 flat pins)
  -> EX operand forwarding LUT5
  -> 32-bit BEQ equality LUT6 + 2 CARRY4
  -> branch redirect/flush LUT cone
  -> fetch-buffer instruction reset input
```

The corresponding 102 MHz worst path has WNS `-0.074 ns`, starts at the data
BRAM `CLKARDCLK`, ends at `if_id_reg_reg[pc][17]/R`, and has `9.401 ns` data
delay: `4.270 ns` logic (`45.423%`) plus `5.131 ns` routing (`54.577%`) across
9 levels.

This is a LOAD write-back/MEM-WB forwarding path through the EX branch compare
and frontend flush. It is not an accumulator-forwarding, rs2-forwarding,
register-file-read, sign-extension, DSP-internal, DSP-output, or hazard-detect
path. The main baseline problem is the combination of mux depth, branch/control
fan-out, and routing. Relevant fan-outs are 38 on each `wb_write_data` bit, 17
on the branch-compare result, about 39--40 on redirect/flush control, and 33 on
the final payload reset control.

## DSP48E1 inspection

Vivado correctly infers exactly one DSP48E1 for the signed multiply-add. In the
baseline it is placed at `DSP48_X0Y2`; in the accepted 104 MHz implementation
it is at `DSP48_X0Y4`. The accepted configuration remains:

- `USE_MULT=MULTIPLY`;
- `USE_SIMD=ONE48`;
- `AREG=BREG=CREG=MREG=PREG=0`;
- `USE_DPORT=0`.

`DREG` and `ADREG` report 1 as primitive properties, but the D port is tied off
and unused; no active MAC pipeline register exists. The baseline's closest
100 MHz DSP path had WNS `+0.040 ns` and was therefore near-critical but not
the absolute limiter. It ran from data BRAM through write-back and rs1
forwarding into the DSP, then through the result-select LUT to EX/MEM.

## Options considered

| Option | Expected benefit | Cost/risk | Decision |
| --- | --- | --- | --- |
| Split LOAD and ALU/MAC write-back forwarding sources | Remove a write-back mux in series with forwarding | Extra compares/mux inputs could duplicate logic | Tested first, rejected |
| Clear only frontend valid bits dynamically | Remove branch/flush control from invalid payload data inputs | Invalid payloads retain don't-care data; validity discipline must be preserved | Accepted |
| Add a DSP/MAC pipeline register | Break the remaining combinational DSP path | Changes MAC latency and requires new stalls/forwarding or scoreboarding | Not implemented; explicit approval would be required |

## Candidate 1: split write-back forwarding -- rejected

The first experiment predecoded MEM/WB LOAD versus ALU/MAC sources and selected
them directly in decode and EX forwarding. Focused MAC8 verification passed all
83 checks, and the Phase 12 regression passed all 2,793 checks with 457 cycles
and 319 retired instructions.

Post-route evidence rejected it immediately at 100 MHz:

- setup WNS `-0.321 ns`, TNS `-8.591 ns`, 43 failing endpoints;
- hold WNS `+0.056 ns`, hold TNS `0.000 ns`;
- 1,654 LUTs, 1,497 FFs, 1 DSP, 1 BRAM tile;
- worst path remained data BRAM to
  `fetch_buffer_instruction_reg[15]/R`, with 9 levels;
- data delay `9.838 ns`: `4.270 ns` logic (`43.403%`) and `5.568 ns` routing
  (`56.597%`).

Vivado duplicated enough selection/comparison logic to add 200 LUTs over the
baseline and worsened timing. Per the one-change-at-a-time rejection rule, no
higher-frequency runs were used and the candidate RTL was overwritten rather
than preserved as an abandoned variant.

## Candidate 2: valid-only frontend invalidation -- accepted

### RTL change

Reset still writes defined values to `if_id_reg` and fetch-buffer payloads.
During redirect, redirect-pending, empty-response, and buffer-consume events,
the candidate now clears only the associated `valid` bit. Invalid payload PC
and instruction registers retain their previous value as don't-care state.

Before:

```systemverilog
if_id_reg.valid       <= 1'b0;
if_id_reg.pc          <= 32'h0000_0000;
if_id_reg.instruction <= NOP_INSTRUCTION;
```

After:

```systemverilog
if_id_reg.valid <= 1'b0;
```

The same principle applies to fetch-buffer payload clearing. Valid
instructions are loaded identically to the baseline. There is no new pipeline
stage, stall, bypass, architectural state, encoding, or software-visible
change.

### Functional verification

| Test | Checks | Failures | Cycles/instructions |
| --- | ---: | ---: | --- |
| Focused MAC8 XSim | 83 | 0 | baseline dot product 29/24; MAC8 19/14 |
| Original Phase 12 XSim | 2,793 | 0 | aggregate 457/319 |

Both dot products produce `0xfffffff2` (signed -14). The focused suite covers
positive, negative, mixed-sign, INT8 extrema, repeated accumulation, wrapping
overflow, back-to-back accumulator dependencies, EX/MEM and MEM/WB forwarding,
load-to-rs1, load-to-rs2, load-to-accumulator, reset, `x0`, invalid opcode
safety, STORE forwarding, and dot-product equivalence.

### Post-route timing and utilisation

Every row below routed successfully, passed hold timing, and generated a
bitstream. A bitstream from a setup-failing run is evidence of flow completion,
not a deployable timing-clean result.

| Target | Period | Runs passing | Setup WNS | Setup TNS | Hold WNS | Hold TNS | Failing setup endpoints | LUT | FF | DSP | BRAM |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 MHz | 10.000 ns | 3/3 | +0.198 ns | 0.000 ns | +0.035 ns | 0.000 ns | 0 | 1,457 | 1,507 | 1 | 1 |
| 102 MHz | 9.804 ns | 1/1 | +0.071 ns | 0.000 ns | +0.037 ns | 0.000 ns | 0 | 1,456 | 1,507 | 1 | 1 |
| 104 MHz | 9.615 ns | 3/3 | +0.062 ns | 0.000 ns | +0.055 ns | 0.000 ns | 0 | 1,457 | 1,507 | 1 | 1 |
| 106 MHz | 9.434 ns | 0/3 | -0.081 ns | -0.815 ns | +0.033 ns | 0.000 ns | 13 | 1,457 | 1,507 | 1 | 1 |

A fresh baseline-versus-candidate rerun on 6 August 2026 reproduced the
consolidated 100, 102 and 104 MHz results exactly:

| Target | Original setup WNS | Candidate setup WNS | WNS improvement | Original/candidate result |
| ---: | ---: | ---: | ---: | --- |
| 100 MHz | +0.031 ns | +0.198 ns | +0.167 ns | pass / pass |
| 102 MHz | -0.074 ns | +0.071 ns | +0.145 ns | fail / pass |
| 104 MHz | -0.273 ns | +0.062 ns | +0.335 ns | fail / pass |

All six rerun implementations routed successfully, passed hold timing and
generated bitstreams. The setup gains are therefore measurable at every
requested comparison point, not inferred from a single route.

All repeated WNS values were identical. Each repetition was a fresh Vivado
process using the same deterministic directives and constraints;
`seed_applied=false` is recorded in the CSV because Vivado 2026.1 did not
expose a supported implementation seed in this flow. Full per-run fields,
including endpoints, delays, logic levels, routes, bitstreams, and resources,
are in `ai_mac8_validonly_fmax/results.csv`.

### Accepted critical paths

At 100 MHz, the old payload-reset path is gone. The new worst path is the
near-critical MAC datapath:

- startpoint: data BRAM `CLKARDCLK` at `RAMB18_X0Y4`;
- endpoint: `ex_mem_reg_reg[alu_result][24]/D`;
- WNS `+0.198 ns`;
- data delay `9.721 ns`;
- logic `6.667 ns` (`68.584%`), route `3.054 ns` (`31.416%`);
- 4 levels: write-back LUT3, rs1-forward LUT5, DSP48E1, result-select LUT6.

At the highest passing 104 MHz point, the worst path is LOAD write-back through
rs1 forwarding, the 32-bit branch comparison, redirect control, and redirect
target addition:

- startpoint: data BRAM `CLKARDCLK`;
- endpoint: `redirect_pending_target_reg[30]/D`;
- WNS `+0.062 ns`;
- data delay `9.559 ns`;
- logic `5.574 ns` (`58.313%`), route `3.985 ns` (`41.687%`);
- 16 levels: 11 `CARRY4`, one LUT3, one LUT4, two LUT5, one LUT6.

The closest 104 MHz DSP path passes at `+0.165 ns`, with `9.415 ns` data delay:
`6.667 ns` logic (`70.816%`) and `2.748 ns` routing (`29.184%`) across four
levels.

At 106 MHz, the absolute worst path is data BRAM through write-back, branch
comparison, redirect control, and the inferred clock-enable network for a held
fetch-buffer payload register:

- endpoint: `fetch_buffer_instruction_reg[27]/CE`;
- WNS `-0.081 ns`, data delay `9.294 ns`;
- logic `4.146 ns` (`44.611%`), route `5.148 ns` (`55.389%`);
- 8 levels and a final control net with 64 flat pins.

The 106 MHz DSP path also fails at `-0.050 ns`, so further frequency gain must
address both frontend/branch control and the combinational DSP input/output
path rather than hiding one endpoint with a constraint.

## Compact comparison

| Design | 100 MHz WNS | 102 MHz | LUT/FF/DSP/BRAM at 100 MHz | Functional result | Decision |
| --- | ---: | --- | --- | --- | --- |
| Original MAC8 | +0.031 ns | fails, -0.074 ns | 1,454 / 1,507 / 1 / 1 | verified | preserved reference |
| Split-WB forwarding | -0.321 ns | not run after rejection | 1,654 / 1,497 / 1 / 1 | 83 + 2,793 checks pass | rejected |
| Valid-only frontend | +0.198 ns | passes, +0.071 ns | 1,457 / 1,507 / 1 / 1 | 83 + 2,793 checks pass | accepted |

## Remaining risks and recommendation

The accepted design relies on the invariant that invalid frontend payloads are
never consumed; current decode, fetch, retirement, and self-checking tests all
enforce that invariant. At 106 MHz, both the branch/clock-enable control cone
and the unregistered DSP path fail setup. The high-fan-out 38-pin write-back
buses, 17-pin branch result, 34-pin redirect control, and 64-pin payload-enable
control remain timing risks. Results are deterministic-flow evidence, not a
placement-seed distribution.

Accept the timing-optimised MAC8 as the recommended implementation variant and
proceed to DOT4ACC planning. Keep the original MAC8 RTL as the reproducible
reference until the experimental variant is intentionally promoted in a
separate reviewed change.
