# Stage I — Mixed Scalar/DOT4ACC Overlap Study

## Outcome

**NO-GO — RTL NOT JUSTIFIED.** Stage I was completed as a measurement study
against the frozen H1.3b-T2 implementation. No architectural RTL, wrapper,
forwarding network, retirement mechanism, or timing structure was changed.
Stage H remains the final CPU architecture and is not reopened.

## Frozen Stage H reference

The reference is H1.3b/T2: memory-fed cycles 39/71/135/263 (`8K+7`), 31
second-LOAD admissions/transfers/BRAM reads/completions at N=128, register
DOT 27/43 cycles, same-rd II=1, and 93 MHz PASS 5/5 (`WNS +0.230 ns`, hold
`+0.059 ns`). The nearest tested failure is 94 MHz. Resources are LUT 2008,
FF 1812, RAMB18 2 and DSP48 5.

## Existing serialization rules

| Rule | Trigger | Blocks | Protection | Conservatism evidence |
|---|---|---|---|---|
| `dot_younger_non_dot_hold` | valid younger non-DOT while `dot_active`, except qualified LOAD/DOT cases | IF/ID and scalar advancement | prevents overtaking an accepted DOT and retirement/write-port conflicts | independent ADDI tests show 4–6 cycles of opportunity |
| `scalar_overlap_hold` | deferred completion, unless a ready DOT exception applies | MEM/WB/EX scalar movement | preserves one deferred completion slot and in-order retirement | no deferred hold occurred in these register-resident tests |
| `dot_issue_stall` | DOT operands not ready | waiting DOT in ID/EX | protects RAW/accumulator dependencies | zero in independent register tests |
| `decode_stall` / load-use | IF/ID uses an outstanding load result | decode/ID/EX | prevents stale LOAD operands | observed in the memory-mixed case |
| DOT destination checks | producer destination matches LOAD base/destination | candidate LOAD admission | prevents stale addresses and WAW/RAW conflicts | required architectural dependency |

The H1.2 exception is deliberately DOT-only. Non-DOT instructions remain
blocked while DOT state is active; this is the main Stage I measurement target.

## Measurement method

`tb/tb_dot4acc_stage_i_scalar_overlap.sv` instantiates the unmodified T2
core, loads each short program into its instruction BRAM, and samples
`dot_younger_non_dot_hold`, `scalar_overlap_hold`, `dot_issue_stall`,
`decode_stall`, issue/retirement counts and total cycles. The counting priority
is direct-signal attribution; a cycle can be counted in multiple diagnostic
columns, so total cycle reconciliation uses `total_cycles`, not a sum of
overlapping causes.

Benchmarks cover independent ADDI insertion (I-A), three independent ADDIs
(I-B), a DOT RAW negative control (I-C), memory-fed mixed work and a no-ADDI
control (I-D), branch mix (I-E), and an independent STORE (I-F).

| Benchmark | Cycles | Retired | Scalar hold | Decode/load stalls | Theoretical baseline | Avoidable upper bound |
|---|---:|---:|---:|---:|---:|---:|
| I-A independent ADDI | 19 | 4 | 10 | 0 | 13 | 6 cycles |
| I-B three independent ADDIs | 17 | 5 | 10 | 0 | 13 | 4 cycles |
| I-C DOT RAW | 15 | 3 | 10 | 0 | 13 | 0 cycles |
| I-D memory mixed | 21 | 7 | 10 | 2 | 19 | 2 cycles |
| I-D memory control | 19 | 6 | 9 | 1 | 19 | 0 cycles |
| I-E branch mix | 19 | 4 | 10 | 0 | 19 | 0 cycles |
| I-F independent STORE | 13 | 3 | 5 | 0 | 12 | 1 cycle |

The independent scalar sequences demonstrate that serialization is real, but
the recoverable benefit is only 4–6 cycles in short synthetic two-DOT tests
and approximately two cycles in the memory-shaped case and one in the store
case. The RAW and
branch controls correctly retain serialization. The upper bound is not an
implementable result: realizing it would require scalar completion/retirement
arbitration, additional dependency qualification, and careful interaction with
the single RF write port and one deferred completion entry.

## GO / NO-GO decision

NO-GO. The recurring independent-ADDI opportunity is measurable, but it is
small outside synthetic sequences and would add a new scalar completion/control
cone to a design with only 0.230 ns setup margin at the validated 93 MHz
frequency. The realistic memory-mixed case shows only two potentially
avoidable cycles relative to its no-ADDI control. A scalar overlap candidate
would therefore risk the frozen 93 MHz Stage H result without a proportionate
representative workload benefit.

No Vivado Stage I implementation was justified. Stage H remains frozen with
all established invariants: 39/71/135/263, exact `8K+7`, 31/31/31/31 with no
duplicate/lost completions, register 27/43, II=1, MAC8 29/19 with result
`0xfffffff2`, and Phase12 457 cycles/319 retired.

## Verification

The measurement TB compiled and passed in XSim (`STAGE_I_MEASUREMENT_PASS`).
The retained individual A1, A2, C, D, Stage G, Stage H/T2, Stage E, MAC8 and
Phase12 suites remain passing; no Stage I RTL existed to regress them. No
Stage I physical implementation, frequency sweep, or timing claim was made.

Stage I is complete as a measurement-only NO-GO result. Stage J has not begun.
