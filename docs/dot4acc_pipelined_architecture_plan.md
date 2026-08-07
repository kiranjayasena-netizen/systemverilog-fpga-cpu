# Pipelined DOT4ACC Architecture Plan

Status: Stages A1, A2, C, and D are complete. `OP_DOT4ACC = 4'hc` remains
non-executable in every historical core. The Stage D successor
`cpu_core_pipeline_dot4acc_wb` preserves the verified Stage C issue controls
and adds single-port architectural writeback plus exactly-once in-order
retirement. Post-route timing and full architectural benchmarking remain
future work.

## Executive summary

Use a dedicated three-stage DOT4ACC arithmetic pipeline in a new experimental
copy of the timing-optimised MAC8 core. A separate issue register terminates
the existing decode/forwarding paths before the four multipliers. The three
arithmetic stages register: (1) four signed 16-bit products, (2) one signed
18-bit balanced-tree result, and (3) the 32-bit accumulated result.

The issue register plus arithmetic stages occupy four cycles. A result and its
aligned PC/opcode/destination metadata are observable three advancing clocks
after issue acceptance and are consumed for architectural writeback and
retirement on the fourth advancing edge. Independent or contiguous
same-accumulator DOT4ACC instructions retain an initiation interval (II) of
one.

Younger scalar, memory, and control instructions remain held until all older
DOT4ACC operations complete. Consecutive DOT4ACC operations may issue. This
restriction preserves in-order retirement and the single register-file write
port without a reorder buffer. Comparisons against valid destination metadata
in the DOT pipeline form a compact scoreboard; a one-result bypass supports
contiguous same-`rd` accumulator chains.

The DOT unit uses four dedicated DSP48E1 blocks. The existing MAC8 DSP remains
separate so its verified path is untouched, giving five DSPs in the complete
experimental core. The estimated increment is 180--300 LUTs and 350--450 FFs.
All estimates require synthesis and post-route confirmation.

## Repository evidence and five-stage baseline

The timing-optimised core is an in-order pipeline:

```text
IF -> ID -> EX -> MEM -> WB/retirement
      |     |      |       |
    IF/ID ID/EX  EX/MEM  MEM/WB
```

The instruction BRAM uses fetch-pending and fetch-buffer state. Decode reads
`rs1`, `rs2`, and the old `rd` accumulator for MAC8. ID/EX carries operands and
controls. EX/MEM carries ALU/MAC results, memory controls, and STORE data.
MEM/WB selects LOAD data or the ALU result for the single register-file write
port and retirement interface.

Current dependency and side-effect rules are:

- EX/MEM forwarding for non-LOAD results and MEM/WB forwarding for LOAD/ALU
  results to EX `rs1`, `rs2`, STORE data, and the MAC8 accumulator;
- WB-to-ID bypass while decode captures operands;
- one load-use bubble when an ID instruction consumes the ID/EX LOAD
  destination, including MAC8's implicit `rd` source;
- register writes gated by MEM/WB valid, `reg_write`, and `rd != x0`;
- memory effects gated by EX/MEM valid;
- redirects and performance events gated by valid instructions; and
- retirement gated by MEM/WB valid.

At 104 MHz, the repeatable worst path is data BRAM through LOAD writeback,
MEM/WB-to-EX forwarding, BEQ comparison, redirect control, and target addition
to `redirect_pending_target_reg[30]/D`. At 105 MHz, a second limiter runs from
data BRAM through writeback and forwarding into the unregistered MAC8 DSP and
then to EX/MEM. A wider combinational EX expression is therefore excluded.

## Opcode availability and recommended encoding

Opcode `4'hc` is currently free:

- `cpu_defs_pkg.sv` assigns `4'h0` through `4'ha` to the base ISA and `4'hb`
  to MAC8;
- the shared `opcode_is_valid()` accepts only the base ISA, while Phase 12
  cores locally add MAC8;
- `docs/isa.md` explicitly leaves `4'hc` through `4'hf` invalid; and
- the Phase 12 test currently uses `4'hc` as an invalid-opcode case.

The recommended provisional encoding is:

| Bits | DOT4ACC meaning |
| --- | --- |
| `[31:28]` | `4'hc` |
| `[27:23]` | `rd`, accumulator source and destination |
| `[22:18]` | `rs1`, four packed signed INT8 lanes |
| `[17:13]` | `rs2`, four packed signed INT8 lanes |
| `[12:0]` | reserved; canonical encoding is zero |

This planning task does not assign the encoding. During implementation, only
the new experimental core should accept it. The shared base predicate and
historical cores must continue to reject it. The current invalid-`0xc` test
must move to another invalid opcode only when DOT4ACC is implemented.

## Semantics and arithmetic widths

For:

```text
DOT4ACC rd, rs1, rs2
rs1 = {a3, a2, a1, a0}
rs2 = {b3, b2, b1, b0}
```

the exact operation is:

```text
p0 = signed16(signed8(a0) * signed8(b0))
p1 = signed16(signed8(a1) * signed8(b1))
p2 = signed16(signed8(a2) * signed8(b2))
p3 = signed16(signed8(a3) * signed8(b3))
s0 = signed17(sign_extend(p0) + sign_extend(p1))
s1 = signed17(sign_extend(p2) + sign_extend(p3))
dot = signed18(sign_extend(s0) + sign_extend(s1))
rd = (rd_old + sign_extend32(dot)) mod 2^32
```

Each product remains signed 16-bit. The largest product is +16,384
(`-128 * -128`) and the most negative is -16,256 (`-128 * 127`). Four lanes
span -65,024 through +65,536, requiring an 18-bit signed sum. Only the final
32-bit addition wraps. There is no saturation, rounding, exception, or flag.

For `rd == x0`, the accumulator is zero and the instruction may complete and
retire, but register write enable is false. Invalid opcodes never enter the
DOT pipeline and remain side-effect free.

## Architecture alternatives

| Property | Two-stage DOT pipeline | Three-stage DOT pipeline | Non-overlapped multi-cycle unit |
| --- | --- | --- | --- |
| Work | S1 four products; S2 full tree plus accumulator | Issue latch; S1 products; S2 tree; S3 accumulator | Reuse one/two multipliers, then accumulate |
| DOT DSPs | 4 | 4 | 1 or 2 |
| LUT arithmetic | Tree and 32-bit add share one stage | Tree and accumulator are separated | Partial sum and sequencing logic |
| Result latency | 2 clocks after acceptance | 3 clocks after acceptance | 4 clocks with one DSP; normally 3 with two DSPs |
| Best II | 1 | 1 | 4 with one DSP; normally 3 with two DSPs |
| Peak at 100 MHz | 400 MMAC/s | 400 MMAC/s | 100 MMAC/s with one DSP; about 133 MMAC/s with a registered two-DSP unit |
| Timing risk | High | Moderate and local | Low arithmetic risk |
| Control | Valids, dependencies, completion | Valids, compact scoreboard, chain bypass | Busy/ready FSM and global EX stall |
| LOAD | Stall and potentially long forwarding-to-DSP path | Existing bubble, then issue-latch isolation | Wait for operands, then global stall |
| Branch/flush | Younger controls cannot overtake | Younger controls held until drain | Global block naturally orders controls |
| Retirement | Must prevent completion collision | Ordered DOT burst, mutually exclusive selector | One completion after global stall |
| Verification | High timing/recurrence risk | Moderate, explicit invariants | Lowest functional complexity |

### Two-stage pipeline

The second stage would perform two pair sums, the final packed sum, and the
32-bit accumulator addition before one register. It also leaves little room to
isolate forwarded inputs before multiplication. This concentrates the same
mux, DSP, and carry-chain forms already seen near the boundary. Reject it as
the first implementation.

### Three-stage pipeline

Register products, the balanced tree output, and the accumulator result
separately. Precede them with an operand issue register. This costs FFs but
creates clear timing boundaries while preserving II=1. Select this option.

### Multi-cycle non-overlapped unit

A one-DSP unit can compute and accumulate one lane per cycle over four cycles,
for at most 100 MMAC/s. A two-DSP unit computes two lanes per product cycle; a
timing-safe registered reduction generally makes it a three-cycle operation,
about 133 MMAC/s. A two-cycle result must not be assumed until routed timing
proves the dual-product reduction and accumulator. This is the area-saving
fallback, but it blocks EX and sacrifices stream throughput.

## Selected architecture and pipeline diagram

Create a new copied experimental CPU such as
`cpu_core_pipeline_dot4acc_pipelined.sv`. Preserve both MAC8 cores.

```text
 existing IF/ID -> ID/EX -> DOT issue register
                              |
                              v
       +--------------------------------+
 D1    | 4 x signed 8x8 multiply        | -> 4 x signed16 product regs
       +--------------------------------+
                              |
                              v
       +--------------------------------+
 D2    | pair sums and signed18 total   | -> dot-total reg
       +--------------------------------+
                              |
                              v
       +--------------------------------+
 D3    | accumulator + sign-extended dot| -> completion/writeback reg
       +--------------------------------+
                              |
                              v
                shared architectural write port and retirement

 normal EX -> EX/MEM -> MEM/WB ---------+
```

DOT4ACC uses a separate execution pipeline. It does not occupy EX/MEM or
MEM/WB. PC, opcode, `rd`, accumulator snapshot, chain flag, and valid state
travel with the arithmetic. The main EX ALU remains available physically, but
issue control holds younger non-DOT instructions while DOT state is valid.

The existing `wb_write_data` and EX forwarding network remain exclusive to
the current pipeline. DOT completion selects only the register-file write port
and retirement outputs. A simulation assertion must prove normal and DOT
writeback are never simultaneously valid.

## Cycle-by-cycle operation

Let `I` be the cycle whose closing edge accepts a DOT from EX:

| Cycle | Operation |
| --- | --- |
| `I` | Apply existing EX/MEM and MEM/WB operand selection; capture packed sources, accumulator snapshot, PC, opcode, `rd`, and valid in the issue register. Insert a bubble into EX/MEM. |
| `I+1` | Four DSP48E1 blocks compute and register four signed 16-bit products. |
| `I+2` | Compute two signed 17-bit pair sums and one signed 18-bit total; register the total. |
| `I+3` | Select snapshot or chain result, perform the 32-bit modulo addition, write nonzero `rd`, and retire. |

Latency is three clock intervals from acceptance to architectural completion,
or four occupied cycles including issue. For `K` dependency-clean DOTs issued
at `I..I+K-1`, completions occur at `I+3..I+K+2`; II is one.

## Valid, enable, redirect, flush, and reset

- Every stage has an explicit valid bit; invalid payload is irrelevant.
- `enable == 0` freezes DOT state, completion, writeback, and retirement.
- An older EX redirect prevents a younger DOT in ID from launching.
- Once DOT launches, younger scalar/control instructions and the fast ID JUMP
  are held until DOT drains.
- A younger branch therefore cannot flush an older DOT. A taken older branch
  still kills a younger, unlaunched DOT through existing flush rules.
- Reset clears all DOT valids, pending destinations, chain state, and pending
  completion. No cancelled DOT may later write or retire.
- A generic flush must be age-aware: clear younger issue state, never an older
  launched DOT. The selected issue policy removes ambiguous age cases.

## Hazard and compact-scoreboard design

Ordinary forwarding cannot supply a result that has not been calculated. Use
comparisons against the valid destination metadata already in the DOT issue,
product, sum, and completion stages. This is a fixed-depth in-order scoreboard,
not a general out-of-order structure.

Issue rules:

1. Stall any non-DOT while a DOT stage is valid.
2. Stall a DOT when `rs1` or `rs2` matches any nonzero older DOT destination.
3. Allow a DOT with the same accumulator `rd` at II=1 only for the immediately
   preceding contiguous chain and only if `rs1/rs2` are independent.
4. Stall an interleaved WAW accumulator (`rd A`, `rd B`, `rd A`) until the
   older matching destination commits, preventing a stale snapshot.
5. Never mark `x0` busy.
6. Retain the existing one-cycle LOAD-use bubble for every DOT source role.

For a contiguous chain, D3 selects the immediately preceding valid completion
instead of the captured accumulator. Issue and completion order are identical,
so chain members reach D3 on consecutive cycles. DOT results are not added to
the existing EX forwarding muxes.

### Required sequence behaviour

| Sequence | Required action |
| --- | --- |
| Back-to-back `DOT rd` | II=1 if neither packed source reads pending `rd`; use chain bypass. |
| DOT then scalar reads `rd` | Hold scalar until DOT drain, then read committed `rd`. |
| Scalar writes `rd`, then DOT | Capture normal EX/MEM or MEM/WB forwarded accumulator. |
| LOAD then DOT `rs1` | Exactly one existing load-use bubble, then MEM/WB capture. |
| LOAD then DOT `rs2` | Same one bubble. |
| LOAD then DOT accumulator | Conservatively keep the same one bubble. |
| DOT then STORE | Hold STORE; read committed result without a new forwarding input. |
| DOT then BEQ | Hold BEQ; compare committed result. |
| DOT writes `x0` | Retire, but no busy state or register write. |
| Reset with DOT active | Clear valids; no later write or retirement. |
| Taken older branch | Younger DOT never launches. |
| Younger branch | Wait for older DOT completion, then execute normally. |

Fixed stalls alone would serialize useful accumulator chains. Forwarding from
early DOT stages cannot provide an unfinished result. A 32-entry busy-bit array
needs counts for repeated destinations, while allowing scalar instructions to
pass DOTs would require ordered completion buffering. Fixed-stage destination
comparisons plus one chain bypass are the smallest correct mechanism.

## Writeback arbitration and retirement

Retain one architectural write port. A mutually exclusive selector chooses
normal MEM/WB or DOT completion for register write and retirement. Do not add
DOT data to the high-fanout `wb_write_data` forwarding bus.

Ordering is guaranteed because older normal instructions drain before the
first DOT completes, DOTs complete in issue order at one per cycle, and no
younger non-DOT enters EX until every DOT valid clears. Required invariants are
`!(normal_wb_valid && dot_complete_valid)`, one retirement per valid
instruction, no result loss, and no write for `rd == x0`. A collision is an
architecture bug; silently prioritising one writer is forbidden.

## DSP mapping and resource estimate

Each lane should infer one signed 8-by-8 multiplier with registered 16-bit
output and a DSP-use request. Netlist inspection, not an attribute alone, must
prove mapping. Four dedicated DOT DSPs plus the preserved MAC8 DSP produce five
DSP48E1 blocks in the experimental core. Sharing the MAC8 DSP would add muxes
to its measured path and is not recommended initially.

A hybrid parallel unit with two DSP multipliers and two LUT multipliers could
retain II=1, but it would add a large signed-multiplier LUT cone, create unequal
lane timing, and complicate placement for little educational benefit. It is a
resource-pressure alternative only if synthesis shows that five total DSPs are
unacceptable; it is not the recommended mapping. Reusing two DSPs over two
product cycles or one DSP over four product cycles is the lower-area
multi-cycle alternative described above.

Do not claim four-lane packed multiplication in one DSP. For example:

```text
(a0 + a1*2^k) * (b0 + b1*2^k)
 = a0*b0 + (a0*b1 + a1*b0)*2^k + a1*b1*2^(2k)
```

The cross terms, signed corrections, guard spacing, and DSP48E1 input widths
prevent a simple four-product interpretation. Any packed alternative requires
a mathematical proof, synthesizer-supported mapping, and exhaustive
equivalence testing.

Estimated resources relative to 1,457 LUTs, 1,507 FFs, one DSP, and one BRAM:

| Resource | Increment | Estimated total |
| --- | ---: | ---: |
| DSP48E1 | +4 | 5 |
| LUT | +180 to +300 | about 1,637 to 1,757 |
| FF | +350 to +450 | about 1,857 to 1,957 |
| BRAM | 0 | 1 tile |

FFs cover operand isolation, product/total/metadata registers, valid bits, and
completion state. LUTs cover the signed tree, comparisons, chain selector, and
writeback selection. These are planning ranges, not measured results.

## Timing strategy

Target 100 MHz (`10.000 ns`). Expected local paths are issue FF to DSP product
FF, product FF through the 17/18-bit tree to total FF, and total/accumulator FF
through one 32-bit add to completion FF.

Mandatory isolation rules:

- terminate existing forwarding at the DOT issue register;
- never place DOT arithmetic in `ex_alu_result` or on MAC8-to-EX/MEM selection;
- never feed DOT completion into existing EX forwarding;
- hold dependent consumers until writeback instead of adding a forwarding
  input to the BRAM/writeback/branch cone;
- leave branch equality, target arithmetic, and jump target logic unchanged;
- keep scoreboard and busy fanout local to issue admission.

Acceptance requires routed nonnegative setup and hold slack at 100 MHz, zero
failing endpoints, full routing, a bitstream, expected DSP mapping, and no
material regression of known branch or MAC8 paths. Actual post-route cells and
nets must identify any new limiter.

## Performance model

DOT4ACC performs four lane MACs. Peak arithmetic throughput is 400 MMAC/s at
100 MHz after fill (800 million primitive multiply-plus-add operations per
second if those are counted separately). This is not a memory-fed application
throughput claim.

### Register-resident arithmetic

Assume operands are already in registers, DOT packed sources do not read a
pending DOT destination, all DOTs form one accumulator chain, and a dependent
STORE follows. The scalar column extrapolates the existing four-element
constant-coefficient benchmark's 3.5 arithmetic instructions per lane; it is
not a general software multiplier. Cycles include one STORE, the existing
five-cycle fetch/pipeline overhead, and three DOT drain cycles.

| Elements | Scalar arithmetic instructions | MAC8 instructions | DOT instructions | Scalar cycles | MAC8 cycles | DOT cycles | DOT speed-up vs scalar / MAC8 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 14 | 4 | 1 | 20 | 10 | 10 | 2.00x / 1.00x |
| 16 | 56 | 16 | 4 | 62 | 22 | 13 | 4.77x / 1.69x |
| 64 | 224 | 64 | 16 | 230 | 70 | 25 | 9.20x / 2.80x |

The measured four-element programs include nine initialization instructions:
scalar is 24 instructions/29 cycles and MAC8 is 14/19. Replacing four MAC8s
with one DOT projects 11 retired instructions but approximately 19 cycles
under the conservative drain policy. Pipeline fill hides the advantage for a
single four-lane operation; long streams approach the fourfold lane rate.

### Streaming from data memory

DOT4ACC needs two packed 32-bit LOADs per four lanes; MAC8 needs two operand
LOADs per lane. This conservative model uses `LOAD A; LOAD B; arithmetic`, one
immediate load-use bubble, one accumulator initialization, one final STORE,
and a DOT drain before the next scalar LOAD group:

```text
scalar:  5.5*N + 7 cycles (special measured arithmetic model)
MAC8:    4*N + 7 cycles
DOT4ACC: 7*ceil(N/4) + 7 cycles
```

| Elements | Scalar instructions | MAC8 instructions | DOT instructions | Scalar cycles | MAC8 cycles | DOT cycles | DOT speed-up vs scalar / MAC8 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 24 | 14 | 5 | 29 | 23 | 14 | 2.07x / 1.64x |
| 16 | 90 | 50 | 14 | 95 | 71 | 35 | 2.71x / 2.03x |
| 64 | 354 | 194 | 50 | 359 | 263 | 119 | 3.02x / 2.21x |

Software can reduce stalls by loading multiple packed pairs before a DOT burst,
subject to 31 writable registers. Long vectors cannot all remain resident.
The single data-memory port and conservative no-overtaking policy prevent a
naive stream from sustaining 400 MMAC/s. Memory changes are outside this plan.

## Verification matrix and cycle contracts

Use a signed reference model with explicit 16-, 17-, 18-, and 32-bit casts.

| Area | Required coverage |
| --- | --- |
| Lane arithmetic | All-positive, all-negative, mixed-sign, zeros, unique lane order. |
| Limits | `+127`, `-128`, all sign combinations, and no product truncation. |
| Sum range | Maximum +65,536 (`0x0001_0000`), maximum negative -65,024 (`0xffff_0200`), and cancellation to zero. |
| Accumulator | Positive/negative cases and modulo wrapping around `0x7fff_ffff`, `0x8000_0000`, zero, and `0xffff_ffff`. |
| DOT dependencies | Back-to-back same-`rd`, independent DOTs, interleaved WAW stall, and DOT result used as younger `rs1/rs2`. |
| Scalar dependencies | Scalar-to-DOT and DOT-to-scalar for all source roles. |
| LOAD | Immediate dependencies for `rs1`, `rs2`, and accumulator. |
| Side effects | DOT-to-STORE, DOT-to-BEQ taken/not taken, `x0`, invalid opcodes. |
| Control | Taken older branch, younger branch held, stage-by-stage reset, enable pause/resume. |
| Equivalence | One DOT equals four ordered MAC8 operations and scalar reference modulo `2^32`. |

Focused cycle contracts, measured from EX issue edge:

- isolated DOT writes and retires exactly at `I+3`;
- four independent or same-accumulator DOTs issue at `I..I+3` and retire at
  `I+3..I+6`;
- a dependent scalar/STORE/BEQ remains held through last completion and enters
  ID/EX on the following enabled cycle;
- DOT `rs1/rs2` RAW issue waits until its pending producer completes;
- each immediate LOAD-to-DOT role produces exactly one load-use bubble; and
- reset before completion produces no later write or retirement.

Integration acceptance also preserves the 83-check MAC8 result, 2,793-check
Phase 12 result, 457 cycles, 319 retired instructions, complete XSim regression,
and `0xfffffff2` dot-product result.

## Staged implementation roadmap

### Stage A: encoding and reference contract

Stage A1 status: complete. Opcode `4'hc` is reserved in the shared package
without adding it to shared validity predicates. The canonical encoder,
explicit-width arithmetic reference, independent sequential comparison model,
and historical-core invalid-opcode coverage are integrated into XSim.

- Files: `docs/isa.md`, `rtl/cpu_defs_pkg.sv`, a new focused DOT testbench, and
  the Phase 12 invalid-opcode case.
- Work: reserve `4'hc`, add canonical encoder/reference helpers and all
  arithmetic vectors. Do not make a CPU execute DOT yet.
- Tests: package/helper compile, explicit range checks, historical-core reject.
- Gate: exact widths pass and no historical behaviour changes.
- Reject if: `4'hc` gains another use or implicit expression sizing remains.

### Stage B: isolated arithmetic pipeline — complete (Stage A2)

- Files: `rtl/dot4acc_pipeline.sv` and `tb/tb_dot4acc_pipeline.sv`.
- Interface: `clk`, synchronous active-high `rst`, global clock-enable
  `enable`, `input_valid`, 32-bit `accumulator`, `packed_a`, and `packed_b`,
  with registered `output_valid` and 32-bit `result`.
- Work: stage 1 registers four signed 16-bit products and the accumulator;
  stage 2 registers two signed 17-bit pair sums and the aligned accumulator;
  stage 3 forms a signed 18-bit dot sum, explicitly sign-extends it, and
  registers the modulo-`2^32` signed 32-bit accumulator result.
- Measured contract: an accepted input uses the acceptance edge as stage
  advance 1 and asserts `output_valid` on stage advance 3. Disabled clocks do
  not advance any valid or payload state. The initiation interval is one.
- Verification: 2,859 checks passed with zero failures; 420 operations were
  accepted, 415 completed in order, and 5 were intentionally discarded by
  reset. Directed arithmetic, continuous traffic, bubbles, freezes, reset,
  and 700 deterministic stress cycles all passed against the Stage A1 oracle.
- Isolated synthesis: Vivado 2026.1 synthesized the module for
  `xc7a35tcpg236-1` with no latches, 50 slice LUTs, 99 flip-flops, and four
  DSP48E1 blocks. This is synthesis-only resource evidence, not routed timing.
- Isolation: no CPU core, decoder, register file, hazard path, forwarding path,
  writeback selector, or retirement path includes the Stage A2 module.

### Stage C: issue, dependency, and flush integration — complete

- Files: copied experimental `rtl/cpu_core_pipeline_dot4acc_issue.sv` and
  focused `tb/tb_cpu_core_pipeline_dot4acc_issue.sv`. The verified MAC8 cores
  and `rtl/dot4acc_pipeline.sv` are unchanged.
- Canonical decode: only opcode `4'hc` with zero `[12:0]` is accepted in the
  experimental core. DOT controls have `reg_write`, memory, branch, and jump
  effects cleared and DOT valid is explicitly suppressed from EX/MEM.
- Issue acceptance: `enable && !rst && id_ex_is_dot && dot_operands_ready &&
  !ex_redirect_taken && !redirect_pending_valid`. The issue path accepts one
  operation on every advancing clock and registers both packed inputs, the
  selected accumulator basis, `rd`, eligibility, and chain metadata.
- Forwarding/readiness: existing EX/MEM non-LOAD and MEM/WB forwarding select
  each of `rs1`, `rs2`, and old `rd`. LOAD dependencies retain the existing
  one-bubble rule for all three roles. A completion-stage DOT result can feed a
  waiting DOT-only source; matches in the issue/product/sum metadata stages
  stall. Every comparison ignores `x0` as a writable destination.
- Fixed-depth tracking: valid, nonzero destination, eligibility, and chain
  state advance through issue plus three metadata slots in lockstep with the
  arithmetic pipeline and freeze under global `enable`.
- Ordering: contiguous DOT instructions may proceed. A younger non-DOT is held
  as soon as an older DOT occupies ID/EX or any DOT metadata slot and is
  released only after the last completion observation drains. This also holds
  younger fast jumps, branches, LOADs, STOREs, and scalar side effects.
- Redirect/reset: an older EX redirect wins before issue, while the conservative
  hold policy prevents a younger control transfer from overtaking an accepted
  DOT. Reset clears issue, all metadata, arithmetic valid state, chain state,
  and hold state. Cancelled pre-issue DOTs never produce eligible metadata.
- Result boundary: issue at advancing edge `I` becomes an aligned result and
  destination observation at `I+3`; no Stage C signal drives architectural
  writeback, memory, retirement, redirect, or retired-instruction counters.
- Stage C limitation: release after observation proves ordering/control but
  cannot make a younger scalar consumer see the DOT value because writeback is
  intentionally absent. Focused younger non-DOT tests are dependency-free;
  dependent architectural consumers become executable only in Stage D.
- Verification: 1,468 checks passed with zero failures. The run accepted 128
  transactions, completed 123, intentionally reset-flushed 5, and observed 26
  younger DOT cancellations before issue. Independent and eight-member chains
  demonstrated II=1; the deterministic mixed-control stress phase ran 520
  wall-clock cycles with enable freezes and resets.

The original D3 proposal required an immediately preceding final result at the
Stage A2 pipeline input. That value cannot exist two clocks before the fixed
Stage A2 output and the Stage A2 interface has no late accumulator port. Stage
C therefore uses an ordered completion-side recurrence without changing the
arithmetic RTL. A chain head carries `A0`; each continuation carries accumulator
zero and produces raw `doti`. Ordered observation computes `A1=A0+dot0`, then
`A2=A1+dot1`, then `A3=A2+dot2`. Consecutive completions make this recurrence
II=1 while preserving modulo-`2^32` mathematical order.

### Stage D: writeback and retirement — complete

- Files: `rtl/cpu_core_pipeline_dot4acc_wb.sv`,
  `tb/tb_cpu_core_pipeline_dot4acc_wb.sv`, and
  `programs/dot4acc_stage_d.mem`. The Stage C core and all historical cores
  remain unchanged.
- Write-port arbitration: `normal_wb_valid` represents a writable MEM/WB
  result and `dot_wb_valid` represents an eligible, non-`x0` DOT completion.
  One explicit selector drives the existing register-file write enable,
  address, and data. The requests are structurally mutually exclusive: an
  immediately older normal instruction writes at least three enabled edges
  before DOT architectural completion, and the conservative hold prevents a
  younger non-DOT from reaching MEM/WB. A simulation assertion rejects any
  violation; no priority-based loss mechanism is used.
- Architectural completion: issue acceptance at edge `I` produces arithmetic
  observation at `I+3` and exactly one writeback/retirement event at `I+4`.
  Global disable freezes the completion and defers consumption; reset flushes
  it. The retirement event carries the original PC, opcode, `rd`, logical
  result, valid state, and write eligibility.
- `x0`: a valid `DOT4ACC x0,...` is computed, retires, and increments the
  retired-instruction counter once, but never requests the write port and
  never opens or continues an accumulator chain.
- Chains: Stage C already exposes one ordered logical result for every chain
  member. Stage D writes and retires `A1`, `A2`, ... on consecutive enabled
  edges, so every instruction has defined architectural completion and the
  final register value is the full recurrence. Issue II remains one.
- Consumer visibility: the younger non-DOT hold includes the completion slot
  through its consumption edge. A released scalar, STORE, or branch therefore
  reads the newly committed register value naturally; no additional global
  DOT-to-scalar forwarding mux is required. Waiting DOT-only operands retain
  the Stage C completion forwarding path.
- Verification: the focused Stage D test passed 3,945 checks with zero
  failures. It accepted 140 DOTs, retired 133, and accounted for seven reset
  flushes. Signed arithmetic, `x0`, normal/DOT arbitration, independent and
  same-`rd` II=1 streams, dependent scalar and DOT consumers, redirects,
  reset, completion freeze, and 520-cycle mixed stress all passed. The compact
  executable program retired a two-DOT chain and stored `0x000000ac` in 18
  preliminary functional cycles.
- Optional synthesis-only structure: 2,162 LUTs, 2,471 FFs, two RAMB18E1s,
  five DSP48E1s, and zero latches, with zero errors and zero critical warnings.
  All four DOT DSPs retain `AREG=1` and `BREG=1`, so Stage D has not created a
  direct forwarding-to-DSP input path. This is not placed or routed timing
  evidence.

### Stage E: synthesis and DSP mapping

- Files: new experimental top, copied flow, compact reports.
- Work: synthesize for `xc7a35tcpg236-1`; inspect primitives and registers.
- Tests: DRC, netlist hierarchy, DSP properties, utilization, stage timing.
- Gate: four DOT DSPs plus existing MAC8 DSP, one BRAM, no latches, explained
  resource totals.
- Reject if: cross-lane packing appears, multipliers map unexpectedly, or MAC8
  mapping changes.

### Stage F: post-route timing

- Files: new resumable sweep flow, compact CSV/report, documentation links.
- Work: repeat 100 MHz routes first, then characterize the boundary without
  overwriting MAC8 evidence.
- Tests: setup/hold, routes, bitstreams, resources, path reports, XSim, and
  publication checks.
- Gate: every required 100 MHz run passes setup/hold with zero endpoints and no
  material branch/MAC8 path regression.
- Reject if: 100 MHz is not repeatable or DOT logic enters a protected path.

## Risks and mitigations

- **Tree timing:** keep logic local; add another register if 100 MHz fails.
- **Accumulator recurrence:** allow II=1 only for contiguous chains; stall
  interleaved matching destinations.
- **Scoreboard omissions:** compare every valid stage and assert issue safety.
- **Write collision:** prove mutual exclusion; never rely on priority loss.
- **Control regression:** register/localize hold state and compare routed paths.
- **DSP inference:** inspect primitives and register properties after synthesis.
- **Memory limit:** document the no-overlap cost; do not broaden this phase.
- **Valid loss/duplication:** count issue, completion, write, and retirement at
  every reset, pause, and redirect position.

## Stage D completion and exact next-stage recommendation

Stage A1 is complete: opcode `4'hc`, the canonical zero-reserved-field encoder,
the width-explicit reference model, the independent sequential model, and
historical-core invalid-opcode checks are verified in XSim.

Stage A2 is complete as an isolated, three-stage, II=1 arithmetic pipeline.
Stage C remains complete in its copied issue-only core. Stage D is complete in
the separate writeback successor: one collision-asserted selector drives the
single register-file write port, every eligible completion writes once, every
valid completion retires and increments the counter once, and aligned
PC/opcode/`rd`/result metadata is preserved. Same-`rd` chains retain issue II=1
and retire one logical accumulated result per instruction. DOT-to-scalar
consumers observe the committed value after the conservative hold releases.

The exact next stage is full architectural benchmarking plus post-route
timing/Fmax characterization of `cpu_core_pipeline_dot4acc_wb`: run meaningful
packed-dot and chain workloads against scalar and MAC8 baselines, then perform
repeatable 100 MHz implementation and a bounded Fmax sweep while reporting
setup/hold, resource use, critical paths, and DSP register placement. Do not
change instruction semantics or broaden into caches, DMA, scratchpads, or
additional SIMD operations during that characterization stage.
