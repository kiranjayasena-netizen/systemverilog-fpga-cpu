# Architecture Notes

## Current Architecture Status

The architecture has progressed from individual RTL module bring-up to two verified CPU implementation paths:

- The original integrated CPU baseline in `rtl/cpu_core.sv`.
- The separate multi-cycle CPU implementation in `rtl/cpu_core_multicycle.sv`.

The original CPU is a simple educational 32-bit soft-core written in SystemVerilog. It is a single-cycle-style design: for each instruction, the core fetches the instruction, decodes it, reads registers, performs the ALU or memory operation, selects writeback data, and chooses the next PC through one straightforward combinational datapath around synchronous state elements.

The separate multi-cycle CPU keeps the same custom ISA and final architectural behaviour, but splits instruction execution across finite-state-machine states. This was added after Phase 7 timing analysis showed that the single-cycle-style implementation did not meet the 100 MHz Basys 3 timing target after routing.

The design remains intentionally small. It is meant to make the CPU datapath easy to understand before adding more advanced features such as pipelining, hazards, interrupts, caches, or a bus interface.

## Project Progress Summary

The project has reached these architecture milestones:

| Phase | Architecture Progress |
| --- | --- |
| Module bring-up | Parameterised 32-bit ALU, register file, program counter, instruction memory, data memory, fetch unit, decoder and control unit. |
| CPU integration | `cpu_core` integrates fetch, decode, control, register read, ALU, memory, writeback and PC selection. |
| ISA support | Custom ISA supports NOP, ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ and JUMP. |
| Program execution | File-loaded custom-ISA programs execute through `cpu_top` and the integrated `cpu_core`. |
| Expanded verification | Phase 6 program tests cover arithmetic edge cases, memory offsets, branches, jumps, loops and invalid opcode safety. |
| FPGA baseline | `fpga_top` builds for the Digilent Basys 3 and generates a bitstream, but the single-cycle-style path misses 100 MHz post-route timing. |
| Multi-cycle redesign | `cpu_core_multicycle` preserves the ISA while splitting work across FETCH, DECODE, EXECUTE, MEMORY and WRITEBACK states. |
| Multi-cycle FPGA path | `fpga_top_multicycle` builds separately for the Basys 3 and meets the 100 MHz post-route timing target in Phase 8G. |

Physical Basys 3 board testing has not been claimed in the architecture notes. Existing FPGA evidence is from simulation, synthesis, implementation, timing reports and bitstream generation.

## Beginner-Friendly Datapath Overview

The CPU core is built from these RTL modules:

- `program_counter`: stores the current instruction address.
- `instruction_memory`: stores 32-bit instruction words and supports optional `$readmemh` loading.
- `fetch_unit`: combines the program counter and instruction memory.
- `instruction_decoder`: splits a 32-bit instruction into opcode, register fields, and sign-extended immediate.
- `control_unit`: turns the opcode into datapath control signals.
- `register_file`: stores 32 general-purpose 32-bit registers.
- `alu`: performs ADD, SUB, AND, OR, and XOR.
- `data_memory`: stores 32-bit data words for LOAD and STORE.
- `cpu_core`: wires the blocks together into the current integrated processor.
- `cpu_top`: wraps the integrated `cpu_core` for Phase 5 file-loaded program execution tests.
- `cpu_core_multicycle`: separate FSM-based CPU implementation that preserves the custom ISA.
- `fpga_top`: Basys 3 wrapper for the original integrated CPU baseline.
- `fpga_top_multicycle`: Basys 3 wrapper for the separate multi-cycle CPU implementation.

### Fetch

The fetch stage uses the current `pc` value as a byte address into instruction memory. Instruction memory uses `addr[31:2]` as the word address, so byte addresses `0`, `4`, `8`, and `12` access instruction words `0`, `1`, `2`, and `3`.

The CPU core calculates `next_pc` and passes it into the fetch unit. For normal sequential execution:

```text
next_pc = pc + 4
```

For a taken branch or jump, `next_pc` becomes the PC-relative target.

### Decode

The instruction decoder breaks the 32-bit instruction into fields:

```text
instruction[31:28] = opcode
instruction[27:23] = rd
instruction[22:18] = rs1
instruction[17:13] = rs2
instruction[12:0]  = imm13
```

It also sign-extends `imm13` to 32 bits as `imm_ext`. This lets ADDI, LOAD, STORE, BEQ, and JUMP use positive and negative immediate values.

### Control

The control unit reads the opcode and produces simple control signals:

- `reg_write`: enables register writeback.
- `use_imm`: selects `imm_ext` as ALU input B.
- `alu_op`: selects the ALU operation.
- `valid_instr`: marks recognised opcodes.
- `mem_read`: enables LOAD data memory reads.
- `mem_write`: enables STORE data memory writes.
- `mem_to_reg`: selects memory read data for writeback.
- `branch`: marks BEQ.
- `jump`: marks JUMP.

Invalid opcodes are safe: they do not write registers or memory and do not branch or jump.

### Register Read

The register file has two read ports. The CPU connects:

- `rs1` to read port A.
- `rs2` to read port B.
- `rd` to the write address.

Register `x0` is hardwired to zero. Writes to `x0` are ignored inside the register file.

### ALU Execution

ALU input A always comes from register read port A:

```text
alu_a = rdata_a
```

ALU input B is selected by `use_imm`:

```text
alu_b = use_imm ? imm_ext : rdata_b
```

For ADD, SUB, AND, OR, and XOR, the ALU result is the value written back to `rd`. For ADDI, LOAD, and STORE, the ALU uses ADD. In LOAD and STORE, the ALU result is the data memory byte address.

### Memory Access

Data memory is word-addressed using `addr[31:2]`, matching instruction memory. The ALU result drives the data memory address.

LOAD:

```text
address = rs1 + imm_ext
rd = data_memory[address]
```

STORE:

```text
address = rs1 + imm_ext
data_memory[address] = rs2
```

Data memory writes are synchronous. Data memory reads are combinational and enabled by `mem_read`.

### Writeback

The CPU has one register writeback path. The writeback data is selected by `mem_to_reg`:

```text
writeback_data = mem_to_reg ? data_mem_read_data : alu_result
```

The register file write enable remains protected by instruction validity:

```text
reg_file_we = reg_write && valid_instr
```

This prevents invalid opcodes from updating the register file.

### Branch And Jump

BEQ compares the two register operands:

```text
branch_taken = branch && valid_instr && (rdata_a == rdata_b)
```

BEQ and JUMP use the same target calculation:

```text
pc_target = pc + (imm_ext << 2)
```

The immediate is shifted left by two because it counts instruction words. One instruction word is 4 bytes.

The final next-PC selection is:

```text
next_pc = (branch_taken || (jump && valid_instr)) ? pc_target : pc_plus_4
```

This keeps control flow simple and visible in the waveform.

### Current Limits

The core is intentionally minimal:

- No pipeline yet.
- No hazard detection or forwarding.
- No interrupts or exceptions.
- No external bus interface yet.
- No status flags yet.
- No assembler yet; programs are currently hand-written as hex `.mem` files.

These limits are acceptable for the current phase because the main goal is to build and verify the datapath one piece at a time.

## Phase 3 FPGA Top-Level Architecture

Phase 3 adds a Basys 3-facing wrapper around the already integrated CPU core. The CPU instruction encoding and `cpu_core` behaviour are unchanged. The FPGA wrapper exists so the current simulated CPU can be built in Vivado and observed through simple board-level I/O.

### Target Board And Build Configuration

The current FPGA target is:

- Board: Digilent Basys 3.
- FPGA part: `xc7a35tcpg236-1`.
- Top module: `fpga_top`.
- Constraints file: `constraints/basys3.xdc`.
- Synthesis script: `scripts/run_vivado_synth.tcl`.
- Implementation script: `scripts/run_vivado_impl.tcl`.

The Basys 3 constraints currently map only the board signals needed by `fpga_top`:

- `clk`: 100 MHz Basys 3 board clock.
- `rst_btn`: reset pushbutton.
- `enable_sw`: SW0 CPU enable switch.
- `led[15:0]`: LD0 through LD15 debug outputs.

No unused pins are intentionally constrained in the current wrapper.

### FPGA Top Wrapper

File: `rtl/fpga_top.sv`

The wrapper instantiates `cpu_core` and exposes a small board-facing interface:

- `clk`: real 100 MHz Basys 3 clock.
- `rst_btn`: active-high reset input.
- `enable_sw`: user switch used to allow CPU stepping.
- `led[15:0]`: CPU debug state for first hardware bring-up.

The wrapper loads the LED demo program through the CPU instruction memory init-file path:

```text
IMEM_INIT_FILE = "programs/fpga_led_demo.mem"
```

This keeps the CPU core reusable while allowing the FPGA top-level to choose a program image for board bring-up.

### Slow CPU Stepping

File: `rtl/slow_tick_generator.sv`

The Basys 3 design still uses the real 100 MHz board clock. A divided clock is not created. Instead, `slow_tick_generator` creates a single-cycle `tick` pulse using a configurable `DIVISOR` parameter.

The FPGA wrapper gates the CPU enable input with the switch and the slow tick:

```text
cpu_enable = enable_sw && slow_tick
```

This means all CPU registers remain clocked by the same 100 MHz clock, while the CPU state only advances on slow enable pulses. The default divider is intended for human-visible LED stepping. Testbenches override the divider with a small value so simulation remains fast.

### LED Debug Mapping

The 16 LEDs expose a compact view of the CPU state:

| LED bits | Signal | Purpose |
| --- | --- | --- |
| `led[3:0]` | `pc[5:2]` | Low instruction-word address bits |
| `led[7:4]` | `opcode` | Current instruction opcode |
| `led[8]` | `valid_instr` | Recognised instruction indicator |
| `led[9]` | `reg_write` | Register writeback indicator |
| `led[10]` | `use_imm` | Immediate operand select indicator |
| `led[13:11]` | `alu_op` | ALU operation select |
| `led[15:14]` | `alu_result[1:0]` | Low ALU result bits |

This mapping is intentionally simple. It is useful for early board bring-up because the PC and opcode fields should visibly step through the demo program. The ALU result LEDs are secondary indicators because they depend on current register state and the active instruction.

The expected LED sequence is documented separately in [FPGA LED expected sequence](fpga_led_expected_sequence.md). That document is design-derived and has not yet been confirmed on physical hardware.

### FPGA LED Demo Program

File: `programs/fpga_led_demo.mem`

The demo program is:

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

The BEQ is intentionally not taken because `x1` and `x2` contain different values. The JUMP at word index 6 returns to word index 0. During normal operation the visible PC word index should loop:

```text
0, 1, 2, 3, 4, 5, 6, 0, ...
```

The spare NOP at word index 7 should not normally be reached.

### Phase 3 Verification And Build Evidence

Phase 3 evidence is separated into simulation, synthesis/implementation, and pending hardware evidence.

Simulation evidence:

- `tb/fpga_top_tb.sv` checks that `fpga_top` drives known LED values and exposes changing CPU debug state while enabled.
- `tb/slow_tick_generator_tb.sv` checks the one-cycle slow tick behaviour with a small simulation divisor.
- The full XSim regression has passed with the FPGA wrapper and slow tick tests included.

Synthesis and implementation evidence:

- Vivado synthesis passes for `fpga_top` targeting `xc7a35tcpg236-1`.
- Vivado implementation completes optimisation, placement and routing.
- Bitstream generation completes locally as `reports/bitstreams/fpga_top.bit`.
- The generated bitstream is a local build artifact and should not be committed.

Pre-hardware evidence is summarised in `reports/phase3_prehardware_validation.md`. The key limitation is that none of this is physical board validation yet.

### Phase 3 Resource And Timing Status

The Phase 3C routed implementation summary records:

- Slice LUTs: 2,983 / 20,800, 14.34%.
- Slice registers: 8,314 / 41,600, 19.99%.
- Block RAM tiles: 0 / 50, 0.00%.
- DSPs: 0 / 90, 0.00%.
- Total on-chip power estimate: 0.081 W.
- Target clock: 10.000 ns, 100 MHz.
- Post-route WNS: -1.551 ns.
- Post-route TNS: -5707.315 ns.
- Worst hold slack: 0.075 ns.

The routed design does not meet the 100 MHz setup timing constraint. The worst reported post-route path runs from the program counter through the single-cycle-style CPU datapath into register file writeback:

```text
cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C
to
cpu_inst/reg_file_inst/regs_reg[2][12]/D
```

This timing miss is consistent with the current simple single-cycle-style architecture. The slow tick makes state changes human-visible, but it does not close the internal 100 MHz timing path because all registers are still clocked by the real 100 MHz clock.

### Pending Hardware Validation

The project cannot yet claim:

- The Basys 3 has been programmed.
- The LEDs show the expected pattern on the real board.
- The reset button has been validated on the real board.
- The enable switch has been validated on the real board.
- The CPU has executed correctly in physical FPGA hardware.

The next hardware step is to program the Basys 3, use SW0 as `enable_sw`, use the mapped reset button, and compare the real LED pattern against the expected sequence document. Any observed behaviour should be recorded in a hardware bring-up report.

## ALU

File: `rtl/alu.sv`

The ALU is a parameterised combinational block with two operands, a 3-bit opcode and one result. Its `WIDTH` parameter defaults to 32 bits, matching the register file and the current CPU datapath width.

Interface summary:

- `WIDTH`: data width parameter, defaulting to 32.
- `a`: `WIDTH`-bit operand A.
- `b`: `WIDTH`-bit operand B.
- `op`: 3-bit operation select.
- `y`: `WIDTH`-bit result.

| Opcode | Operation |
| --- | --- |
| `3'b000` | ADD |
| `3'b001` | SUB |
| `3'b010` | AND |
| `3'b011` | OR |
| `3'b100` | XOR |
| Other | `'0` default result |

The ALU currently does not expose flags such as carry, zero, negative or overflow. These can be added later if the CPU instruction set needs them.

## CPU Architecture Direction

The first integrated CPU is now complete as a simple single-cycle-style baseline. It includes:

- A 32-register register file with `x0` protection.
- A 32-bit program counter.
- File-loadable instruction memory.
- Data memory with LOAD and STORE support.
- ADD, SUB, AND, OR, XOR and ADDI execution.
- BEQ and JUMP control flow.
- Decoder and control unit blocks that drive the datapath.

The separate multi-cycle CPU is now the main timing-improvement path. It preserves the same ISA and final program behaviour while adding explicit FSM state and intermediate registers to shorten the combinational paths seen by Vivado timing analysis.

## Register File

File: `rtl/register_file.sv`

The register file is a 32-register, 32-bit storage block intended to provide operands to the ALU and accept writeback data from the CPU datapath.

Interface summary:

- `clk`: clock input.
- `rst`: active-high reset.
- `we`: write enable.
- `waddr`: 5-bit write address.
- `wdata`: 32-bit write data.
- `raddr_a`: 5-bit read address for read port A.
- `raddr_b`: 5-bit read address for read port B.
- `rdata_a`: 32-bit read data from read port A.
- `rdata_b`: 32-bit read data from read port B.

Behaviour:

- 32 registers, addressed from `x0` to `x31`.
- 32-bit data width.
- Two asynchronous read ports.
- One synchronous write port.
- Register `x0` is hardwired to zero.
- Writes to `x0` are ignored.
- Reset clears the stored registers.

This interface matches a simple CPU datapath where two source registers can be read at the same time and one destination register can be written back on a clock edge.

## Program Counter

File: `rtl/program_counter.sv`

The program counter stores the address of the current instruction. It is a 32-bit synchronous state register with reset and enable control.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset.
- `enable`: allows the PC to update when high.
- `next_pc`: 32-bit next PC value.
- `pc`: 32-bit current PC output.

Behaviour:

- `RESET_ADDR` parameter defaults to `32'h0000_0000`.
- On a rising clock edge, if `rst` is high, `pc` is loaded with `RESET_ADDR`.
- Else if `enable` is high, `pc` is loaded with `next_pc`.
- Else the current `pc` value is held.

The PC does not calculate branch or increment addresses internally. The surrounding datapath/control logic will provide `next_pc`, allowing the same interface to support sequential execution, branches and jumps later.

## Instruction Memory

File: `rtl/instruction_memory.sv`

The instruction memory is a simple combinational-read ROM-style block for fetching 32-bit instructions from byte addresses.

Interface summary:

- `addr`: 32-bit byte address input.
- `instruction`: 32-bit instruction output.
- `DEPTH`: parameter for the number of 32-bit instruction words, defaulting to 256.
- `INIT_FILE`: optional hex file path used with `$readmemh`, defaulting to an empty string.

Behaviour:

- Internally stores instructions as `logic [31:0] mem [0:DEPTH-1]`.
- All instruction words initialise to `32'h0000_0000`.
- If `INIT_FILE` is not empty, memory contents are loaded with `$readmemh`.
- Uses `addr[31:2]` as the word address, so byte addresses `0`, `4`, `8` and `12` map to words `0`, `1`, `2` and `3`.
- Reads are combinational.
- Out-of-range addresses return `32'h0000_0000`.

This block connects naturally to the program counter output. The program counter supplies a byte address, and the instruction memory returns the 32-bit instruction at that word-aligned location.

## Data Memory

File: `rtl/data_memory.sv`

The data memory is a standalone 32-bit word memory block used by the CPU core for LOAD and STORE instructions.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset.
- `mem_read`: enables combinational read data output.
- `mem_write`: enables synchronous write on the rising clock edge.
- `addr`: 32-bit byte address input.
- `write_data`: 32-bit write data input.
- `read_data`: 32-bit read data output.
- `DEPTH`: parameter for the number of 32-bit memory words, defaulting to 256.

Behaviour:

- Internally stores words as `logic [31:0] mem [0:DEPTH-1]`.
- Uses `addr[31:2]` as the word address, matching the instruction memory address convention.
- On reset, all memory words are cleared to `32'h0000_0000`.
- Writes are synchronous and only occur when `mem_write` is high and the word address is in range.
- Reads are combinational and return the selected word only when `mem_read` is high and the word address is in range.
- Disabled reads and out-of-range reads return `32'h0000_0000`.
- Out-of-range writes are ignored.

## Fetch Unit

File: `rtl/fetch_unit.sv`

The fetch unit integrates the existing program counter and instruction memory into a simple instruction-fetch stage.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset passed to the program counter.
- `enable`: allows the program counter to advance when high.
- `next_pc`: externally selected 32-bit next program counter value.
- `pc`: 32-bit current program counter output.
- `instruction`: 32-bit instruction fetched from instruction memory.
- `IMEM_DEPTH`: forwarded instruction memory depth parameter, defaulting to 256 words.
- `IMEM_INIT_FILE`: forwarded instruction memory hex init-file path, defaulting to an empty string.

Behaviour:

- Instantiates `program_counter` with `RESET_ADDR = 32'h0000_0000`.
- Instantiates `instruction_memory` with the forwarded `IMEM_DEPTH` and `IMEM_INIT_FILE` parameters.
- Connects `pc` directly to the instruction memory `addr` input.
- Supports file-based instruction program loading through the instruction memory `$readmemh` path.
- When enabled, the fetch stage loads the externally provided `next_pc`.
- When disabled, the PC and fetched instruction hold their current values.

This block keeps PC storage and instruction memory together while allowing the CPU core to choose sequential, branch or jump next-PC values.

## Instruction Decoder

File: `rtl/instruction_decoder.sv`

The instruction decoder is a purely combinational block that splits a 32-bit instruction into opcode, register index and immediate fields. The decoded opcode feeds the control unit.

Instruction format:

| Bits | Field | Description |
| --- | --- | --- |
| `[31:28]` | `opcode` | 4-bit operation code |
| `[27:23]` | `rd` | 5-bit destination register index |
| `[22:18]` | `rs1` | 5-bit source register 1 index |
| `[17:13]` | `rs2` | 5-bit source register 2 index |
| `[12:0]` | `imm13` | 13-bit immediate field |

Interface summary:

- `instruction`: 32-bit instruction input.
- `opcode`: decoded 4-bit opcode.
- `rd`: decoded 5-bit destination register.
- `rs1`: decoded 5-bit source register 1.
- `rs2`: decoded 5-bit source register 2.
- `imm13`: raw 13-bit immediate.
- `imm_ext`: `imm13` sign-extended to 32 bits.

Initial opcode map:

| Opcode | Operation |
| --- | --- |
| `4'h0` | NOP |
| `4'h1` | ADD |
| `4'h2` | SUB |
| `4'h3` | AND |
| `4'h4` | OR |
| `4'h5` | XOR |
| `4'h6` | ADDI |
| `4'h7` | LOAD |
| `4'h8` | STORE |
| `4'h9` | BEQ |
| `4'ha` | JUMP |

This decoder format keeps the fetched 32-bit instruction aligned with the 32-bit datapath and the 32-register register file. The signed immediate path supports immediate arithmetic, base-plus-offset addressing for LOAD and STORE, and PC-relative BEQ/JUMP targets.

## Control Unit

File: `rtl/control_unit.sv`

The control unit is a purely combinational block that maps the decoded 4-bit instruction opcode to datapath control signals. It does not handle status flags yet.

Interface summary:

- `opcode`: 4-bit instruction opcode from the instruction decoder.
- `reg_write`: enables register file writeback.
- `use_imm`: selects the sign-extended immediate as the second ALU operand instead of `rs2` data.
- `alu_op`: 3-bit ALU operation code.
- `valid_instr`: marks recognised instruction opcodes.
- `mem_read`: enables data memory read for LOAD.
- `mem_write`: enables data memory write for STORE.
- `mem_to_reg`: selects data memory read data for register writeback.
- `branch`: marks BEQ instructions for conditional PC target selection.
- `jump`: marks JUMP instructions for unconditional PC target selection.

Control signal table:

| Instruction | Opcode | `reg_write` | `use_imm` | `alu_op` | `mem_read` | `mem_write` | `mem_to_reg` | `branch` | `jump` | `valid_instr` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NOP | `4'h0` | `0` | `0` | `3'b000` ADD | `0` | `0` | `0` | `0` | `0` | `1` |
| ADD | `4'h1` | `1` | `0` | `3'b000` ADD | `0` | `0` | `0` | `0` | `0` | `1` |
| SUB | `4'h2` | `1` | `0` | `3'b001` SUB | `0` | `0` | `0` | `0` | `0` | `1` |
| AND | `4'h3` | `1` | `0` | `3'b010` AND | `0` | `0` | `0` | `0` | `0` | `1` |
| OR | `4'h4` | `1` | `0` | `3'b011` OR | `0` | `0` | `0` | `0` | `0` | `1` |
| XOR | `4'h5` | `1` | `0` | `3'b100` XOR | `0` | `0` | `0` | `0` | `0` | `1` |
| ADDI | `4'h6` | `1` | `1` | `3'b000` ADD | `0` | `0` | `0` | `0` | `0` | `1` |
| LOAD | `4'h7` | `1` | `1` | `3'b000` ADD | `1` | `0` | `1` | `0` | `0` | `1` |
| STORE | `4'h8` | `0` | `1` | `3'b000` ADD | `0` | `1` | `0` | `0` | `0` | `1` |
| BEQ | `4'h9` | `0` | `0` | `3'b000` ADD | `0` | `0` | `0` | `1` | `0` | `1` |
| JUMP | `4'ha` | `0` | `0` | `3'b000` ADD | `0` | `0` | `0` | `0` | `1` | `1` |
| Invalid | Other | `0` | `0` | `3'b000` ADD | `0` | `0` | `0` | `0` | `0` | `0` |

The default control outputs are safe for invalid instructions: register writeback, memory access, branch and jump are disabled, immediate selection is disabled, the ALU operation defaults to ADD and `valid_instr` is low.

## CPU Core

File: `rtl/cpu_core.sv`

The CPU core is the first integrated datapath. It connects the fetch unit, instruction decoder, control unit, register file, 32-bit ALU and data memory into a simple single-cycle execution path.

Interface summary:

- `clk`: clock input.
- `rst`: active-high synchronous reset passed to the fetch unit and register file.
- `enable`: enables instruction fetch and PC advance.
- `IMEM_DEPTH`: forwarded instruction memory depth parameter, defaulting to 256 words.
- `IMEM_INIT_FILE`: forwarded instruction memory hex init-file path, defaulting to an empty string.
- `pc`: current 32-bit program counter debug output.
- `instruction`: fetched 32-bit instruction debug output.
- `opcode`, `rd`, `rs1`, `rs2`, `imm_ext`: decoded instruction debug outputs.
- `reg_write`, `use_imm`, `alu_op`, `valid_instr`: control debug outputs.
- `alu_result`: 32-bit ALU result debug output.

Datapath behaviour:

- `fetch_unit` supplies `pc` and `instruction`, with optional file-based instruction memory initialisation.
- `instruction_decoder` extracts opcode, register fields and sign-extended immediate.
- `control_unit` maps opcode to register write, immediate select, ALU operation, memory access, branch, jump and valid-instruction control signals.
- `register_file` reads `rs1` and `rs2`.
- ALU input A is register file read port A.
- ALU input B is either register file read port B or `imm_ext`, selected by `use_imm`.
- The ALU result is used directly for arithmetic/logical writeback and as the data memory address for LOAD and STORE.
- `data_memory` reads or writes using the ALU result address.
- STORE writes register file read port B data to data memory.
- LOAD selects data memory read data for register writeback through `mem_to_reg`.
- Non-memory ALU instructions select the ALU result for register writeback.
- Register file write enable is `reg_write && valid_instr`.
- `pc_plus_4 = pc + 32'd4`.
- `pc_target = pc + (imm_ext << 2)`, where `imm_ext` is signed and counts instruction words.
- BEQ takes the PC target when `branch && valid_instr && (rdata_a == rdata_b)`.
- JUMP always takes the PC target when `jump && valid_instr`.
- `next_pc` selects `pc_target` for a taken branch or valid jump, otherwise `pc_plus_4`.

This first core supports NOP, ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ and JUMP using the existing instruction format. Invalid opcodes are blocked from register and memory writeback by `valid_instr`, and writes to `x0` remain blocked inside the register file. The core does not include hazards, stalls or pipelining yet.

The `programs/load_store_test.mem` program image exercises the current LOAD/STORE path through the `IMEM_INIT_FILE` parameter path. This allows CPU programs to be kept as standalone hex files instead of being inserted directly into a testbench.
The `programs/branch_jump_test.mem` program image exercises BEQ, JUMP and not-taken branch behaviour through the same file-loaded instruction path.

## Phase 5 Program Execution System

Phase 5 added standalone memory-system modules and a runnable top-level program execution wrapper without refactoring the already working `cpu_core`.

Files:

- `rtl/instr_mem.sv`
- `rtl/data_mem.sv`
- `rtl/cpu_top.sv`
- `programs/add_test.mem`
- `tb/tb_instr_mem.sv`
- `tb/tb_data_mem.sv`
- `tb/tb_program_execution.sv`

The important design choice is that `cpu_top.sv` wraps the existing integrated `cpu_core`. The existing `cpu_core` already contains the fetch, instruction-memory and data-memory path using `fetch_unit`, `instruction_memory` and `data_memory`. The standalone `instr_mem.sv` and `data_mem.sv` modules document and test the memory-system concepts independently.

The Phase 5 program executes:

```text
ADDI  x1, x0, 5
ADDI  x2, x0, 7
ADD   x3, x1, x2
STORE x3, [x0 + 0]
NOP
```

Expected final architectural state:

- `x1 = 5`
- `x2 = 7`
- `x3 = 12`
- data memory word 0 = `32'd12`

This proved that the CPU could execute a small multi-instruction program in simulation.

## Phase 6 Program-Level ISA Verification

Phase 6 expanded verification from individual modules and one program into a broader custom-ISA program suite. The CPU architecture and instruction encodings were kept unchanged.

The Phase 6 program suite covers:

| Phase | Program Focus | Main Architecture Behaviour Verified |
| --- | --- | --- |
| 6A | Arithmetic edge cases | ADDI, ADD, SUB, negative immediates, wraparound/underflow and `x0` protection. |
| 6B | Memory offsets | LOAD/STORE base + 0, base + 4 and negative offset addressing. |
| 6C | Branch control | BEQ taken and BEQ not-taken behaviour. |
| 6D | Jump control | Forward JUMP and skipped-instruction protection. |
| 6E | Simple loop | Repeated ADD/SUB, BEQ loop exit, backward JUMP and final STORE. |
| 6F | Invalid opcode safety | Invalid opcodes keep `valid_instr` low and do not write registers or data memory. |

This suite became the functional baseline that the later multi-cycle CPU had to preserve.

## Phase 7 FPGA Baseline And Timing Evidence

Phase 7 froze the verified simulation baseline and built the original `fpga_top` path for the Basys 3.

Baseline FPGA configuration:

- Target board: Digilent Basys 3.
- FPGA part: `xc7a35tcpg236-1`.
- Top module: `fpga_top`.
- Constraint file: `constraints/basys3.xdc`.
- Target clock: 10.000 ns, 100 MHz.

Phase 7C implementation completed and generated a bitstream for the original single-cycle-style CPU path. The design fit comfortably in the device:

| Resource | Phase 7C post-route usage |
| --- | ---: |
| LUTs | 2,983 / 20,800, 14.34% |
| FFs | 8,314 / 41,600, 19.99% |
| BRAM | 0 / 50, 0.00% |
| DSP | 0 / 90, 0.00% |

However, Phase 7D timing analysis showed that setup timing did not meet 100 MHz:

| Timing Metric | Phase 7C/7D Result |
| --- | ---: |
| WNS | -1.551 ns |
| TNS | -5707.315 ns |
| WHS | 0.075 ns |
| Estimated max frequency | approximately 86.6 MHz |

The worst path was classified as a single-cycle-style PC/fetch/decode/execute/writeback path:

```text
cpu_inst/fetch_inst/pc_inst/pc_reg[30]/C
to
cpu_inst/reg_file_inst/regs_reg[2][12]/D
```

This result did not mean the simulated CPU behaviour was wrong. It showed that the simple educational single-cycle-style datapath was too long for the 100 MHz FPGA target after routing.

## Phase 8 Multi-Cycle CPU Architecture

Phase 8 introduced a separate multi-cycle CPU rather than replacing the original `cpu_core`.

File:

- `rtl/cpu_core_multicycle.sv`

The multi-cycle CPU preserves:

- The same 32-bit instruction format.
- The same opcode map.
- The same `x0` zero-register behaviour.
- The same signed `imm13` immediate convention.
- The same branch/jump target convention: `instruction_pc + (imm_ext << 2)`.
- The same invalid-opcode safety requirement.

It adds internal registers so one instruction can be executed over several shorter cycles:

- `instruction_reg`: stores the fetched instruction.
- `instruction_pc`: stores the PC of the current instruction.
- Decoded field registers: `opcode_reg`, `rd_reg`, `rs1_reg`, `rs2_reg`, `imm13_reg`, `imm_ext_reg`.
- Operand registers: `operand_a_reg`, `operand_b_reg`.
- `alu_result_reg`: stores arithmetic results or effective addresses.
- `memory_read_data_reg`: stores loaded data before writeback.
- `state`: stores the current FSM state.
- Internal `regs[0:31]`: register file storage.
- Internal `data_mem[0:255]`: data memory storage.

### Multi-Cycle FSM States

The multi-cycle CPU uses these states:

| State | Purpose |
| --- | --- |
| `FETCH` | Capture `fetched_instruction`, capture `instruction_pc`, and advance PC by 4 for the default sequential path. |
| `DECODE` | Decode instruction fields, sign-extend `imm13`, read source operands and decide the next state. |
| `EXECUTE` | Perform ALU operation, calculate effective address, or evaluate branch/jump target. |
| `MEMORY` | Perform LOAD read capture or STORE write. |
| `WRITEBACK` | Write arithmetic or LOAD result to `rd`, unless `rd` is `x0`. |

Instruction state sequences:

| Instruction | Multi-cycle sequence |
| --- | --- |
| NOP | FETCH -> DECODE -> FETCH |
| ADD/SUB/AND/OR/XOR | FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH |
| ADDI | FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH |
| LOAD | FETCH -> DECODE -> EXECUTE -> MEMORY -> WRITEBACK -> FETCH |
| STORE | FETCH -> DECODE -> EXECUTE -> MEMORY -> FETCH |
| BEQ | FETCH -> DECODE -> EXECUTE -> FETCH |
| JUMP | FETCH -> DECODE -> EXECUTE -> FETCH |
| Invalid opcode | FETCH -> DECODE -> FETCH |

### Multi-Cycle Control Flow

During FETCH, the PC is advanced to `pc + 4` by default. The current instruction's PC is captured separately as `instruction_pc`.

BEQ and JUMP target calculation uses the captured instruction PC:

```text
pc_target = instruction_pc + (imm_ext_reg << 2)
```

For BEQ:

```text
if (operand_a_reg == operand_b_reg)
    pc = pc_target
```

For JUMP:

```text
pc = pc_target
```

This preserves the original PC-relative branch/jump convention while allowing the default sequential PC update to happen earlier in FETCH.

### Multi-Cycle Verification Progress

The separate multi-cycle CPU was verified incrementally:

| Phase | Verification Scope | Result |
| --- | --- | --- |
| 8B | FSM skeleton, reset, NOP, invalid opcode and sequential PC stepping | Passed |
| 8C | ADD, SUB, AND, OR, XOR, ADDI and `x0` protection | Passed |
| 8D | LOAD/STORE memory execution and negative offset load | Passed |
| 8E | BEQ taken/not-taken, forward/backward JUMP and loop execution | Passed |
| 8F | Full custom-ISA program suite equivalent to Phase 6 behaviours | Passed |

Phase 8F confirmed that the multi-cycle CPU passes full custom-ISA program verification across arithmetic, memory, branch, jump, loop and invalid-opcode safety scenarios.

## Phase 8G Multi-Cycle FPGA Path

Phase 8G added a separate FPGA implementation path for the multi-cycle CPU.

Files:

- `rtl/fpga_top_multicycle.sv`
- `scripts/run_vivado_synth_multicycle.tcl`
- `scripts/run_vivado_impl_multicycle.tcl`
- `reports/phase8g_multicycle_timing_comparison.md`

The new wrapper keeps the same Basys 3 external ports as `fpga_top`:

- `clk`
- `rst_btn`
- `enable_sw`
- `led[15:0]`

It instantiates:

- `slow_tick_generator`
- `cpu_core_multicycle`
- a local 256-word instruction memory initialised from `programs/fpga_led_demo.mem`

The multi-cycle FPGA wrapper still uses the real Basys 3 100 MHz clock. It does not create a divided clock. CPU execution is still gated with a slow enable pulse:

```text
cpu_enable = enable_sw && slow_tick
```

The multi-cycle LED mapping is:

| LED bits | Signal |
| --- | --- |
| `led[3:0]` | `pc[5:2]` |
| `led[7:4]` | `opcode_reg` |
| `led[8]` | `valid_instr` |
| `led[9]` | `reg_write` |
| `led[10]` | `mem_write` |
| `led[13:11]` | `state` |
| `led[15:14]` | `alu_result[1:0]` |

This differs from the original `fpga_top` LED mapping because the multi-cycle CPU has explicit FSM state and does not use the original `use_imm`/`alu_op` debug interface.

### Phase 8G FPGA Result

Phase 8G synthesis and implementation completed for `fpga_top_multicycle` using the same Basys 3 part and constraints.

Post-route utilisation:

| Resource | Phase 8G post-route usage |
| --- | ---: |
| LUTs | 3,027 / 20,800, 14.55% |
| FFs | 8,654 / 41,600, 20.80% |
| BRAM | 0 / 50, 0.00% |
| DSP | 0 / 90, 0.00% |

Post-route timing:

| Timing Metric | Phase 8G Result |
| --- | ---: |
| WNS | 1.389 ns |
| TNS | 0.000 ns |
| WHS | 0.038 ns |
| THS | 0.000 ns |
| Estimated max frequency | approximately 116.1 MHz |
| 100 MHz setup timing | Met |

The worst Phase 8G path is now a multi-cycle memory-read path:

```text
cpu_inst/alu_result_reg_reg[6]/C
to
cpu_inst/memory_read_data_reg_reg[22]/D
```

This is no longer the full PC/fetch/decode/execute/writeback path from the Phase 7 baseline.

### Phase 7 Versus Phase 8G Comparison

| Metric | Phase 7 single-cycle-style baseline | Phase 8G multi-cycle path |
| --- | ---: | ---: |
| LUTs | 2,983 | 3,027 |
| FFs | 8,314 | 8,654 |
| BRAM | 0 | 0 |
| DSP | 0 | 0 |
| WNS | -1.551 ns | 1.389 ns |
| TNS | -5707.315 ns | 0.000 ns |
| 100 MHz setup timing | Not met | Met |
| Estimated max frequency | ~86.6 MHz | ~116.1 MHz |

The multi-cycle path uses slightly more LUTs and flip-flops, but it meets timing at 100 MHz. This supports the Phase 8 architecture direction as the preferred timing-closure path, subject to supervisor review and later hardware validation.

## Current Architecture Direction

The project now has two useful architecture baselines:

1. Original single-cycle-style baseline

   - Simpler to explain and useful as the first complete CPU integration.
   - Fully verified in simulation through Phase 6.
   - Builds to bitstream for Basys 3.
   - Does not meet 100 MHz post-route timing.

2. Separate multi-cycle implementation

   - Preserves the same custom ISA and program behaviours.
   - Verified through full Phase 8F program testing.
   - Builds to bitstream through the separate Phase 8G FPGA path.
   - Meets 100 MHz post-route timing in the Phase 8G implementation result.

The likely next architecture decision is whether to make the multi-cycle path the preferred FPGA implementation path after supervisor review and, later, physical board bring-up.

## Remaining Architecture Decisions

- Whether to use `fpga_top_multicycle` rather than `fpga_top` for the first timing-clean hardware demonstration.
- Whether to keep the current register-array memory structures or redesign instruction/data memories to infer FPGA block RAM more cleanly.
- Whether to add a small assembler or program-generation script to reduce manual `.mem` encoding errors.
- Whether status flags are needed for future ISA extensions.
- Whether pipelining is useful as a later extension after the multi-cycle design is documented.
- Whether to add external bus, UART, memory-mapped I/O or debug interfaces after basic board validation.
- How to record and compare physical Basys 3 behaviour once the board is available.
