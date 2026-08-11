# GPU Evolution Phase 0 — CPU Architecture Assessment

## Scope

This document is a read-only assessment of the frozen summer-project CPU and
the first incremental GPU/vector step. The CPU remains unchanged; the final
reference is the `summer-project-final` baseline and the T2 core listed below.

## 1. How the current CPU works

The final core is
`rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`, wrapped by
`rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`. It implements a
five-boundary in-order pipeline:

```text
instruction BRAM -> fetch buffer -> IF/ID -> ID/EX -> EX/MEM -> MEM/WB -> retire
                                      |         |          |
                                   decode   ALU/branch   data BRAM
```

The core owns its final register array (`regs[0:31]`) and uses one
architectural write port with two combinational read selections. The separate
`rtl/register_file.sv` is the earlier reusable educational register-file
module; the frozen timing core keeps the register state internally to align
writeback, DOT completion, and retirement control.

The scalar ISA has NOP, ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ, JUMP,
MAC8, and DOT4ACC. The scalar ALU is implemented by `rtl/alu.sv`. MAC8 is a
low-byte signed multiply-add and DOT4ACC is a four-lane signed-int8
multiply-add implemented by `rtl/dot4acc_pipeline.sv` with four DSP-directed
multipliers and a fabric reduction tree.

Instruction and data memories are synchronous BRAM-style modules
(`rtl/bram_instr_mem.sv` and `rtl/bram_data_mem.sv`) with 256 32-bit words by
default. Addresses are byte addresses selecting `addr[9:2]`. The Basys 3
clock/reset/enable/LED shell is constrained by `constraints/basys3.xdc`.

## 2. Control, hazards, and memory behaviour

Decode derives opcode, register fields, immediate, and source-use predicates.
The pipeline uses load-use stalls, EX/MEM and MEM/WB forwarding, branch/jump
redirects, fetch buffering, and valid bits for precise cancellation.

DOT4ACC has a private issue/metadata/completion path. A DOT accepted at issue
I completes at I+3 and retires at I+4; same-rd chains accept at II=1.
DOT-specific source and accumulator forwarding handles in-flight results.

Stage H adds one deferred-load completion entry, backpressure, and an atomic
`second_load_transfer_fire` event. `second_load_reserved` tracks the dynamic
LOAD lifetime and `second_load_idex_owned` tracks the ID/EX transaction. This
allows one qualifying younger LOAD to cross IF/ID→ID/EX while one older DOT
overlap is active, while preserving one RF write port and in-order retirement.

## 3. Reusable CPU concepts

The following concepts transfer directly to a vector processor:

| CPU concept | Vector/GPU analogue |
|---|---|
| 32-bit ALU operation | one lane ALU operation |
| register-file read/write discipline | vector register-file read/write |
| decode/control opcode | shared vector control |
| DOT arithmetic pipeline | future vector multiply/reduction pipeline |
| valid/enable pipeline registers | vector issue/writeback enables |
| BRAM data memory | future local/shared vector memory |
| performance counters | lane throughput and stall counters |
| timing/resource reports | lane-scaling trade-off evidence |

The existing ALU's operations can be reused conceptually, but the first
implementation will keep a vector register file and lane ALU independent from
the frozen CPU to make verification and timing attribution unambiguous.

## 4. CPU-specific components to leave unchanged

The final CPU's fetch buffering, scalar retirement protocol, deferred-load
ownership, branch cancellation, instruction encoding, and Basys 3 wrapper are
not modified by the initial GPU work. No vector instruction is added to the
frozen CPU in Phase 1, and no CPU benchmark or timing result is redefined.

## 5. New hardware required over time

The incremental path requires:

1. A vector register file with four 32-bit elements per register.
2. A four-lane integer ALU with one shared operation control.
3. A vector execution unit combining register file, ALU, and writeback.
4. A separately verified CPU/accelerator interface.
5. Only later, local memory, masks, a programmable parallel core, framebuffer,
   and video output.

## 6. Recommended incremental plan

1. **Phase 1:** standalone four-lane vector register file; verify reset,
   writes, reads, overwrite, and lane ordering.
2. **Phase 2:** standalone four-lane ALU; verify integer operations and signed
   behaviour.
3. **Phase 3:** vector execution unit and short programmable test sequence.
4. **Phase 4:** choose and verify a CPU interface (prefer a small explicit
   coprocessor/MMIO boundary before changing CPU decode).
5. **Phase 5:** benchmark CPU versus vector unit on vector add/dot workloads.
6. **Phase 6:** parameterise lane count only after four lanes are verified.
7. **Phase 7:** add banked local memory and measure conflicts/bandwidth.
8. **Phase 8:** add execution masks and divergence examples.
9. **Phase 9:** evolve to a small programmable parallel core.
10. **Phase 10:** framebuffer simulation, then only the simplest board output
    supported by verified Basys 3 constraints.

Every step needs a self-checking testbench and a cycle/resource/timing record.
No later step begins after a failing earlier step.

## 7. Workflow and evidence

The repository uses Vivado XSim through scripts such as
`scripts/run_xsim_regression.ps1` and dedicated Stage E–L scripts. Physical
implementation uses Tcl scripts under `scripts/` and the Basys 3 XDC. New
vector modules will be added under `rtl/`, their testbenches under `tb/`, and
educational design notes under `docs/`; generated Vivado/XSim artifacts remain
ignored.
