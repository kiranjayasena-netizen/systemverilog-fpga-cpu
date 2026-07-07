# FPGA LED Expected Sequence

## Purpose

This document describes the expected Basys 3 LED behaviour for the current FPGA demo program before physical hardware testing. The values are derived from the RTL design, the LED mapping in `rtl/fpga_top.sv`, and the instruction words in `programs/fpga_led_demo.mem`.

This is not measured board behaviour. It is a reference table for first hardware bring-up once the Basys 3 is available.

## LED Bit Mapping

The FPGA top-level maps CPU debug signals onto the 16 Basys 3 LEDs:

| LED bits | Signal | Meaning |
| --- | --- | --- |
| `led[3:0]` | `pc[5:2]` | Current instruction word index, low 4 bits |
| `led[7:4]` | `opcode` | Current instruction opcode |
| `led[8]` | `valid_instr` | High for recognised instructions |
| `led[9]` | `reg_write` | High when the current instruction writes a register |
| `led[10]` | `use_imm` | High when the ALU B input uses the immediate value |
| `led[13:11]` | `alu_op` | ALU operation code |
| `led[15:14]` | `alu_result[1:0]` | Low two bits of the current ALU result |

The CPU uses the real 100 MHz Basys 3 clock. The slow tick only gates the CPU enable path, so the visible state should advance once per slow enable pulse when `enable_sw` is high.

## Demo Program

The demo program is loaded from `programs/fpga_led_demo.mem`:

```text
60800001  ADDI x1, x0, 1
61000002  ADDI x2, x0, 2
11844000  ADD  x3, x1, x2
52044000  XOR  x4, x1, x2
90044002  BEQ  x1, x2, +2
62800007  ADDI x5, x0, 7
A0001FFA  JUMP -6
00000000  NOP
```

The branch at word index 4 is expected not to be taken because `x1 = 1` and `x2 = 2`. The jump at word index 6 uses an immediate of `-6`, so the target is word index 0. The NOP at word index 7 is a spare word and should not normally be reached in the loop.

## Expected Sequence

Control LED shorthand:

- `V`: `led[8]`, `valid_instr`
- `W`: `led[9]`, `reg_write`
- `I`: `led[10]`, `use_imm`
- `ALU`: `led[13:11]`

| Step | PC | Instruction word | Assembly meaning | Expected `led[3:0]` | Expected `led[7:4]` | Expected key control LEDs | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | `0x00000000` | `60800001` | `ADDI x1, x0, 1` | `0x0` | `0x6` | `V=1, W=1, I=1, ALU=000` | Writes `x1 = 1`; ALU low bits should reflect result `1`. |
| 1 | `0x00000004` | `61000002` | `ADDI x2, x0, 2` | `0x1` | `0x6` | `V=1, W=1, I=1, ALU=000` | Writes `x2 = 2`; ALU low bits should reflect result `2`. |
| 2 | `0x00000008` | `11844000` | `ADD x3, x1, x2` | `0x2` | `0x1` | `V=1, W=1, I=0, ALU=000` | Writes `x3 = 3`; ALU low bits should reflect result `3`. |
| 3 | `0x0000000C` | `52044000` | `XOR x4, x1, x2` | `0x3` | `0x5` | `V=1, W=1, I=0, ALU=100` | Writes `x4 = 3`; ALU low bits should reflect result `3`. |
| 4 | `0x00000010` | `90044002` | `BEQ x1, x2, +2` | `0x4` | `0x9` | `V=1, W=0, I=0, ALU=000` | Branch should not be taken because `x1 != x2`; next PC should be word index 5. |
| 5 | `0x00000014` | `62800007` | `ADDI x5, x0, 7` | `0x5` | `0x6` | `V=1, W=1, I=1, ALU=000` | Writes `x5 = 7`; ALU low bits should reflect result `3` because `7[1:0] = 2'b11`. |
| 6 | `0x00000018` | `A0001FFA` | `JUMP -6` | `0x6` | `0xA` | `V=1, W=0, I=0, ALU=000` | Jump target is word index 0; next visible instruction should return to step 0. |
| Spare | `0x0000001C` | `00000000` | `NOP` | `0x7` | `0x0` | `V=1, W=0, I=0, ALU=000` | Spare word. It should only be seen if the loop control flow is not operating as expected. |

## Expected Loop Behaviour

With reset released and `enable_sw` high, the visible PC nibble should step through:

```text
0, 1, 2, 3, 4, 5, 6, 0, 1, ...
```

The opcode nibble on `led[7:4]` should step through:

```text
6, 6, 1, 5, 9, 6, A, 6, ...
```

If the spare NOP at word index 7 appears repeatedly during normal operation, the jump path should be investigated.

## ALU Result LED Notes

`led[15:14]` shows `alu_result[1:0]`. These LEDs depend on the current register state and ALU operation, so they are less direct than the PC and opcode LEDs.

For the intended program sequence after reset, the low ALU result bits should follow the simulated program behaviour:

- `ADDI x1, x0, 1`: result low bits `01`
- `ADDI x2, x0, 2`: result low bits `10`
- `ADD x3, x1, x2`: result low bits `11`
- `XOR x4, x1, x2`: result low bits `11`
- `BEQ x1, x2, +2`: ALU output is not used for branch comparison, so these LEDs are not the primary check for this step
- `ADDI x5, x0, 7`: result low bits `11`
- `JUMP -6`: ALU output is not used for the jump target, so these LEDs are not the primary check for this step

During hardware bring-up, use `led[3:0]`, `led[7:4]`, and the key control LEDs as the primary checks. Use `led[15:14]` as a secondary indication only.

## Use During Hardware Bring-Up

When the Basys 3 board is available, this table should be used as a visual checklist:

1. Program the board with the generated `fpga_top.bit`.
2. Apply reset and confirm the design starts from PC word index 0.
3. Enable the CPU with SW0.
4. Watch the low PC LEDs and opcode LEDs advance through the expected loop.
5. Confirm the NOP spare word is not normally reached.
6. Record any mismatch in a hardware bring-up report.

This document records expected behaviour only. It should be updated after real board testing with measured observations.
