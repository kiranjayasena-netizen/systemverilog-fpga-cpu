# GPU Stage 7 — Vector Load/Store Integration

Stage 7 adds VLOAD and VSTORE to a new memory-enabled programmable core while
preserving the Stage 1–6 functional modules. The original Stage 5 core is not
modified.

## ISA

ALU instructions retain the Stage 4 format. Opcode `4'hA` is VLOAD and `4'hB`
is VSTORE:

```text
VLOAD  [15:12]=A, [11:9]=destination, [8:4]=memory address, [3:0]=reserved
VSTORE [15:12]=B, [11:9]=source,      [8:4]=memory address, [3:0]=reserved
```

`4'hC`–`4'hF` remain invalid. Reserved bits are ignored.

## Control and timing

`vector_memory_program_core` uses `S_EXEC` and `S_LOAD_WB` states. An ALU
instruction or VSTORE completes at its active edge and advances PC. A VLOAD
asserts the Stage 6 synchronous read in `S_EXEC`, latches its destination, and
writes the registered memory result in `S_LOAD_WB`; only then does PC advance.

```text
VLOAD:  S_EXEC/read edge → S_LOAD_WB/write edge → PC advance
VSTORE: S_EXEC/write edge → PC advance
```

Invalid instructions advance without architectural writes. Start while
running is ignored. Final VLOAD/VSTORE effects commit before `done` asserts.

## Interfaces and policy

Instruction loading and external data-memory loading are accepted while idle.
Running-time external data writes and debug reads are ignored. Synchronous data
debug reads while idle use the same one-edge latency as the real memory port. Vector-register loading
remains available while idle and retains reset/load/execute priority.

## Verification

`tb/vector_memory_program_core_tb.sv` covers basic loads/stores, dependent
load/ALU and ALU/store sequences, the full two-load pipeline example, invalid
slots, boundary addresses, final memory operations, lane-preserving data, and
restart behavior. Stage 7 uses the existing 32×128 synchronous READ-FIRST
memory without duplicating its implementation.

## Limitations

There are no indirect addresses, branches, loops, VMUL, masks, banking, cache,
DMA, DDR, framebuffer, or CPU connection. The next step is memory-processing
benchmark characterization, not another control feature.
