# Verification Notes

## ALU Functional Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `tb/alu_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- ADD zero, basic add and 32-bit wraparound.
- SUB zero, basic subtract and 32-bit underflow.
- AND bit patterns.
- OR bit patterns.
- XOR bit patterns.
- Invalid/default opcodes `3'b101`, `3'b110` and `3'b111`.

Result:

- The updated parameterised 32-bit ALU testbench passed in Vivado XSim.
- Console summary:
  - `Tests run:    27`
  - `Tests failed: 0`
  - `ALU TEST PASSED`

Commands to run from the repository root in a Vivado-enabled PowerShell:

```powershell
xvlog -sv rtl/alu.sv tb/alu_tb.sv
xelab alu_tb -s alu_tb_sim
xsim alu_tb_sim -runall
```

Waveform notes:

- The generated waveform file is `alu_tb.vcd`.
- The refreshed ALU waveform image is saved as `docs/images/alu_waveform.png`.

Conclusion:

The parameterised ALU aligns with the 32-bit register file and CPU datapath, and the updated 32-bit functional simulation passed.

## Register File Functional Simulation

Status: passed.

Files tested:

- `rtl/register_file.sv`
- `tb/register_file_tb.sv`

Simulator:

- Vivado XSim

Tests covered:

- Reset clears registers.
- Register `x0` is hardwired to zero.
- Writes to `x0` are ignored.
- Writes and reads across registers `x1` to `x31`.
- Both asynchronous read ports reading different registers.
- Both asynchronous read ports reading the same register.
- Disabled write preserves existing data.
- Overwrite of an existing register.
- Read-before-write and read-after-write clock behaviour.
- Second reset clears written register contents.

Result:

- Console output included: "All 55 register file checks passed."
- Simulation completed at 457 ns.
- A VCD waveform was generated.

Waveform notes:

- The generated waveform file is `register_file_tb.vcd`.
- The register file waveform image is saved as `docs/images/register_file_waveform.png`.

Conclusion:

Initial register file functional simulation passed.

## Program Counter Functional Simulation

Status: passed.

Files tested:

- `rtl/program_counter.sv`
- `tb/program_counter_tb.sv`

Simulator:

- Vivado XSim

Tests covered:

- Synchronous reset loads `RESET_ADDR`.
- Normal PC update to `32'h0000_0004`.
- PC increment behaviour using `pc + 32'd4`.
- `enable = 0` holds the current PC value.
- Custom `next_pc` load to `32'h0000_0100`.
- Final reset reloads `RESET_ADDR`.

Result:

- Console output included: "PROGRAM COUNTER TEST PASSED."
- Testbench summary reported 6 tests run and 0 tests failed.
- Simulation completed at 66 ns.
- A VCD waveform was generated.

Waveform notes:

- The generated waveform file is `program_counter_tb.vcd`.
- The program counter waveform image is saved as `docs/images/program_counter_waveform.png`.

Conclusion:

Initial program counter functional simulation passed.

## Instruction Memory Functional Simulation

Status: passed.

Files tested:

- `rtl/instruction_memory.sv`
- `tb/instruction_memory_tb.sv`

Simulator:

- Vivado XSim

Tests covered:

- Direct testbench initialisation of DUT memory words 0 to 3.
- Byte address `0` maps to word 0.
- Byte address `4` maps to word 1.
- Byte address `8` maps to word 2.
- Byte address `12` maps to word 3.
- Unaligned byte addresses `1`, `2` and `5` map through `addr[31:2]`.
- Unwritten memory locations return zero.
- Out-of-range addresses return zero.

Result:

- Console output included: "INSTRUCTION MEMORY TEST PASSED."
- Testbench summary reported 9 tests run and 0 tests failed.
- Simulation completed at 11 ns.
- A VCD waveform was generated.

Waveform notes:

- The generated waveform file is `instruction_memory_tb.vcd`.
- The instruction memory waveform image is saved as `docs/images/instruction_memory_waveform.png`.

Conclusion:

Initial instruction memory functional simulation passed.

## Fetch Unit Functional Simulation

Status: passed.

Files tested:

- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/fetch_unit.sv`
- `tb/fetch_unit_tb.sv`

Simulator:

- Vivado XSim

Tests covered:

- Testbench preload of instruction memory words 0 to 3.
- Reset returns `pc` to `32'h0000_0000`.
- Reset fetches instruction word 0.
- Sequential fetch advances to PC values `32'h0000_0004`, `32'h0000_0008` and `32'h0000_000c`.
- Sequential fetch returns instruction values `32'h2222_2222`, `32'h3333_3333` and `32'h4444_4444`.
- `enable = 0` holds the PC and instruction.
- Final reset returns fetch state to PC 0 and instruction word 0.

Result:

- Console output included: "FETCH UNIT TEST PASSED."
- Testbench summary reported 6 tests run and 0 tests failed.
- Simulation completed at 66 ns.
- A VCD waveform was generated.

Waveform notes:

- The generated waveform file is `fetch_unit_tb.vcd`.
- The fetch unit waveform image is saved as `docs/images/fetch_unit_waveform.png`.

Conclusion:

Initial fetch unit integration simulation passed.

## Instruction Decoder Functional Simulation

Status: passed.

Files tested:

- `rtl/instruction_decoder.sv`
- `tb/instruction_decoder_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- NOP decode.
- ADD, SUB, AND, OR, XOR and ADDI opcode decode.
- Register field extraction for `rd`, `rs1` and `rs2`.
- Positive immediate sign extension.
- Negative immediate sign extension with `imm13 = 13'h1fff`, producing `imm_ext = 32'hffff_ffff`.
- Edge register values with `rd = 31`, `rs1 = 31` and `rs2 = 31`.

Result:

- Console output included: "INSTRUCTION DECODER TEST PASSED."
- Testbench summary reported 9 tests run and 0 tests failed.
- Simulation completed at 9 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/instruction_decoder.sv tb/instruction_decoder_tb.sv
xelab instruction_decoder_tb -s instruction_decoder_tb_sim
xsim instruction_decoder_tb_sim -runall
```

Waveform notes:

- The generated waveform file is `instruction_decoder_tb.vcd`.

Conclusion:

Initial instruction decoder functional simulation passed.

## Control Unit Functional Simulation

Status: passed.

Files tested:

- `rtl/control_unit.sv`
- `tb/control_unit_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- NOP control outputs.
- ADD, SUB, AND, OR and XOR register-register ALU control outputs.
- ADDI immediate-operand control outputs.
- Invalid opcode defaults for `4'h7` and `4'hf`.

Result:

- Console output included: "CONTROL UNIT TEST PASSED."
- Testbench summary reported 9 tests run and 0 tests failed.
- Simulation completed at 9 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/control_unit.sv tb/control_unit_tb.sv
xelab control_unit_tb -s control_unit_tb_sim
xsim control_unit_tb_sim -runall
```

Waveform notes:

- The generated waveform file is `control_unit_tb.vcd`.

Conclusion:

Initial control unit functional simulation passed.

## CPU Core Functional Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `rtl/register_file.sv`
- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/fetch_unit.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/cpu_core.sv`
- `tb/cpu_core_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Integrated fetch, decode, control, register read, ALU execution and register writeback.
- Program preload through `dut.fetch_inst.imem.mem`.
- ADDI writeback to `x1` and `x2`.
- ADD using `x1` and `x2`.
- SUB using `x3` and `x1`.
- XOR using `x1` and `x2`.
- Final register checks through `dut.reg_file_inst.regs`.

Program tested:

- `ADDI x1, x0, 5`
- `ADDI x2, x0, 7`
- `ADD  x3, x1, x2`
- `SUB  x4, x3, x1`
- `XOR  x5, x1, x2`

Result:

- Console output included: "CPU CORE TEST PASSED."
- Testbench summary reported 5 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x1 = 32'h0000_0005`
  - `x2 = 32'h0000_0007`
  - `x3 = 32'h0000_000c`
  - `x4 = 32'h0000_0007`
  - `x5 = 32'h0000_0002`
- Simulation completed at 66 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/alu.sv rtl/register_file.sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/fetch_unit.sv rtl/instruction_decoder.sv rtl/control_unit.sv rtl/cpu_core.sv tb/cpu_core_tb.sv
xelab cpu_core_tb -s cpu_core_tb_sim
xsim cpu_core_tb_sim -runall
```

Waveform notes:

- The generated waveform file is `cpu_core_tb.vcd`.

Conclusion:

Initial CPU core integration simulation passed.

## Future Verification Work

- Add verification entries for each new RTL module.
- Save useful waveform screenshots in `docs/images/`.
- Keep testbenches self-checking.
- Use `$fatal` or an equivalent failure mechanism when checks fail.
- Record simulator, files tested, coverage points and conclusions for each simulation.
