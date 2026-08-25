# GPU Stage 6 — Standalone Vector Data Memory

## Purpose

Stage 6 provides storage larger than the eight vector registers without
integrating memory into the programmable vector core. It is a standalone
FPGA-oriented memory block for future VLOAD/VSTORE work.

## Organization and interface

`vector_data_memory` stores 32 entries of 128 bits, for 4096 total bits. The
5-bit address selects one complete vector. Lane packing remains lane 0 in
`[31:0]`, lane 1 in `[63:32]`, lane 2 in `[95:64]`, and lane 3 in `[127:96]`.

The block has one synchronous read port and one synchronous write port:

```text
read_enable, read_addr  -> rising edge -> registered read_data
write_enable, write_addr, write_data -> rising edge -> memory update
```

Reads are registered and `read_data` holds when `read_enable=0`. Writes are
whole-vector writes; there are no byte or lane masks.

## Reset and read/write policy

There is no reset input. The memory array is deliberately not cleared so that
the RTL remains suitable for FPGA memory inference. Contents are undefined
until written. The output register is likewise only meaningful after an
enabled read.

The implementation explicitly uses READ-FIRST behavior for a same-address
read and write on one edge: `read_data` receives the old memory value while
the write commits the new value. Different-address simultaneous accesses are
independent.

## Verification

`tb/vector_data_memory_tb.sv` checks basic and multi-address accesses,
boundaries 0 and 31, lane ordering, overwrite, disabled read/write behavior,
synchronous timing, different-address and same-address simultaneous accesses,
and deterministic multi-entry patterns. Vivado XSim passed all checks.

## Synthesis and future implications

The lightweight inference script is
`scripts/run_vector_data_memory_stage6_synth.tcl`, targeting
`xc7a35tcpg236-1`. The Stage 6 memory is intentionally measured before any
attempt to force a particular primitive. A future VLOAD will need address
issue, a memory edge, and vector-register writeback after the registered read;
a VSTORE will commit a whole vector at a defined write edge.

Stage 6 has no CPU connection, VLOAD/VSTORE instructions, address generator,
banking, cache, DMA, or external DDR.
