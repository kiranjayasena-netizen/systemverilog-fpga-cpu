# DOT4ACC Stage G Timing-Architecture Recovery

Status: **partial recovery; 100 MHz not yet closed**

Stage G preserved the Stage D baseline and tested measured, isolated control
transformations against the Stage F routed reference. The best candidate removes
the original DOT chain-control critical path and improves 100 MHz WNS from
`-0.348 ns` to `-0.004 ns`, but it does not meet the required 5/5 100 MHz pass
criterion. A second candidate worsened timing and was rejected.

## Fixed baseline

Stage F baseline:

| Candidate | 100 MHz WNS | TNS | Setup endpoints | Hold WNS | Result |
| --- | ---: | ---: | ---: | ---: | :--- |
| Stage F | -0.348 ns | -2.091 ns | 6 | +0.058 ns | FAIL |

The Stage F default flow uses Vivado 2026.1, part `xc7a35tcpg236-1`, the real
Basys 3 XDC, and default `synth_design`, `opt_design`, `place_design`, and
`route_design` with no `phys_opt_design`, special directives, floorplanning, or
manual placement. The Stage F reference passes 98 MHz 5/5 and fails 99 MHz 5/5.

## G1 hypothesis and transformation

The Stage F 100 MHz path was:

```text
data BRAM -> LOAD forwarding -> BEQ comparison -> redirect cancellation
-> dot_chain_open/dot_chain_rd state reset
```

The original sequential logic gave `redirect_taken` direct control of
`dot_chain_open_reg` and `dot_chain_rd_reg`, even though decoded non-DOT
instruction contiguity already terminates a chain before an ordinary branch or
jump can resolve its EX redirect.

G1 changed only the copied experimental core
`rtl/cpu_core_pipeline_dot4acc_timingopt.sv`: chain state is now opened by a
DOT acceptance and closed by the existing decoded non-DOT boundary. Redirect
and fetch cancellation logic is unchanged. DOT arithmetic, issue acceptance,
forwarding, writeback, retirement, pipeline latency, and chain recurrence are
unchanged.

G1 added the simulation-only invariant:

```systemverilog
assert property (@(posedge clk) disable iff (rst)
                 id_ex_is_dot |-> !ex_redirect_taken);
```

The focused testbench also checks taken and not-taken branches around a same-rd
chain and confirms that wrong-path DOTs are cancelled and post-branch DOTs do
not retain continuation metadata.

## G1 functional result

The copied Stage G testbench passed **4,258 checks with 0 failures**. It includes
the complete Stage D suite plus the new G1 chain/redirect tests.

Observed G1 executable-program result remained 18 cycles and `0x000000ac`.
Same-rd chains, independent DOT streams, reset, freeze, cancellation, scalar
consumers, LOAD dependencies, and retirement ordering remained unchanged.

## G1 routed result

One clean default-flow 100 MHz implementation was run.

| Candidate | WNS | TNS | Setup endpoints | Hold WNS | Pulse WNS | LUT | FF | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| Stage F | -0.348 ns | -2.091 ns | 6 | +0.058 ns | +4.500 ns | 1,816 | 1,705 | FAIL |
| G1 | -0.004 ns | -0.004 ns | 1 | +0.034 ns | +4.500 ns | 1,829 | 1,706 | FAIL |

G1 removed the original BRAM→BEQ→redirect→DOT-chain endpoint. The new worst
path is the inherited MAC8 path:

```text
data BRAM CLKARDCLK
→ MAC8 DSP48E1
→ EX/MEM alu_result register
```

Measured G1 path data delay is 9.915 ns, with 6.667 ns logic delay, 3.248 ns
route delay, four logic levels, and `-0.004 ns` slack. The MAC8 DSP is at
`DSP48_X0Y4`.

## G2 investigation and rejection

G2 qualified DOT completion forwarding with `id_ex_is_dot`, based on the fact
that younger scalar instructions are held while DOT metadata drains. This was
architecturally safe in the focused tests, but the routed result worsened:

| Candidate | WNS | TNS | Setup endpoints | Hold WNS | LUT | FF | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| G2 | -0.181 ns | -1.889 ns | 26 | +0.034 ns | 1,826 | 1,705 | REJECTED |

G2 also brought the original DOT chain-state path back as the absolute limiter.
The G2 changes were reverted; the retained Stage G source is the G1 candidate.

## DOT arithmetic and resources

The G1 routed design retains five DSP48E1s: one MAC8 and four DOT DSPs. The
four DOT DSPs retain `AREG=1`, `BREG=1`, and `PREG=1`; pair DSPs retain `MREG=1`
and product DSPs retain `MREG=0`. The worst through-DOT-DSP path remains
positive in the Stage F evidence, and G1 did not alter `dot4acc_pipeline.sv`.

G1 routed resources:

```text
1829 LUT
1706 FF
2 RAMB18E1
0 RAMB36E1
5 DSP48E1
1 BUFG
0 latches
```

## Functional preservation

The final post-G1 complete XSim regression passed with exit code 0 in 332
seconds. Invariants remain:

```text
Stage A1: 306/0
Stage A2: 2859/0
Stage C: 1468/0
Stage D: 3945/0
Stage G1 focused: 4258/0
Stage E: 233/0
MAC8: 83/0
Phase 12: 2796/0
historical aggregate: 457 cycles, 319 retired instructions
historical benchmark: 29/19 cycles, 0xfffffff2
```

Stage E cycle invariants remain 27 cycles at N=64, 43 cycles at N=128, and
II=1 for same-rd chains. No Stage E workload or arithmetic implementation was
changed.

## Constraints and implementation hygiene

The G1 implementation used the same Basys 3 XDC, clock override, device, and
default directives as Stage F. It routed successfully, generated a bitstream,
passed hold and pulse-width timing, and reported zero errors and zero critical
warnings. No false-path, multicycle, special-route, placement, or floorplan
constraint was introduced.

## Decision and remaining limitation

G1 is retained as a useful functionally equivalent candidate because it removes
the DOT-specific control bottleneck and comes within 4 ps of 100 MHz. It is not
Stage G-complete: there is no 5/5 100 MHz pass and no new Fmax sweep is claimed.
The inherited MAC8 DSP path is now the measured blocker. G2 showed that a naive
completion-forwarding mux qualification is counterproductive under routing.

## Exact next-stage recommendation

Continue with one narrow timing study focused on the inherited MAC8
BRAM→DSP→EX/MEM path, reusing previously proven MAC8 timing techniques only if
they preserve the 29/19-cycle benchmark and all DOT timing invariants. Do not
start Stage H memory-feed or Stage I hold-policy work until repeatable 100 MHz
closure is recovered.

## Stage G3.1 update

G3.1 added an 8-bit MAC8-specific operand-A selection path while leaving the
general `ex_operand_a` path unchanged. The exact G1 path was BRAM `DOADO[7]`
at `RAMB18_X0Y2` through `ex_operand_a[7]` into MAC8 DSP
`cpu_inst/ex_alu_result0/A[28]` at `DSP48_X0Y4`, then to the EX/MEM result
register. It measured `9.915 ns` data delay (`6.667 ns` logic and `3.248 ns`
routing) at `-0.004 ns` WNS.

Assertions prove that valid MAC8 cannot overlap a writable DOT completion on
`rs1`, and that the dedicated low-byte selection equals the original
`ex_operand_a[7:0]` for valid MAC8 EX states. G3.1 passed the full functional
regression and preserved the Stage E cycle invariants.

Five clean 100 MHz implementations passed identically: WNS `+0.111 ns`, TNS
`0.000 ns`, hold WNS `+0.084 ns`, zero setup endpoints, zero hold endpoints,
1,818 LUTs, 1,704 FFs, two RAMB18E1s, and five DSP48E1s. The critical family
remains BRAM -> MAC8 DSP A port -> EX/MEM, but it now passes at 100 MHz.

The bounded sweep produced one-run failures at 101 MHz (`-0.230 ns`), 102 MHz
(`-0.152 ns`), 103 MHz (`-0.107 ns`), 104 MHz (`-0.148 ns`), and 105 MHz
(`-0.036 ns`). The 101 MHz
follow-up repeatability run was interrupted before completion, so 100 MHz is
the highest repeatable passing point and 101 MHz is reported as the first
observed failing point, not a separately repeatability-certified failure.

G3.1 satisfies the required 100 MHz recovery. The next stage is Stage H
memory-feed optimisation; it is not implemented here.
