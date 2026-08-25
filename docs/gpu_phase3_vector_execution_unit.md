# GPU Stage 3 — Standalone Vector Execution Unit

## Objective

Stage 3 integrates the verified Stage 1 vector register file and Stage 2
vector ALU into one standalone, directly controlled datapath. It does not
connect to the frozen CPU, instruction memory, scheduler, or vector memory.

## Module hierarchy

```text
vector_execution_unit
  +-- vector_register_file
  |     +-- two combinational source reads
  |     +-- one synchronous write port
  +-- vector_alu
        +-- four combinational 32-bit lanes
```

The integrated path is:

```text
src_a/src_b -> register-file reads -> vector_alu -> alu_result
                                      |
load/execute writeback mux ----------+
                                      v
                                  dst register
```

## Interface

Normal control inputs are `src_a`, `src_b`, `dst` (3-bit vector-register
indices), `alu_op` (the existing 4-bit Stage 2 encoding), and
`execute_enable`. `alu_result` exposes the combinational result before the
writeback edge.

For standalone verification, `load_enable`, `load_addr`, and `load_data`
provide an explicit vector initialization path. `debug_read_enable`,
`debug_read_addr`, and `debug_read_data` provide a clean readback path without
hierarchical storage access. Debug mode temporarily uses source read port A;
it is intended for verification while normal execution is disabled.

## Writeback and timing semantics

There is one register-file writer. Its priority is:

```text
reset > load_enable > execute_enable > hold
```

Reset priority is implemented by the existing register file. Load and execute
are combined into one write-enable/address/data mux, so simultaneous load and
execute produces exactly one load write. With execute disabled, no normal ALU
writeback occurs.

During a cycle, source addresses select old register contents and the ALU
computes combinationally. At the rising edge, an enabled destination captures
the result. Reads after the edge observe the new value. This naturally supports
`VADD V1,V1,V2` and `VSUB V2,V1,V2`: source/destination aliasing uses old
pre-edge operands.

Invalid ALU encodings retain Stage 2 semantics: the ALU produces zero and an
enabled execution writes that zero to the destination.

## Verification

`tb/vector_execution_unit_tb.sv` is self-checking and covers:

- reset and reset priority over load/execute;
- external vector loads and debug readback;
- VADD, VSUB, VXOR, and VCMPLT sequences;
- destination equal to source A and source B;
- execute-disabled hold;
- simultaneous load/execute load priority;
- invalid operation zero writeback;
- signed VCMPLT and arithmetic VSRA integration;
- lane order and lane-independent result propagation;
- old-state/new-state writeback timing.

The Stage 3 XSim run completed with `VECTOR EXECUTION UNIT TEST PASSED`.
Stage 1 and Stage 2 remain independently verified and their RTL was not
modified.

## Timing/resource observations

The integrated combinational path is register-file read muxing → four-lane
ALU operation muxing → writeback input muxing. Adds/subtracts use LUT/carry
chains, logic operations use LUTs, comparisons add per-lane comparator logic,
and shifts use barrel-shifter/multiplexer networks. The shifts are expected to
be the most timing-sensitive operations. No DSPs are expected because VMUL is
not implemented. No full synthesis or CPU timing campaign is performed in
Stage 3.

## Deliberate limitations and next stage

This is one externally controlled vector operation at a time with single-cycle
combinational execution and synchronous writeback. It has no decoder, program
counter, scheduler, masks, memory operands, pipeline, or VMUL. The next stage
may define a compact vector instruction/control format and decode it into this
unit, but CPU integration remains out of scope.
