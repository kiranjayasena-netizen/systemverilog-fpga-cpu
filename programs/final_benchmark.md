# Final Benchmark Program

`programs/final_benchmark.mem` is the Phase 18 shared benchmark image used by both XSim and the Basys 3 FPGA hardware wrapper.

The program uses only the custom ISA instructions supported by the Phase 13 forward-timing CPU: `NOP`, `ADD`, `SUB`, `AND`, `OR`, `XOR`, `ADDI`, `LOAD`, `STORE`, `BEQ` and `JUMP`.

## Behaviour

The benchmark initializes a small register set and then runs a deterministic loop. Each loop group includes arithmetic dependencies, a store/load pair, a load-use dependency, a taken `BEQ`, a not-taken `BEQ`, and backward `JUMP` control flow. Data memory locations are written before being loaded, so the program does not rely on undefined memory contents.

## Instruction Listing

| Word | Instruction | Purpose |
|---:|---|---|
| 0 | `ADDI x1, x0, 64` | Base address |
| 1 | `ADDI x2, x0, 0` | Accumulator |
| 2 | `ADDI x3, x0, 5` | Loop counter |
| 3 | `ADDI x4, x0, 1` | Step |
| 4 | `ADDI x5, x0, 3` | Mask |
| 5 | `ADDI x6, x0, 7` | XOR constant |
| 6 | `STORE x2, [x1 + 0]` | Initialize data memory |
| 7 | `ADDI x7, x0, 0` | Scratch initialization |
| 8 | `ADD x2, x2, x4` | Accumulate |
| 9 | `XOR x7, x2, x6` | Arithmetic mix |
| 10 | `AND x8, x7, x5` | Arithmetic mix |
| 11 | `OR x9, x8, x4` | Arithmetic mix |
| 12 | `STORE x9, [x1 + 0]` | Store working value |
| 13 | `LOAD x10, [x1 + 0]` | Load working value |
| 14 | `ADD x11, x10, x2` | Load-use dependency |
| 15 | `SUB x3, x3, x4` | Decrement counter |
| 16 | `BEQ x3, x0, +2` | Exit group when counter reaches zero |
| 17 | `JUMP -9` | Loop back to word 8 |
| 18 | `ADDI x3, x0, 5` | Reset loop counter |
| 19 | `STORE x11, [x1 + 4]` | Store group result |
| 20 | `LOAD x12, [x1 + 4]` | Load group result |
| 21 | `ADD x13, x12, x4` | Second load-use dependency |
| 22 | `BEQ x13, x0, +2` | Not-taken branch |
| 23 | `JUMP -15` | Repeat benchmark group |
| 24 | `NOP` | Safe target if branch condition ever changes |
