# Phase 14F Six-Stage Pipeline Full Program Verification

## Purpose

Phase 14F verifies the separate Phase 14 six-stage pipeline against a compact full custom-ISA program and measures simulation performance. This phase combines arithmetic, memory, control flow, safety checks and CPI measurement in one program-style test.

Phase 14F does not run Vivado implementation and does not claim a Phase 14 MIPS result. The preferred measured implementation remains the Phase 13E forwarding-timing pipeline using the Phase 13I `fanout_opt` implementation strategy:

- Fmax: 115.607 MHz
- CPI: 1.339
- Practical estimated MIPS: ~86.4

## Files Added Or Modified

Added:

- `tb/tb_cpu_core_pipeline6_full_program.sv`
- `reports/phase14f_pipeline6_full_verification.md`

Modified:

- `scripts/run_xsim_regression.ps1`
- `README.md`
- `docs/verification.md`

No Phase 13E/13I preferred RTL files were modified.

## Full Program Coverage

The Phase 14F testbench directly initializes the instruction memory of `cpu_core_pipeline6` with a compact full-program sequence. The program covers:

- `ADDI`, including negative immediate sign extension
- `ADD`, `SUB`, `AND`, `OR`, `XOR`
- `LOAD` and `STORE`
- positive and negative signed memory offsets
- load-use arithmetic dependency
- load-use store dependency
- BEQ taken
- BEQ not taken
- forward JUMP
- backward JUMP loop
- wrong-path register-write protection
- wrong-path STORE protection
- invalid opcode safety
- NOP safety
- `x0` write protection
- pause/resume during in-flight pipeline execution

## Measurement Convention

Cycles are counted only while reset is released and `enable` is asserted. Deliberate pause cycles with `enable == 0` are excluded.

Retired instructions are counted from `debug_retire_valid`. Bubbles and invalid opcodes are not counted. Wrong-path flushed instructions are not counted. NOP is counted as a valid retired instruction, matching the Phase 14E convention.

CPI is calculated as:

```text
CPI = enabled cycles / retired instructions
```

## Results

Focused command:

```powershell
xvlog/xelab/xsim for rtl/cpu_defs_pkg.sv, rtl/bram_instr_mem.sv, rtl/bram_data_mem.sv, rtl/cpu_core_pipeline6.sv and tb/tb_cpu_core_pipeline6_full_program.sv
```

Focused transcript:

- `reports/simulation_transcripts/phase14f_pipeline6_full_program_focused_20260714_110746.txt`

Focused result:

- Checks run: 97
- Failures: 0
- Enabled cycles: 95
- Retired instructions: 58
- CPI: 1.638
- Branch redirects: 2
- Jump redirects: 3
- Total redirects: 5
- Flush pulses: 5
- Load-use stalls: 10
- Memory writes: 11

Full local regression command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Full regression transcript:

- `reports/simulation_transcripts/phase14f_full_xsim_regression_20260714_110824.txt`

Full regression result:

- Full local XSim regression completed successfully.
- The Phase 14F full-program test passed inside the full regression.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and all self-checking tests passed.

## Final Architectural Checks

Final register checks:

| Register | Expected | Purpose |
| --- | ---: | --- |
| `x0` | 0 | hard-zero protection |
| `x1` | 64 | memory base address |
| `x2` | 3 | loop accumulator |
| `x3` | 0 | loop counter |
| `x4` | 1 | loop step |
| `x5` | 1 | BEQ not-taken operand |
| `x6` | 4 | final loaded-plus-one result |
| `x7` | 44 | taken-BEQ target result |
| `x8` | 88 | JUMP wrong-path ADDI blocked |
| `x9` | 22 | JUMP target result |
| `x10` | 3 | final loaded accumulator |
| `x11` | 7 | load-use arithmetic result |
| `x12` | `0xffffffff` | negative immediate sign extension |
| `x13` | 123 | invalid opcode did not overwrite |

Final memory checks:

| Data word | Expected | Purpose |
| --- | ---: | --- |
| 16 | 3 | final loop accumulator |
| 17 | 3 | final loop result |
| 18 | 4 | final loaded-plus-one store |
| 19 | 7 | load-use arithmetic store |
| 20 | 0 | wrong-path STORE blocked |
| 21 | 6 | negative-offset LOAD result |

Additional safety checks:

- wrong-path BEQ STORE did not retire;
- wrong-path JUMP ADDI did not retire;
- invalid opcode did not retire;
- loop body retirement counts matched the expected repeated execution;
- no writeback targeted `x0`;
- no retire PC alignment failure occurred;
- no memory address alignment failure occurred;
- pause cycles produced no retirement, register write or memory write.

## CPI Comparison

| Implementation | Measured CPI | Notes |
| --- | ---: | --- |
| Phase 13I preferred measured pipeline | 1.339 | Current preferred result with post-route Fmax evidence |
| Phase 14F six-stage pipeline simulation | 1.638 | Full-program simulation only; no Phase 14 timing result yet |

The Phase 14F CPI is higher than the Phase 13I CPI. The deeper six-stage pipeline could still become preferable only if Phase 14G demonstrates enough post-route Fmax improvement to offset the CPI penalty.

## Hypothetical Sensitivity Only

These values are not measured Phase 14 performance results. They show what practical MIPS would be if a future Phase 14G implementation reached the listed Fmax with the Phase 14F CPI of 1.638.

| Hypothetical Fmax | Hypothetical MIPS |
| ---: | ---: |
| 120 MHz | 73.3 |
| 125 MHz | 76.3 |
| 130 MHz | 79.4 |
| 135 MHz | 82.4 |
| 140 MHz | 85.5 |
| 145 MHz | 88.5 |
| 150 MHz | 91.6 |

To beat the Phase 13I result of about 86.4 MIPS, the Phase 14 pipeline would need roughly 141.5 MHz or better at the measured CPI. To reach 90 MIPS, it would need roughly 147.4 MHz or better.

## Known Limitations

- No Phase 14 Vivado implementation result exists yet.
- No Phase 14 Fmax result exists yet.
- No Phase 14 MIPS claim is made.
- There is no branch prediction.
- There is no target buffer.
- Control-flow and load-use handling are still conservative.
- Phase 13I remains the best measured implementation until Phase 14 has both full verification and post-route timing evidence.

## Recommended Next Phase

Phase 14G should synthesize and implement the separate six-stage pipeline on the Basys 3 target, run a timing sweep, measure post-route Fmax and calculate practical MIPS using the Phase 14F measured CPI.
