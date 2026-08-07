# AI Optimization Plan

## Scope And Baseline

This plan targets the Phase 12 five-stage CPU because it matches the stated
approximately 71.1 MIPS baseline. Later Phase 13-24 variants are retained as
historical optimisation experiments and are not modified by this work.

The baseline is an in-order 32-bit custom CPU with five architectural stages:

| Stage | Main work |
| --- | --- |
| IF | Issue a synchronous instruction-BRAM read and preserve request PC metadata |
| ID | Decode fields, read the register array and create control |
| EX | Forward operands, execute ALU operations and resolve BEQ |
| MEM | Access synchronous data BRAM |
| WB | Select ALU/load data, write `rd` and publish retirement information |

The implementation uses separate instruction and data BRAMs, a one-entry
fetch buffer, valid bits in IF/ID, ID/EX, EX/MEM and MEM/WB, `x0` hardwired to
zero, EX/MEM and MEM/WB forwarding, WB-to-ID bypass, one-cycle load-use
stalls, and registered branch/jump redirects that flush younger work.

The original ISA has one 32-bit instruction format:

```text
[31:28] opcode | [27:23] rd | [22:18] rs1 | [17:13] rs2 | [12:0] imm13
```

Before Phase 2, opcodes `0x0` through `0xA` were used and `0xB` through `0xF`
were unused. Programs are hand-encoded hexadecimal `.mem` files loaded with
`$readmemh`; the repository has no assembler or instruction-image generator.

The original Phase 12 routed design used 1,146 LUTs, 1,473 FFs, one BRAM tile
and no DSPs. It met 100 MHz with WNS `+0.185 ns`. Its aggregate XSim benchmark
measured 457 cycles for 319 retired instructions (CPI 1.433), corresponding to
69.803 MIPS at 100 MHz or approximately 71.1 MIPS at its timing-estimated
101.9 MHz Fmax.

## Arithmetic Data Path

For ADD/SUB/AND/OR/XOR, ID reads `rs1` and `rs2`; EX selects the newest values
from EX/MEM or MEM/WB and computes `ex_alu_result`; EX/MEM and MEM/WB carry the
result to the existing writeback port. ADDI substitutes the sign-extended
immediate for operand B. LOAD/STORE use the same adder for the effective byte
address, then access synchronous data BRAM in MEM.

The most suitable near-term AI insertion point is EX because:

- both source operands and all existing forwarding paths are already present;
- the result naturally uses the existing EX/MEM, MEM/WB and retirement paths;
- no new architectural register or memory interface is required;
- a multiply-add maps directly to an FPGA DSP block.

The ID/EX register is the suitable place to carry the old `rd` accumulator.
The load-use detector and forwarding muxes are the suitable places to model
the implicit third source dependency. Future packed operations may need an
extra execute stage or an explicit multi-cycle ready/stall handshake if their
adder tree cannot meet the clock period.

## Phase 1: Existing-ISA Dot-Product Baseline

Implemented files:

- `programs/ai_dot_product_baseline.mem`
- `programs/ai_dot_product.md`

The benchmark calculates:

```text
[3, -2, 5, -4] dot [-3, 4, -1, -2] = -14
```

Because the original ISA has no multiply or shifts, the unrolled arithmetic
kernel uses repeated signed ADD/SUB operations. This is deliberately simple
and completely reproducible; it is not presented as a general software
multiplier. It provides a fair fixed-workload baseline for the new instruction.

Measured in Vivado XSim through retirement of the result STORE:

| Metric | Existing ISA |
| --- | ---: |
| Arithmetic-kernel instructions | 14 |
| Initialization + kernel + STORE instructions | 24 |
| Enabled cycles through STORE | 29 |
| Result | `0xffff_fff2` (-14) |

## Phase 2: Scalar Signed INT8 MAC8

### Encoding

`MAC8` uses previously unused opcode `4'hb`:

```text
MAC8 rd, rs1, rs2
rd = rd + signed(rs1[7:0]) * signed(rs2[7:0])
```

`rd` is both a 32-bit accumulator source and the destination. `rs1[7:0]` and
`rs2[7:0]` are signed two's-complement INT8 inputs. Their full signed 16-bit
product is sign-extended to 32 bits before addition. The final result wraps
modulo `2^32`; there is no silent product truncation, saturation or overflow
flag. Instruction bits `[12:0]` are reserved and should be encoded as zero.

The opcode is deliberately enabled only in `cpu_core_pipeline_full`. Shared
historical cores still reject `0xB`, because accepting it without an execute
implementation would silently corrupt results.

### Pipeline And Hazard Changes

- ID reads the old `rd` value as an implicit accumulator source.
- ID/EX carries a new 32-bit accumulator field.
- EX/MEM forwarding supplies a preceding ALU/MAC result to any of the three
  MAC sources; MEM/WB forwarding and WB-to-ID bypass cover older producers.
- The load-use detector checks `rs1`, `rs2` and implicit accumulator `rd`.
- Back-to-back MAC8 instructions targeting the same accumulator need no stall.
- A LOAD immediately feeding any MAC8 source receives the existing one-cycle
  load-use bubble.
- MAC8 uses normal EX/MEM and MEM/WB writeback and retirement; no new writeback
  port or architectural state is introduced.

### Timing Choice

MAC8 is single-cycle in EX. A multi-cycle operation would require global
pipeline back-pressure and would reduce the benefit for short dot products.
The inferred expression is guided with `use_dsp = "yes"`; it remains portable
SystemVerilog arithmetic at the functional level and does not instantiate a
DSP48 primitive.

Vivado maps the expression as one unregistered DSP48E1 `C + A*B`. The routed
design still meets 100 MHz, but WNS falls from `+0.185 ns` to `+0.031 ns`.
The worst path remains a data-BRAM/writeback/frontend-control path rather than
the DSP path. A completed 95-110 MHz sweep passed all five independent 100 MHz
runs and failed all five 102 MHz runs at setup, bounding the tested Fmax for
this exact flow to `100 MHz <= Fmax < 102 MHz`. The small margin means future
packed arithmetic must not simply extend this combinational EX path without
retiming. See `../reports/ai_mac_fmax_sweep.md` for the method and full table.

### Measured Comparison

All XSim counts below are measured through retirement of the result STORE.
Vivado resource/timing values are post-route measurements at 100 MHz.

| Metric | Existing ISA | MAC8 | Change |
| --- | ---: | ---: | ---: |
| Arithmetic-kernel instructions | 14 | 4 | 3.500x fewer kernel instructions |
| Total retired instructions | 24 | 14 | 1.714x fewer total instructions |
| Enabled cycles | 29 | 19 | 1.526x measured cycle speed-up |
| Result | -14 | -14 | Exact match |
| LUTs | 1,146 | 1,454 | +308 |
| FFs | 1,473 | 1,507 | +34 |
| BRAM tiles | 1 | 1 | No change |
| DSPs | 0 | 1 | +1 |
| WNS at 100 MHz | +0.185 ns | +0.031 ns | -0.154 ns margin |
| Estimated Fmax from routed slack | ~101.9 MHz | ~100.3 MHz | ~1.5% lower |
| Tested Fmax bracket | Not swept | 100 MHz passes; 102 MHz fails | `100 MHz <= Fmax < 102 MHz` |
| Vectorless power estimate | 0.089 W | 0.091 W | +0.002 W |

The instruction and cycle comparisons are measured XSim results. The resource,
power and slack rows are measured Vivado report values. The estimated-Fmax row
is a calculation from the routed 100 MHz slack; the tested bracket comes from
the completed frequency sweep. Combining the slack-derived Fmax estimates with
the measured cycle counts predicts about a 1.50x throughput improvement; that
is a prediction, whereas 1.526x is the measured same-clock cycle speed-up.

### Phase 2 Timing Optimisation

Post-route path inspection showed that the original 100 MHz limiter was not
the DSP. It ran from data BRAM through LOAD write-back, MEM/WB-to-EX
forwarding, the BEQ comparison, and redirect/flush logic to a fetch-buffer
payload reset input. Its 9.339 ns data delay was 4.113 ns logic (44.040%) and
5.226 ns routing (55.960%) across nine levels.

The accepted experimental core, `cpu_core_pipeline_mac8_timingopt`, keeps the
verified baseline intact and clears only frontend valid bits during dynamic
bubbles and redirects. Invalid PC/instruction payload registers retain
don't-care data; reset behaviour and valid instruction loading are unchanged.
This removes the long redirect cone from payload data/reset inputs without a
new stage or architectural change.

| Metric | Original MAC8 | Timing-optimised MAC8 |
| --- | ---: | ---: |
| 100 MHz setup WNS | +0.031 ns | +0.198 ns (3/3) |
| 102 MHz setup WNS | -0.074 ns | +0.071 ns (1/1) |
| Highest repeatable pass | 100 MHz | 104 MHz (5/5, +0.062 ns minimum) |
| First consistent fail | 102 MHz | 105 MHz (0/5, -0.148 ns maximum) |
| Repeatable boundary | `100 MHz pass; 102 MHz fail` | `104 MHz pass; 105 MHz fail` |
| Highest observed pass | 100 MHz | 105 MHz with controlled directives (single runs) |
| LUT / FF / DSP / BRAM | 1,454 / 1,507 / 1 / 1 | 1,457 / 1,507 / 1 / 1 |

Focused verification remains 83 checks with zero failures and the original
Phase 12 regression remains 2,793 checks with zero failures, 457 cycles, and
319 retired instructions. See
`../reports/ai_mac8_timing_optimisation.md` and
`../reports/ai_mac8_boundary_sweep.md` for complete path, repeatability,
directive-variation, per-run timing, and utilisation evidence.

The 104 MHz repeatable margin is only `+0.062 ns`, below the approximate
`0.1 ns` threshold for safely extending the single-cycle EX datapath. The
newly resolved 105 MHz limiter passes through the existing DSP48E1, while a
separate frontend/branch-control family also fails. DOT4ACC planning may
therefore proceed only as a pipelined/isolation exercise; a single-cycle
combinational implementation is not recommended.

Architecture-planning status: complete. The selected three-stage arithmetic
pipeline, dependency policy, performance model, verification matrix, and
staged acceptance gates are recorded in
[`dot4acc_pipelined_architecture_plan.md`](dot4acc_pipelined_architecture_plan.md).

Stage A2 status: complete. The isolated `dot4acc_pipeline` implements and
verifies the three registered arithmetic stages with exact valid displacement,
II=1, bubbles, global-enable freeze, reset flush, and Stage A1 equivalence. It
is reused unchanged by the Stage C experiment.

Stage C status: complete in the copied experimental
`cpu_core_pipeline_dot4acc_issue`. Canonical decode, registered operand issue,
fixed-depth dependency tracking, LOAD handling, II=1 ordered same-`rd` chains,
younger non-DOT holds, redirects, and reset flushing are verified. DOT results
remain observation-only: architectural writeback and retirement are absent and
reserved for Stage D, while every historical core remains unchanged.

Stage D status: complete in the separate experimental
`cpu_core_pipeline_dot4acc_wb`. Eligible DOT completions share the existing
single register-file write port through collision-asserted arbitration, carry
aligned PC/opcode/`rd`/result metadata, write and retire exactly once, and
increment the retired-instruction counter once. Same-`rd` chains retain II=1;
historical cores remain unchanged. Full benchmarking and post-route timing are
the next stage.

Stage E status: complete as an architectural/simulation benchmark with no RTL
changes. The self-checking suite passed 233 checks and recorded 48 result rows.
At the equal nominal 100 MHz clock, the 64-element neuron measured 118 scalar,
70 MAC8, and 27 DOT4ACC cycles; DOT4ACC achieved 237.04 MMAC/s, 4.37x speedup
over scalar, 2.59x over MAC8, and 59.26% of its theoretical arithmetic peak.
The 32-member same-`rd` stream retained issue/completion/retirement II=1, while
memory-fed and interleaved-scalar measurements quantify the present
correctness-first hold cost. Full data and controls are in
`reports/dot4acc_stage_e_benchmark.md`. Repeatable post-route 100 MHz proof and
bounded Fmax characterization remain Stage F.

Stage F status: complete without CPU or DOT RTL changes. Under the established
default Vivado 2026.1 flow, the fixed Stage D/E core passes 98 MHz in 5/5 clean
routes and fails setup at 99 MHz and 100 MHz in 5/5 routes each; hold and pulse
width pass throughout. All four DOT DSPs retain `AREG=1` and `BREG=1`, and the
absolute limiting paths are DOT chain/dependency plus branch/redirect/frontend
control rather than DOT arithmetic. See `reports/dot4acc_stage_f_timing.md`.

## Phase 3: Packed INT8 DOT4ACC Proposal — Issue Control Only

A future instruction could treat each source register as four signed INT8
lanes:

```text
DOT4ACC rd, rs1, rs2
sum = signed(rs1[7:0])   * signed(rs2[7:0])
    + signed(rs1[15:8])  * signed(rs2[15:8])
    + signed(rs1[23:16]) * signed(rs2[23:16])
    + signed(rs1[31:24]) * signed(rs2[31:24])
rd = (rd + sign_extend(sum)) mod 2^32
```

Each product is a full signed 16-bit value. The sum of four INT8 products fits
in signed 18 bits before addition to the 32-bit accumulator. Opcode `0xC` is a
possible provisional encoding, but it is not assigned by this phase and must
be checked again before implementation.

Four parallel multipliers plus a balanced adder tree could use four DSPs, or a
mix of DSP and LUT logic. A single-cycle implementation is unlikely to be the
right first choice given the current `+0.031 ns` margin. Preferred options are
a two-cycle execute unit with explicit pipeline back-pressure, or a deeper
pipeline that forwards the packed result only when valid. Hazard detection
must treat `rd` as an implicit source exactly as MAC8 does.

## Phase 4: Local AI Memory And Accelerator Proposal — Not Implemented

A later accelerator should reduce register-file and general data-memory
traffic rather than only adding arithmetic instructions:

- separate activation and weight scratchpads, using byte-wide banks or packed
  32-bit words in dual-port BRAM;
- a 32-bit or wider accumulator/result scratchpad;
- a small DMA engine to move blocks between general memory and scratchpads;
- a 2x2 MAC array as the first educational implementation, scaling to 4x4 only
  after bandwidth, timing and verification are understood;
- address generators for matrix rows/columns and, later, convolution windows;
- a command/status interface with explicit busy/done/error state and a defined
  CPU stall, polling or interrupt policy.

The memory system should be banked so weights and activations can be read in
the same cycle. DMA must arbitrate safely with the CPU and define alignment,
length and out-of-range behavior. None of this phase is implemented here.

## Verification Strategy

Phase 2 verification includes:

- positive, negative, mixed-sign and zero operands;
- INT8 `+127` and `-128` boundaries with the full 16-bit product;
- repeated accumulation and back-to-back accumulator forwarding;
- MAC-result-to-source and MAC-result-to-STORE forwarding;
- LOAD-to-`rs1`, LOAD-to-`rs2` and LOAD-to-accumulator hazards;
- reset and `x0` behavior;
- positive and negative 32-bit accumulator overflow wrapping;
- integration comparison of the original and MAC8 dot products;
- unchanged Phase 12 custom-ISA regression;
- full repository XSim regression;
- Vivado synthesis, implementation, routing and timing checks.

Future DOT4ACC verification should add lane-order tests, every-lane sign
boundary, adder-tree width proofs, randomized reference-model checking,
multi-cycle stall/flush interactions, and post-synthesis equivalence of any
retimed implementation.

## Staged Roadmap

1. Phase 1 — complete: retain the existing-ISA four-element dot product as the
   reproducible software baseline.
2. Phase 2 — complete: retain MAC8 only if full regression and 100 MHz timing
   remain clean; use the comparison table as the new scalar-AI baseline.
3. Phase 2 timing optimisation — complete: accept the valid-only frontend
   experimental variant. Five deterministic default-flow executions pass
   104 MHz at `+0.062 ns`, while five fail 105 MHz at `-0.148 ns`.
   Repetition labels are not placer seeds.
4. Next single step / Phase 3 proposal: plan a pipelined DOT4ACC architecture
   that isolates the packed arithmetic from the current MAC8 DSP path; do not
   write DOT4ACC RTL during the characterization phase.
5. Phase 4 — proposal only: define scratchpad/DMA interfaces and verify memory
   bandwidth with a 2x2 MAC-array model before hardware implementation.

## Remaining Risks

- The timing-optimised routed 100 MHz margin is `+0.198 ns`, but the highest
  repeatable point, 104 MHz, has only `+0.062 ns`; 105 MHz fails both the DSP
  path and frontend/branch-control paths under the default flow.
- Placement-seed sensitivity remains unquantified because Vivado exposes no
  supported seed here. Single-run placement and routing directive variations
  pass 105 MHz but are not repeatability evidence.
- Invalid frontend payload values are now retained across bubbles and
  redirects. Every consumer must continue to be gated by the matching valid
  bit.
- `use_dsp` is a Vivado synthesis directive. Other tools may implement MAC8 in
  LUTs and produce different timing/resource results.
- The extra asynchronous accumulator read and forwarding selection increase
  LUT/routing cost even though the multiply-add itself uses one DSP.
- Signedness depends on taking exactly the low eight bits before `$signed`;
  later refactoring must preserve this order.
- Wraparound, not saturation, is architectural. Quantized networks requiring
  saturating requantization need a separate, explicitly specified operation.
- MAC8 is implemented only in the Phase 12 core; software must not run it on a
  historical core variant.
