# Verification Notes

## ALU Functional Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `tb/alu_tb.sv`

Simulator:

- Vivado XSim

Tests covered:

- ADD
- SUB
- AND
- OR
- XOR
- Invalid/default opcodes

Result:

- ADD, SUB, AND, OR, XOR and invalid/default opcode tests passed.
- Console output included: "All ALU tests passed."
- The upgraded testbench currently reports: "All 27 ALU tests passed."
- A VCD waveform was generated and viewed.

Waveform notes:

- The generated waveform file is `alu_tb.vcd`.
- The ALU waveform image is saved as `docs/images/alu_waveform.png`.

Conclusion:

Initial ALU functional simulation passed.

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

## Future Verification Work

- Add verification entries for each new RTL module.
- Save useful waveform screenshots in `docs/images/`.
- Keep testbenches self-checking.
- Use `$fatal` or an equivalent failure mechanism when checks fail.
- Record simulator, files tested, coverage points and conclusions for each simulation.
