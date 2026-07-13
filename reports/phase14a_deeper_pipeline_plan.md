# Phase 14A Deeper Pipeline Architecture Plan

## Purpose

Phase 14A plans a future deeper pipeline version of the custom-ISA CPU. It is documentation-only: no RTL, testbench, program, constraint or Vivado implementation file is changed in this phase.

The goal is to define a realistic next architecture that could beat the current Phase 13I result and move toward 90+ practical estimated MIPS, while preserving architectural correctness.

## Baseline Summary

Current preferred measured result:

| Metric | Current best |
| --- | ---: |
| Preferred RTL architecture | Phase 13E forwarding-timing pipeline |
| Preferred implementation result | Phase 13I `fanout_opt` strategy |
| Pipeline shape | IF -> ID -> EX -> MEM -> WB |
| Verified period | 8.650 ns |
| Verified Fmax | 115.607 MHz |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| CPI | 1.339 |
| Practical estimated MIPS | ~86.4 |
| LUTs | 1,363 |
| FFs | 1,510 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| 90 MIPS reached | No |

Phase 13I is currently the preferred measured implementation. A Phase 14 deeper pipeline should only replace it if it improves practical estimated MIPS above about 86.4, and ideally reaches 90+ MIPS.

## Motivation

Phase 13 improved the pipelined CPU mostly through focused control-flow changes, forwarding-path restructuring and Vivado implementation strategies. These optimisations are now reaching diminishing returns because the remaining timing paths are not simple instruction-fetch paths.

The recurring timing family involves:

- data-memory or load-result timing;
- writeback result selection;
- WB-to-ID bypass;
- EX-stage forwarding metadata;
- decode and hazard-control signals;
- ID/EX operand and control register enables/resets.

Phase 13I improved placement and fanout handling without changing RTL, but the critical path still passes through data-memory/writeback and frontend or ID/EX control. A deeper pipeline may improve Fmax by splitting operand preparation, bypass selection and execute work across two stages instead of concentrating it around ID/EX and EX.

The risk is that extra stages can increase CPI through additional branch, jump or load-use penalties. The deeper pipeline only wins if the Fmax gain is larger than the CPI cost.

## Proposed Six-Stage Pipeline

Current Phase 13 pipeline:

```text
IF -> ID -> EX -> MEM -> WB
```

Proposed Phase 14 pipeline:

```text
IF -> ID -> OP -> EX -> MEM -> WB
```

| Stage | Name | Main responsibility |
| --- | --- | --- |
| IF | Instruction fetch | Issue instruction BRAM request, track request PC, accept synchronous response, maintain fetch buffering and redirect invalidation. |
| ID | Decode | Decode opcode, register indexes, immediate, validity and basic control bits. Avoid wide operand muxing here where possible. |
| OP | Operand preparation | Read register operands, prepare bypass/forwarding selects, apply or stage selected operands, prepare store data and branch operands. |
| EX | Execute | ALU operation, address calculation, BEQ comparison and redirect generation using prepared operands. |
| MEM | Memory | Data BRAM read/write request and memory metadata tracking. |
| WB | Writeback | Register writeback, retirement event generation and performance counter updates. |

The new OP stage is intended to move operand-read, bypass preparation and forwarding-selection pressure out of the current ID/EX boundary. The EX stage should then receive cleaner operands and control metadata, reducing the length and fanout of timing paths into execute and operand registers.

## Pipeline Register Plan

### IF/ID

Likely fields:

- valid bit;
- PC associated with the returned instruction;
- instruction word;
- fetch/response metadata needed for redirect invalidation;
- optional wrong-path generation or epoch tag if later needed.

Purpose:

- separate synchronous instruction BRAM response handling from decode;
- ensure stale or wrong-path responses never become valid instructions.

### ID/OP

Likely fields:

- valid bit;
- PC;
- instruction;
- opcode;
- rd, rs1, rs2;
- sign-extended immediate;
- decoded control signals;
- valid-instruction flag;
- register-use metadata such as uses_rs1 and uses_rs2;
- writeback metadata such as writes_rd and mem_to_reg;
- memory/control metadata such as mem_read, mem_write, branch and jump.

Purpose:

- keep decode simple and registered;
- pass stable register indexes and control into OP;
- prevent invalid opcodes from causing side effects.

### OP/EX

Likely fields:

- valid bit;
- PC;
- opcode;
- rd, rs1, rs2;
- sign-extended immediate;
- operand A;
- operand B;
- store data;
- branch compare operands;
- forwarding/source metadata if final selection remains in EX;
- decoded control signals;
- wrong-path safety metadata.

Purpose:

- provide EX with stable operands and control;
- reduce route-heavy timing from WB/load result paths into ID/EX;
- keep STORE data and branch operands aligned with the instruction.

### EX/MEM

Likely fields:

- valid bit;
- PC;
- opcode;
- rd;
- ALU result;
- effective address;
- store data;
- branch/jump decision metadata;
- memory read/write controls;
- writeback controls;
- wrong-path/flush safety metadata.

Purpose:

- hold ALU result and memory request information;
- ensure wrong-path STOREs are blocked before memory commit;
- provide newest ALU forwarding source for younger instructions.

### MEM/WB

Likely fields:

- valid bit;
- PC;
- opcode;
- rd;
- ALU result;
- loaded memory data or load-response metadata;
- register-write control;
- memory-write retirement metadata;
- writeback data selection metadata;
- retirement safety metadata.

Purpose:

- perform architectural writeback;
- generate exactly one retirement event per valid instruction;
- provide MEM/WB forwarding source.

## Forwarding Strategy

### Option A: Forwarding Mostly Prepared In OP

In this option, OP selects or prepares the newest operand values before EX.

Advantages:

- EX receives cleaner operands;
- ALU, address calculation and branch comparison can be shorter;
- the current ID/EX operand/control timing family may be reduced.

Risks:

- OP may become the new critical path;
- load-result and writeback data may still need to reach OP quickly;
- branch operand forwarding must remain correct;
- the design may require more careful load-use interlocks.

### Option B: Forwarding Mostly Done In EX

In this option, OP passes raw operands and register IDs, while EX applies forwarding muxes.

Advantages:

- closer to the current verified Phase 13 implementation;
- lower risk of changing architectural behaviour;
- easier to reuse existing forwarding tests and mental model.

Risks:

- EX may remain timing-heavy;
- the extra OP stage may not improve Fmax enough;
- the current writeback/load-result path may still feed a long EX mux path.

### Recommendation

The safer first implementation strategy for Phase 14B/C is a hybrid biased toward Option B:

1. Add the six-stage skeleton with explicit ID/OP and OP/EX registers.
2. Move decode and register-index/control preparation into ID.
3. Move register read and simple bypass-select precomputation into OP.
4. Keep final EX/MEM and MEM/WB forwarding priority decisions close to EX at first.
5. Only move more forwarding into OP after simulation passes and timing reports show EX remains dominant.

This reduces implementation risk while still giving the architecture a new register boundary where the current Phase 13 timing family is likely too dense.

## Load-Use Hazard Strategy

LOAD followed by a dependent instruction remains the most important data hazard.

The target is to preserve a one-cycle load-use stall if possible:

```text
LOAD x1, [base + offset]
ADD  x2, x1, x3
```

The hazard detector should stall only when the following instruction actually uses the loaded register. It should use opcode helper functions such as `opcode_uses_rs1`, `opcode_uses_rs2` and `opcode_writes_rd`, and should ignore x0.

Possible outcomes:

- Best case: one-cycle load-use stall remains possible because OP can hold the dependent instruction until load data can be forwarded.
- Risk case: synchronous BRAM timing plus the added OP stage requires a two-cycle load-use penalty.

A two-cycle load-use penalty may reduce CPI enough to cancel the Fmax improvement. Phase 14 should measure this directly with the same aggregate benchmark used in Phase 13.

## Control-Flow Strategy

The first deeper pipeline should keep control flow conservative:

- no branch prediction;
- no target buffer;
- no cache;
- no speculative execution beyond existing simple fetch behaviour;
- BEQ comparison remains in EX or the equivalent execute stage;
- JUMP target handling should remain simple and timing-safe;
- BEQ and JUMP redirects flush all younger wrong-path stages;
- wrong-path STOREs must not commit;
- wrong-path register writes must not retire.

The added OP stage may increase the number of younger stages behind a redirect. This can increase control penalty unless the redirect path is carefully managed. Correctness has priority over CPI.

## Retirement And Safety Rules

The deeper pipeline must preserve the existing architectural rules:

- each valid instruction retires exactly once;
- hardware bubbles never retire;
- wrong-path instructions never retire;
- wrong-path STOREs never commit;
- wrong-path register writes never occur;
- x0 remains permanently zero;
- invalid opcodes remain safe and cause no architectural side effects;
- branch and jump targets use the existing custom-ISA convention;
- performance counters count real architectural events, not bubbles or flushed work;
- instruction and data memories remain synchronous BRAM-compatible.

The retirement interface should remain explicit so performance and correctness can be measured independently of internal pipeline timing.

## Expected Performance Model

Use the same project formula:

```text
Practical MIPS = Fmax / CPI
```

Possible outcomes:

| Fmax | CPI | Practical MIPS | Interpretation |
| ---: | ---: | ---: | --- |
| 115.607 MHz | 1.339 | 86.4 | Current Phase 13I baseline. |
| 125 MHz | 1.40 | 89.3 | Better Fmax, but still below 90 MIPS. |
| 126 MHz | 1.40 | 90.0 | Reaches 90 MIPS if CPI stays near 1.40. |
| 130 MHz | 1.45 | 89.7 | Fmax gain mostly cancelled by CPI penalty. |
| 135 MHz | 1.45 | 93.1 | Strong result if deeper pipeline reaches this Fmax. |
| 140 MHz | 1.55 | 90.3 | Timing gain can still win with larger CPI penalty, but verification and control penalties become more concerning. |

The deeper pipeline is not automatically better. It should replace Phase 13I only if measured CPI and post-route Fmax produce a higher practical MIPS value.

## Phase 14 Implementation Roadmap

| Phase | Goal | Acceptance evidence |
| --- | --- | --- |
| Phase 14B | Six-stage skeleton and pipeline registers | Reset, enable, sequential fetch, valid-bit movement, bubbles, no side effects. |
| Phase 14C | Arithmetic execution and basic forwarding | ADD/SUB/AND/OR/XOR/ADDI pass; x0 protection; ALU dependency tests pass. |
| Phase 14D | LOAD/STORE and load-use stalls | Memory offset tests pass; STORE data forwarding; measured load-use penalty. |
| Phase 14E | BEQ/JUMP redirects and wrong-path protection | Taken/not-taken BEQ, JUMP, backward loop, wrong-path STORE/register-write protection. |
| Phase 14F | Full custom-ISA regression and CPI measurement | Phase 6/13-style full benchmark passes; cycles, retired count and CPI reported. |
| Phase 14G | Vivado implementation, timing sweep and MIPS comparison | BRAM inference, WNS/TNS/WHS, bitstream, resources, Fmax and practical MIPS compared with Phase 13I. |

## Success Criteria

The deeper pipeline should only replace Phase 13I if all of the following are true:

- full XSim regression passes;
- retired instruction count remains correct;
- no instruction is lost, duplicated or incorrectly retired;
- practical MIPS is greater than about 86.4;
- ideally practical MIPS reaches 90+;
- post-route timing passes with WNS >= 0 and TNS = 0 at the claimed period;
- hold timing passes;
- bitstream generation passes;
- BRAM inference is retained;
- resource usage remains reasonable;
- no custom ISA encoding or program format changes are introduced.

## Risks And Fallback

Main risks:

- forwarding complexity increases;
- OP becomes the new critical path;
- CPI increases due to additional load-use or control penalties;
- branch penalty increases because more younger stages must be flushed;
- verification becomes harder because more stage-valid combinations exist;
- route pressure may move rather than disappear;
- added FFs and control logic may reduce Fmax or increase resources.

Fallback:

- keep Phase 13I as the preferred measured implementation if Phase 14 does not beat about 86.4 MIPS;
- reject any deeper-pipeline change that improves Fmax but loses more through CPI;
- preserve Phase 13E/13I files as the stable comparison baseline.

## Conclusion

Phase 14 should explore a six-stage IF -> ID -> OP -> EX -> MEM -> WB pipeline because Phase 13 timing work is now limited by operand/writeback/forwarding/control paths around ID/EX and data memory. The proposed OP stage gives a clear architectural place to split that work.

The plan is promising but not guaranteed. The deeper pipeline must prove itself through the same evidence standard as Phase 13: full simulation, post-route timing, measured CPI and practical MIPS.
