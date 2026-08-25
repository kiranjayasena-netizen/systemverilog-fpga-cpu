# GPU Stage 4 — Vector Instruction Format and Control

## Purpose

Stage 4 replaces manually driven Stage 3 controls with one compact encoded
vector instruction. It remains a standalone instruction-controlled datapath:
there is no program counter, instruction memory, fetch unit, scheduler, CPU
connection, branch, jump, or memory operand.

## Instruction format

Every instruction is 16 bits:

```text
15          12 11        9 8         6 5         3 2       0
+-------------+-----------+-----------+-----------+---------+
|   opcode    |    dst    |   src_a   |   src_b   | reserved|
+-------------+-----------+-----------+-----------+---------+
```

The three-bit register fields select V0–V7. Reserved bits `[2:0]` are ignored
for valid instructions and remain available for future encoding extensions.

## Opcode table

The instruction opcode directly reuses the verified Stage 2 vector ALU
encoding:

| Opcode | Operation |
|---:|---|
| `4'h0` | VADD |
| `4'h1` | VSUB |
| `4'h2` | VAND |
| `4'h3` | VOR |
| `4'h4` | VXOR |
| `4'h5` | VCMPEQ |
| `4'h6` | VCMPLT |
| `4'h7` | VSLL |
| `4'h8` | VSRL |
| `4'h9` | VSRA |
| `4'hA`–`4'hF` | invalid |

VMUL is not encoded or implemented.

## Decoder architecture

`rtl/vector_instruction_decoder.sv` is purely combinational. It extracts the
fields, accepts opcodes `0`–`9`, and emits deterministic zero controls for
invalid opcodes.

```text
16-bit instruction
        |
        v
vector_instruction_decoder
        |
  alu_op, src_a, src_b, dst,
  instruction_valid, execute_enable
```

For a valid opcode, `instruction_valid=1` and decoder `execute_enable=1`.
For opcode `A`–`F`, both are zero, so invalid encoded instructions cannot
write vector state through the Stage 3 wrapper.

## Wrapper architecture

`rtl/vector_instruction_execution_unit.sv` instantiates the decoder and the
unchanged `vector_execution_unit`:

```text
encoded instruction
        |
        v
instruction decoder
        |
        +--> decoded controls
        |          |
instruction_enable AND valid
        |          v
        +--> vector_execution_unit
                    |
              vector registers
```

The wrapper passes through the existing load/debug interface. The final
execution enable is `instruction_enable && instruction_valid`. Stage 3's
priority remains `reset > load > execution > hold`; no second writer was
introduced.

## Verification

Standalone decoder testbench:
`tb/vector_instruction_decoder_tb.sv`. It checks every valid opcode, every
invalid opcode, reserved-bit independence, V0/V7 fields, source overlap, and
destination overlap.

Integrated testbench:
`tb/vector_instruction_execution_unit_tb.sv`. It constructs encoded
instructions with a helper function and verifies loading, encoded VADD/VSUB/
VXOR/VCMPLT/VSRA sequences, instruction disable, invalid-op suppression,
reserved bits, source/destination aliasing, signed comparison, shifts, reset,
and load priority.

The previous Stage 1, Stage 2, and Stage 3 testbenches are also rerun after
Stage 4. The CPU is not instantiated or modified.

## Timing and limitations

The new likely path is instruction-field decode → Stage 3 source selection →
register-file read → four-lane ALU → writeback mux. The decoder itself is
small combinational logic; future instruction fetch or pipelining can isolate
it if needed. Stage 4 still executes one externally presented instruction at
a time and has no automatic sequencing, memory access, masks, scheduler,
pipeline, or VMUL.

## Next stage

The next planned step is a standalone program counter and vector instruction
memory that can present a short instruction sequence automatically. That
sequencer is intentionally not part of Stage 4.
