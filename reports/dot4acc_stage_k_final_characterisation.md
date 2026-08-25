# Stage K — Final CPU Characterisation and Freeze

## Objective and selected design

Stage K consolidates the finished CPU rather than introducing another
optimization. The selected functional architecture is H1.3b and the selected
timing-equivalent RTL is `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
with top `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`.
No synthesizable RTL, constraints, or memory sizes were changed in Stage K.

## Regression confirmation

The retained individually completed regression results are A1 306/0, A2
2859/0, C 1468/0, D 3945/0, Stage G 4258/0, Stage H 4254/0, and Stage E
233/0. MAC8 remains 29 scalar cycles versus 19 MAC8 cycles with result
`0xfffffff2`; Phase12 remains 457 cycles and 319 retired instructions.

The Stage J testbench was rerun against T2 and passed: J1 N=32/64/128 and J2
2×64 all matched their independent signed-int8 golden references.

## Frozen Stage H and Stage J performance

Stage H memory-fed results are 39/71/135/263 cycles for N=16/32/64/128,
exactly `8K+7`. At N=128 there are 31 second-LOAD admissions, transfers,
BRAM reads, and deferred completions, with zero duplicate or lost completions.
Register-resident DOT remains 27 cycles at N=64 and 43 at N=128; same-rd DOT
remains II=1.

Stage J application results are:

| Workload | Cycles | Useful MACs | Retired | MAC/cycle | MMAC/s @93 MHz | Golden result |
|---|---:|---:|---:|---:|---:|---|
| J1 N=32 | 94 | 32 | 41 | 0.340426 | 31.6596 | `000057ba` |
| J1 N=64 | 182 | 64 | 81 | 0.351648 | 32.7033 | `000024e5` |
| J1 N=128 | 358 | 128 | 161 | 0.357542 | 33.2514 | `000028e5` |
| J2 2×64 | 331 | 128 | 134 | 0.386707 | 35.9637 | `000024e5`, `0000bf7b` |

The full J1 N=128 program is 95 cycles above the 263-cycle Stage H microkernel
because it includes a second data stream and explicit scalar pointer updates.

## Physical evidence

The retained T2 implementation was physically validated on
`xc7a35tcpg236-1` with Vivado 2026.1 at 93 MHz, PASS 5/5. The final recorded
result is WNS +0.230 ns, TNS 0, hold WNS +0.059 ns, with 2008 LUT, 1812 FF,
2 RAMB18, 5 DSP48, 1 BUFG, and 0 latches. The nearest tested higher point,
94 MHz, failed with WNS -0.257 ns and 118 setup failures; 100 MHz remains
unclosed. This is a highest repeatably validated frequency, not a mathematical
Fmax claim.

The limiting setup family is data BRAM → forwarding/operand selection →
DOT/control logic → ID/EX operand reset:

```text
cpu_inst/data_mem_inst/mem_reg/CLKARDCLK
    -> cpu_inst/id_ex_reg_reg[operand_b][16]/R
```

The path is 9.878 ns total (4.651 ns logic, 5.227 ns routing, 12 levels).
The worst hold path is EX/MEM store-data clock-to-data-BRAM input, with
WNS +0.059 ns.

## Timing-recovery history

| Candidate | WNS @100 MHz | TNS | Setup fails | Hold WNS | Decision |
|---|---:|---:|---:|---:|---|
| H1.3b T0 | -1.865 ns | -817.384 ns | 698 | +0.059 ns | rejected |
| T1 | -1.525 ns | -537.848 ns | 652 | +0.059 ns | rejected |
| T2 | -0.623 ns | -71.487 ns | 286 | +0.057 ns | selected |
| T3 | -0.920 ns | -233.654 ns | 454 | +0.110 ns | rejected |

T1 removed a late redirect qualification. T2 isolated branch control from
DOT-only deferred forwarding and became the best timing candidate. T3's
valid-only flush was functionally safe but physically worse. T4 was not
attempted because exact structural equivalence was not proven.

## Accepted and rejected architecture decisions

Accepted decisions are the four-lane pipelined DOT4ACC, II=1 same-rd chaining,
single RF write port, one deferred completion entry, atomic H1.3b second-LOAD
admission, in-order retirement, and the T2 branch/deferred-forwarding split.

Rejected decisions include H1.1/H1.2/H1.3a as performance-neutral candidates,
T3 as a timing candidate, Stage I scalar/DOT overlap (realistic benefit about
two cycles and insufficient for its timing risk), and the fully unrolled J2
4×128 workload (instruction memory capacity). These are measured trade-offs,
not unresolved architecture work.

## Final freeze declaration

```text
Functional architecture:              H1.3b
Physically characterised RTL:         H1.3b-T2
FPGA:                                 xc7a35tcpg236-1
Highest repeatably validated clock:  93 MHz, PASS 5/5
Nearest tested higher clock:         94 MHz, FAIL
Stage H N=128:                       263 cycles, 45.26 MMAC/s @93 MHz
Stage J J1 N=128:                    358 cycles, 33.2514 MMAC/s @93 MHz
Stage J J2 2x64:                     331 cycles, 35.9637 MMAC/s @93 MHz
Resources:                           2008 LUT, 1812 FF, 2 RAMB18,
                                     5 DSP48, 1 BUFG, 0 latches
Status:                              ARCHITECTURE FROZEN
```

Stage K is complete. Stage L has not begun.
