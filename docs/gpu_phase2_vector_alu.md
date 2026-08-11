# GPU Stage 2 — Standalone Four-Lane Vector ALU

## Purpose

Stage 2 adds the first parallel execution datapath without changing the
frozen CPU or connecting to the Stage 1 vector register file. The unit is a
purely combinational four-lane ALU, allowing lane semantics to be verified
before adding execution-unit state, instruction decoding, memory, or a CPU
interface.

## Interface and packing

`rtl/vector_alu.sv` has two 128-bit inputs, a 4-bit shared operation selector,
and one 128-bit output. The lane convention is:

```text
vector[31:0]    = lane 0
vector[63:32]   = lane 1
vector[95:64]   = lane 2
vector[127:96]  = lane 3
```

All four lanes execute the selected operation in the same combinational
evaluation. There is no clock, reset, state, or writeback register.

## Operation encoding and semantics

| Encoding | Operation | Per-lane semantics |
|---:|---|---|
| `4'h0` | VADD | `A + B`, 32-bit wraparound |
| `4'h1` | VSUB | `A - B`, 32-bit wraparound |
| `4'h2` | VAND | bitwise AND |
| `4'h3` | VOR | bitwise OR |
| `4'h4` | VXOR | bitwise XOR |
| `4'h5` | VCMPEQ | `32'h1` if equal, otherwise `32'h0` |
| `4'h6` | VCMPLT | signed 32-bit less-than, result 1 or 0 |
| `4'h7` | VSLL | logical left shift by `B[4:0]` |
| `4'h8` | VSRL | logical right shift by `B[4:0]` |
| `4'h9` | VSRA | signed arithmetic right shift by `B[4:0]` |
| `4'hA`–`4'hF` | invalid | zero result |

Signed comparisons and arithmetic shifts use explicit `$signed` conversion.
Logical right shift uses unsigned lane data and therefore zero-fills. Shift
amounts use only the corresponding lane's five least-significant bits.
Comparison results are scalar 1/0 values replicated as 32-bit lane values;
they are not all-ones masks.

## Verification

`tb/vector_alu_tb.sv` is self-checking and uses an independent lane-by-lane
reference function. It covers all operations, wraparound, unequal lane data,
mixed signed comparisons, shift-by-zero/one/31, high shift bits being ignored,
lane order, lane independence, and invalid-operation zeroing.

Vivado XSim command sequence:

```text
xvlog.bat -sv rtl/vector_alu.sv tb/vector_alu_tb.sv
xelab.bat vector_alu_tb -s vector_alu_tb_sim --debug off
xsim.bat vector_alu_tb_sim -runall
```

The completed run reports `VECTOR ALU TEST PASSED`.

## FPGA mapping expectations

- VADD/VSUB: LUT plus FPGA carry-chain arithmetic.
- VAND/VOR/VXOR: LUT-based bitwise logic.
- VCMPEQ/VCMPLT: per-lane comparator and reduction logic; VCMPLT includes
  signed sign-aware comparison.
- VSLL/VSRL/VSRA: barrel-shifter/multiplexer networks, likely the most
  timing-sensitive operations in this combinational block.
- DSP usage: expected zero; VMUL is deliberately not implemented.

No synthesis or timing campaign is performed at this stage. Correctness and a
clear standalone boundary come first.

## Limitations and deferred VMUL decision

The ALU has no registered latency and is not yet programmable. It is not
connected to `rtl/vector_register_file.sv`, memory, or the CPU. Before adding
VMUL, the project must decide signed versus unsigned arithmetic, operand and
product widths, DSP48 count, pipelined versus combinational timing, execution
latency, writeback timing, Basys 3 resource impact, and achievable frequency.

The next stage may combine the verified vector register file and vector ALU
into a standalone vector execution unit. It must not connect to the frozen CPU
until that unit has its own integration tests.
