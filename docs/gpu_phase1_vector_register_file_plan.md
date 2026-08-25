# GPU Phase 1 — Four-Lane Vector Register File Plan

## Goal

Build the smallest useful SIMD block without touching the frozen CPU: a
standalone vector register file that stores four 32-bit elements per vector
register. The first implementation is `rtl/vector_register_file.sv` with the
self-checking testbench `tb/vector_register_file_tb.sv`.

## Interface decision

- `LANES = 4`
- `ELEMENT_WIDTH = 32`
- `REG_COUNT = 8`
- Packed vector width = 128 bits
- Two combinational read ports
- One synchronous whole-vector write port
- Synchronous active-high reset clears every vector register
- Lane 0 occupies the least-significant element slice `[31:0]`; lane 1 is
  `[63:32]`, matching the repository's little-lane-first packed convention.

Writing a vector is atomic at the register-file clock edge. Reads are ordinary
combinational array reads, so a read after a write edge observes the new vector;
read-during-write behaviour before the edge is intentionally the old value.
There is no x0 hardwired-zero vector: vector register 0 is a normal storage
entry, avoiding an unnecessary scalar-ISA assumption. A future vector ISA can
add a reserved-zero policy only with a dedicated compatibility requirement.

## Why this is the first component

It isolates storage semantics before adding decode, lane arithmetic, or CPU
backpressure. The testbench can prove element ordering and write/read timing
without hiding errors inside a larger execution unit. The module is
parameterised for later 1/2/4/8-lane studies, but Phase 1 measures only the
four-lane default.

## Verification plan

The testbench will check:

1. reset clears all vector registers;
2. writes to multiple register indices;
3. simultaneous independent reads;
4. overwrite of an existing vector;
5. lane 0/lane 3 ordering;
6. write enable and reset priority;
7. no write when `we=0`;
8. a read of each stored vector against an independent expected packed value.

The test is self-checking and terminates with a failure on any mismatch. The
CPU core is not instantiated, so failure cannot be hidden by CPU forwarding or
pipeline behaviour.

## Next gate

Only after this testbench passes should the project add the four-lane ALU. The
next ALU plan is to reuse the scalar ADD/SUB/AND/OR/XOR definitions as shared
operation codes, add compare/shift deliberately, and defer multiply until its
DSP and signed-width policy is specified.
