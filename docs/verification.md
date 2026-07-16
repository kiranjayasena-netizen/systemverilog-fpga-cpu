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

## Data Memory Functional Simulation

Status: passed.

Files tested:

- `rtl/data_memory.sv`
- `tb/data_memory_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Reset clears memory words.
- Write and read word 0.
- Write and read word 1.
- Word 0 remains unchanged after writing word 1.
- Overwrite of word 0.
- Unaligned byte address `1` maps to word 0.
- Unaligned byte address `5` maps to word 1.
- `mem_read = 0` returns zero.
- Disabled write does not update memory.
- Out-of-range read returns zero.
- Out-of-range write does not corrupt valid memory.

Result:

- Console output included: "DATA MEMORY TEST PASSED."
- Testbench summary reported 13 tests run and 0 tests failed.
- Simulation completed at 201 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/data_memory.sv tb/data_memory_tb.sv
xelab data_memory_tb -s data_memory_tb_sim
xsim data_memory_tb_sim -runall
```

Waveform notes:

- The generated waveform file is `data_memory_tb.vcd`.

Conclusion:

Initial data memory functional simulation passed.

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
- External `next_pc` drive into `fetch_unit`.
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

Commands rerun after adding external next-PC support:

```powershell
xvlog -sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/fetch_unit.sv tb/fetch_unit_tb.sv
xelab fetch_unit_tb -s fetch_unit_branch_sim
xsim fetch_unit_branch_sim -runall
```

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
xvlog -sv rtl/cpu_defs_pkg.sv rtl/instruction_decoder.sv tb/instruction_decoder_tb.sv
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
- LOAD memory-read and memory-to-register control outputs.
- STORE memory-write control outputs.
- BEQ branch control output.
- JUMP control output.
- Invalid opcode defaults for `4'hb` and `4'hf`.

Result:

- Console output included: "CONTROL UNIT TEST PASSED."
- Testbench summary reported 13 tests run and 0 tests failed.
- Simulation completed at 13 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv rtl/control_unit.sv tb/control_unit_tb.sv
xelab control_unit_tb -s control_unit_branch_sim
xsim control_unit_branch_sim -runall
```

Waveform notes:

- The generated waveform file is `control_unit_tb.vcd`.

Conclusion:

Control unit LOAD/STORE and BEQ/JUMP functional simulation passed.

## CPU Core Functional Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `rtl/register_file.sv`
- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/data_memory.sv`
- `rtl/fetch_unit.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/cpu_core.sv`
- `tb/cpu_core_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Integrated fetch, decode, control, register read, ALU execution and register writeback.
- Integrated data memory read, data memory write and memory-to-register writeback.
- Program preload through `dut.fetch_inst.imem.mem`.
- ADDI immediate path.
- ADD register-register path.
- SUB register-register path.
- AND register-register path.
- OR register-register path.
- XOR register-register path.
- Negative immediate sign extension.
- Register `x0` write protection.
- Invalid opcode protection through disabled register writeback.
- NOP execution without state corruption.
- Final PC check after 11 instructions.
- LOAD from `[rs1 + imm13]`.
- STORE to `[rs1 + imm13]`.
- LOAD using negative sign-extended offset `imm13 = 13'h1ffc`.
- Final data memory checks through `dut.data_mem_inst.mem`.
- Final register checks through `dut.reg_file_inst.regs`.

Programs tested:

Strengthened ALU/register program:

- `ADDI x1, x0, 15`
- `ADDI x2, x0, 10`
- `ADD  x3, x1, x2`
- `SUB  x4, x1, x2`
- `AND  x5, x1, x2`
- `OR   x6, x1, x2`
- `XOR  x7, x1, x2`
- `ADDI x8, x0, -1`
- `ADDI x0, x0, 99`
- Invalid opcode `4'hf` writing `x9`
- `NOP`

LOAD/STORE program:

- `ADDI  x1, x0, 64`
- `ADDI  x2, x0, 123`
- `STORE x2, [x1 + 0]`
- `LOAD  x3, [x1 + 0]`
- `ADDI  x4, x0, 68`
- `LOAD  x5, [x4 - 4]`
- `STORE x3, [x1 + 4]`
- `LOAD  x6, [x1 + 4]`
- `NOP`

Result:

- Console output included: "CPU CORE TEST PASSED."
- Testbench summary reported 19 tests run and 0 tests failed.
- Strengthened ALU/register final values matched expectations:
  - `x0 = 32'h0000_0000`
  - `x1 = 32'h0000_000f`
  - `x2 = 32'h0000_000a`
  - `x3 = 32'h0000_0019`
  - `x4 = 32'h0000_0005`
  - `x5 = 32'h0000_000a`
  - `x6 = 32'h0000_000f`
  - `x7 = 32'h0000_0005`
  - `x8 = 32'hffff_ffff`
  - `x9 = 32'h0000_0000`
- Final PC matched `32'h0000_002c`.
- LOAD/STORE final values matched expectations:
  - `x1 = 32'd64`
  - `x2 = 32'd123`
  - `x3 = 32'd123`
  - `x4 = 32'd68`
  - `x5 = 32'd123`
  - `x6 = 32'd123`
  - `data_mem_inst.mem[16] = 32'd123`
  - `data_mem_inst.mem[17] = 32'd123`
- Simulation completed at 241 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv rtl/alu.sv rtl/register_file.sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/data_memory.sv rtl/fetch_unit.sv rtl/instruction_decoder.sv rtl/control_unit.sv rtl/cpu_core.sv tb/cpu_core_tb.sv
xelab cpu_core_tb -s cpu_core_regression_sim
xsim cpu_core_regression_sim -runall
```

Waveform notes:

- The generated waveform file is `cpu_core_tb.vcd`.

Conclusion:

CPU core LOAD/STORE integration simulation passed.

## CPU Core File-Loaded Program Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `rtl/register_file.sv`
- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/data_memory.sv`
- `rtl/fetch_unit.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/cpu_core.sv`
- `programs/load_store_test.mem`
- `tb/cpu_core_program_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Instruction memory program loading through `IMEM_INIT_FILE`.
- CPU core parameter forwarding through `cpu_core` and `fetch_unit`.
- LOAD/STORE base-plus-offset execution using the standalone program file.
- Negative sign-extended LOAD offset using `imm13 = 13'h1ffc`.
- Register checks for `x1`, `x2`, `x3`, `x4`, `x5` and `x6`.
- Data memory checks for words 16 and 17.

Program tested:

- `programs/load_store_test.mem`

Result:

- Console output included: "CPU CORE PROGRAM TEST PASSED."
- Testbench summary reported 8 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x1 = 32'd64`
  - `x2 = 32'd123`
  - `x3 = 32'd123`
  - `x4 = 32'd68`
  - `x5 = 32'd123`
  - `x6 = 32'd123`
- Final data memory values matched expectations:
  - `data_mem_inst.mem[16] = 32'd123`
  - `data_mem_inst.mem[17] = 32'd123`
- Simulation completed at 111 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv rtl/alu.sv rtl/register_file.sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/data_memory.sv rtl/fetch_unit.sv rtl/instruction_decoder.sv rtl/control_unit.sv rtl/cpu_core.sv tb/cpu_core_program_tb.sv
xelab cpu_core_program_tb -s cpu_core_program_regression_sim
xsim cpu_core_program_regression_sim -runall
```

Waveform notes:

- The generated waveform file is `cpu_core_program_tb.vcd`.

Conclusion:

CPU core file-based instruction program loading simulation passed.

## CPU Core Branch/Jump Integration Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `rtl/register_file.sv`
- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/data_memory.sv`
- `rtl/fetch_unit.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/cpu_core.sv`
- `tb/cpu_core_branch_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- BEQ taken when `rs1 == rs2`.
- PC-relative branch target calculation using `pc + (imm_ext << 2)`.
- JUMP target calculation using the same signed word-offset path.
- Skipped instruction protection for branch and jump paths.
- Not-taken BEQ falls through to `pc + 4`.
- Register `x0` remains hardwired to zero.

Program tested:

- `ADDI x1, x0, 5`
- `ADDI x2, x0, 5`
- `BEQ  x1, x2, +2`
- `ADDI x3, x0, 99`
- `ADDI x3, x0, 42`
- `JUMP +2`
- `ADDI x4, x0, 99`
- `ADDI x4, x0, 77`
- `NOP`
- `ADDI x5, x0, 1`
- `ADDI x6, x0, 2`
- `BEQ  x5, x6, +2`
- `ADDI x7, x0, 55`
- `NOP`

Result:

- Console output included: "CPU CORE BRANCH TEST PASSED."
- Testbench summary reported 8 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x0 = 32'd0`
  - `x1 = 32'd5`
  - `x2 = 32'd5`
  - `x3 = 32'd42`
  - `x4 = 32'd77`
  - `x7 = 32'd55`
- The test also confirmed `x3 != 32'd99` and `x4 != 32'd99`.
- Simulation completed at 161 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv rtl/alu.sv rtl/register_file.sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/data_memory.sv rtl/fetch_unit.sv rtl/instruction_decoder.sv rtl/control_unit.sv rtl/cpu_core.sv tb/cpu_core_branch_tb.sv
xelab cpu_core_branch_tb -s cpu_core_branch_sim
xsim cpu_core_branch_sim -runall
```

Waveform notes:

- The generated waveform file is `cpu_core_branch_tb.vcd`.

Conclusion:

CPU core BEQ/JUMP integration simulation passed.

## CPU Core File-Loaded Branch/Jump Program Simulation

Status: passed.

Files tested:

- `rtl/alu.sv`
- `rtl/register_file.sv`
- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/data_memory.sv`
- `rtl/fetch_unit.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/cpu_core.sv`
- `programs/branch_jump_test.mem`
- `tb/cpu_core_branch_program_tb.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded BEQ/JUMP program execution through `IMEM_INIT_FILE`.
- Taken BEQ skip path.
- JUMP skip path.
- Not-taken BEQ fall-through path.
- Final register checks through `dut.reg_file_inst.regs`.

Result:

- Console output included: "CPU CORE BRANCH PROGRAM TEST PASSED."
- Testbench summary reported 8 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x0 = 32'd0`
  - `x1 = 32'd5`
  - `x2 = 32'd5`
  - `x3 = 32'd42`
  - `x4 = 32'd77`
  - `x7 = 32'd55`
- The test also confirmed `x3 != 32'd99` and `x4 != 32'd99`.
- Simulation completed at 161 ns.
- A VCD waveform was generated.

Commands run from the repository root:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv rtl/alu.sv rtl/register_file.sv rtl/program_counter.sv rtl/instruction_memory.sv rtl/data_memory.sv rtl/fetch_unit.sv rtl/instruction_decoder.sv rtl/control_unit.sv rtl/cpu_core.sv tb/cpu_core_branch_program_tb.sv
xelab cpu_core_branch_program_tb -s cpu_core_branch_program_sim
xsim cpu_core_branch_program_sim -runall
```

Waveform notes:

- The generated waveform file is `cpu_core_branch_program_tb.vcd`.

Conclusion:

CPU core file-loaded BEQ/JUMP program simulation passed.

## Phase 5 Program Execution Simulation

Status: passed.

Files tested:

- `rtl/instr_mem.sv`
- `rtl/data_mem.sv`
- `rtl/cpu_top.sv`
- `programs/add_test.mem`
- `tb/tb_instr_mem.sv`
- `tb/tb_data_mem.sv`
- `tb/tb_program_execution.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Phase 5 instruction memory `$readmemh` loading from `programs/add_test.mem`.
- Byte-address to word-index mapping using `addr[9:2]`.
- Instruction memory out-of-range reads returning zero.
- Phase 5 data memory reset, synchronous write and combinational read behaviour.
- Data memory `mem_read = 0` returning zero.
- Data memory out-of-range writes being ignored.
- Full program execution through `cpu_top`.
- Final register checks for `x1 = 5`, `x2 = 7` and `x3 = 12`.
- Final data memory check that word 0 contains `32'd12`.

Program tested:

- `ADDI x1, x0, 5`
- `ADDI x2, x0, 7`
- `ADD  x3, x1, x2`
- `STORE x3, [x0 + 0]`
- `NOP`

Result:

- Full XSim regression completed successfully.
- `tb_instr_mem` reported 7 tests run and 0 tests failed.
- `tb_data_mem` reported 6 tests run and 0 tests failed.
- `tb_program_execution` reported 4 tests run and 0 tests failed.
- Console output included:
  - `PHASE 5 INSTRUCTION MEMORY TEST PASSED`
  - `PHASE 5 DATA MEMORY TEST PASSED`
  - `PHASE 5 PROGRAM EXECUTION TEST PASSED`

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Waveform notes:

- The generated waveform files are `tb_instr_mem.vcd`, `tb_data_mem.vcd` and `tb_program_execution.vcd`.
- Phase 5 waveform images generated from the VCD files are saved as:
  - `docs/images/phase5_instr_mem_waveform.png`
  - `docs/images/phase5_data_mem_waveform.png`
  - `docs/images/phase5_program_execution_waveform.png`

Conclusion:

Phase 5 program execution simulation passed. The CPU ran a small multi-instruction custom-ISA program and stored the expected result, `12`, in data memory word 0.

## Phase 6 Arithmetic Edge Program Simulation

Status: passed.

Files tested:

- `rtl/cpu_top.sv`
- `programs/arithmetic_edge_test.mem`
- `tb/tb_phase6_arithmetic_edge.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded custom-ISA program execution through `cpu_top`.
- ADDI with positive immediates.
- ADD register-register execution.
- SUB register-register execution.
- Negative immediate sign extension with `imm13 = 13'h1fff`.
- Arithmetic wraparound from adding `32'hffff_ffff` and `10`.
- SUB underflow from `x0 - x1`.
- Register `x0` write protection after an attempted `ADDI x0, x0, 123`.
- NOP at the end of the program.

Program tested:

- `ADDI x1, x0, 10`
- `ADDI x2, x0, 20`
- `ADD  x3, x1, x2`
- `SUB  x4, x2, x1`
- `ADDI x5, x0, -1`
- `ADD  x6, x5, x1`
- `SUB  x7, x0, x1`
- `ADDI x0, x0, 123`
- `ADD  x8, x0, x3`
- `NOP`

Result:

- Full XSim regression completed successfully.
- `tb_phase6_arithmetic_edge` reported 9 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x0 = 32'h0000_0000`
  - `x1 = 32'd10`
  - `x2 = 32'd20`
  - `x3 = 32'd30`
  - `x4 = 32'd10`
  - `x5 = 32'hffff_ffff`
  - `x6 = 32'd9`
  - `x7 = 32'hffff_fff6`
  - `x8 = 32'd30`
- Console output included `PHASE 6 ARITHMETIC EDGE TEST PASSED`.

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Waveform notes:

- The generated waveform file is `tb_phase6_arithmetic_edge.vcd`.

Conclusion:

The first Phase 6 custom-ISA program test passed. It extends program-level verification beyond the Phase 5 add/store demo by checking arithmetic edge cases, negative immediate sign extension and `x0` write protection.

## Phase 6B Memory Offset Program Simulation

Status: passed.

Files tested:

- `rtl/cpu_top.sv`
- `programs/memory_offset_test.mem`
- `tb/tb_phase6_memory_offset.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded custom-ISA program execution through `cpu_top`.
- ADDI base-address setup.
- STORE to `[base + 0]`.
- LOAD from `[base + 0]`.
- STORE to `[base + 4]`.
- LOAD from `[base + 4]`.
- LOAD using negative sign-extended offset `imm13 = 13'h1ffc`.
- Final data memory word checks.
- NOP at the end of the program.

Program tested:

- `ADDI  x1, x0, 64`
- `ADDI  x2, x0, 123`
- `STORE x2, [x1 + 0]`
- `LOAD  x3, [x1 + 0]`
- `STORE x3, [x1 + 4]`
- `LOAD  x4, [x1 + 4]`
- `ADDI  x5, x0, 68`
- `LOAD  x6, [x5 - 4]`
- `NOP`

Result:

- Full XSim regression completed successfully.
- `tb_phase6_memory_offset` reported 8 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x1 = 32'd64`
  - `x2 = 32'd123`
  - `x3 = 32'd123`
  - `x4 = 32'd123`
  - `x5 = 32'd68`
  - `x6 = 32'd123`
- Final data memory values matched expectations:
  - `data_mem_inst.mem[16] = 32'd123`
  - `data_mem_inst.mem[17] = 32'd123`
- Console output included `PHASE 6B MEMORY OFFSET TEST PASSED`.

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase6b_memory_offset_xsim_regression_20260708_104659.txt`

Waveform notes:

- The generated waveform file is `tb_phase6_memory_offset.vcd`.

Conclusion:

The second Phase 6 custom-ISA program test passed. It verifies LOAD/STORE base-plus-offset addressing, including a negative offset load, using the same file-loaded CPU program path as the Phase 5 and first Phase 6 tests.

## Phase 6C Branch Control Program Simulation

Status: passed.

Files tested:

- `rtl/cpu_top.sv`
- `programs/branch_taken_not_taken_test.mem`
- `tb/tb_phase6_branch_control.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded custom-ISA program execution through `cpu_top`.
- BEQ taken when `rs1 == rs2`.
- Taken BEQ skips the following instruction.
- BEQ not taken when `rs1 != rs2`.
- Fall-through execution after a not-taken BEQ.
- Register `x0` remains zero.
- Explicit check that skipped `ADDI x3, x0, 99` did not remain in `x3`.
- NOP at the end of the program.

Program tested:

- `ADDI x1, x0, 5`
- `ADDI x2, x0, 5`
- `BEQ  x1, x2, +2`
- `ADDI x3, x0, 99`
- `ADDI x3, x0, 42`
- `ADDI x4, x0, 1`
- `ADDI x5, x0, 2`
- `BEQ  x4, x5, +2`
- `ADDI x6, x0, 77`
- `ADDI x7, x0, 88`
- `NOP`

Result:

- Full XSim regression completed successfully.
- `tb_phase6_branch_control` reported 9 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x0 = 32'd0`
  - `x1 = 32'd5`
  - `x2 = 32'd5`
  - `x3 = 32'd42`
  - `x4 = 32'd1`
  - `x5 = 32'd2`
  - `x6 = 32'd77`
  - `x7 = 32'd88`
- Console output included `PHASE 6C BRANCH CONTROL TEST PASSED`.

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase6c_branch_control_xsim_regression_20260708_112418.txt`

Waveform notes:

- The generated waveform file is `tb_phase6_branch_control.vcd`.

Conclusion:

The Phase 6C custom-ISA program test passed. It verifies both taken and not-taken BEQ control flow through a file-loaded CPU program without changing CPU RTL or instruction encodings.

## Phase 6D Jump Control Program Simulation

Status: passed.

Files tested:

- `rtl/cpu_top.sv`
- `programs/jump_test.mem`
- `tb/tb_phase6_jump_control.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded custom-ISA program execution through `cpu_top`.
- Unconditional JUMP with positive PC-relative offset.
- First JUMP skips `ADDI x2, x0, 99`.
- Second JUMP skips `ADDI x4, x0, 99`.
- Register `x0` remains zero.
- Explicit checks that skipped values `99` did not remain in `x2` or `x4`.
- NOP at the end of the program.

Program tested:

- `ADDI x1, x0, 11`
- `JUMP +2`
- `ADDI x2, x0, 99`
- `ADDI x2, x0, 22`
- `ADDI x3, x0, 33`
- `JUMP +2`
- `ADDI x4, x0, 99`
- `ADDI x4, x0, 44`
- `NOP`

Result:

- Full XSim regression completed successfully.
- `tb_phase6_jump_control` reported 7 tests run and 0 tests failed.
- Final register values matched expectations:
  - `x0 = 32'd0`
  - `x1 = 32'd11`
  - `x2 = 32'd22`
  - `x3 = 32'd33`
  - `x4 = 32'd44`
- Console output included `PHASE 6D JUMP CONTROL TEST PASSED`.

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase6d_jump_control_xsim_regression_20260708_114112.txt`

Waveform notes:

- The generated waveform file is `tb_phase6_jump_control.vcd`.

Conclusion:

The Phase 6D custom-ISA program test passed. It verifies unconditional JUMP control flow through a file-loaded CPU program without changing CPU RTL or instruction encodings.

## Phase 6E Simple Loop Program Simulation

Status: passed.

Files tested:

- `rtl/cpu_top.sv`
- `programs/simple_loop_test.mem`
- `tb/tb_phase6_simple_loop.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded custom-ISA program execution through `cpu_top`.
- ADDI setup for loop accumulator, counter and step registers.
- ADD and SUB loop body execution.
- BEQ loop exit when the counter reaches zero.
- JUMP loop-back using a negative PC-relative offset.
- STORE final loop result to data memory word 0.
- Register `x0` remains zero.
- Fixed maximum cycle count to prevent a bad loop from hanging simulation.
- NOP at the end of the program.

Program tested:

- `ADDI x1, x0, 0`
- `ADDI x2, x0, 3`
- `ADDI x3, x0, 1`
- `ADD x1, x1, x3`
- `SUB x2, x2, x3`
- `BEQ x2, x0, +2`
- `JUMP -3`
- `STORE x1, [x0 + 0]`
- `NOP`

Offset notes:

- The BEQ at word 5 uses `+2`, so when `x2 == 0` the PC targets word 7 and skips the loop-back JUMP.
- The JUMP at word 6 uses `13'h1ffd`, which sign-extends to `-3`, so the PC returns to word 3.

Result:

- Full XSim regression completed successfully.
- `tb_phase6_simple_loop` reported 5 tests run and 0 tests failed.
- Final register and memory values matched expectations:
  - `x0 = 32'd0`
  - `x1 = 32'd3`
  - `x2 = 32'd0`
  - `x3 = 32'd1`
  - `data_mem_inst.mem[0] = 32'd3`
- Console output included `PHASE 6E SIMPLE LOOP TEST PASSED`.

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase6e_simple_loop_xsim_regression_20260708_115055.txt`

Waveform notes:

- The generated waveform file is `tb_phase6_simple_loop.vcd`.

Conclusion:

The Phase 6E custom-ISA program test passed. It verifies simple loop execution using ADDI, ADD, SUB, BEQ, JUMP, STORE and NOP through a file-loaded CPU program without changing CPU RTL or instruction encodings.

## Phase 6F Invalid Opcode Safety Program Simulation

Status: passed.

Files tested:

- `rtl/cpu_top.sv`
- `programs/invalid_opcode_test.mem`
- `tb/tb_phase6_invalid_opcode.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- File-loaded custom-ISA program execution through `cpu_top`.
- Valid ADDI instructions before and after invalid opcodes.
- Invalid opcode `4'hb` does not write target register `x10`.
- Invalid opcode `4'hf` does not write target register `x11`.
- A second invalid opcode `4'hb` does not write target register `x12`.
- Valid STORE still writes data memory word 0.
- Invalid opcodes do not corrupt checked data memory words 1 or 5.
- Register `x0` remains zero.
- NOP at the end of the program.

Program tested:

- `ADDI x1, x0, 10`
- `INVALID opcode 4'hb, target x10`
- `ADDI x2, x0, 20`
- `INVALID opcode 4'hf, target x11`
- `STORE x2, [x0 + 0]`
- `INVALID opcode 4'hb, target x12`
- `NOP`

Encoded program words:

```text
6080000A
B5002000
61000014
F5844000
80004000
B6004004
00000000
```

Result:

- Full XSim regression completed successfully.
- `tb_phase6_invalid_opcode` reported 9 tests run and 0 tests failed.
- Final register and memory values matched expectations:
  - `x0 = 32'd0`
  - `x1 = 32'd10`
  - `x2 = 32'd20`
  - `x10 = 32'd0`
  - `x11 = 32'd0`
  - `x12 = 32'd0`
  - `data_mem_inst.mem[0] = 32'd20`
  - `data_mem_inst.mem[1] = 32'd0`
  - `data_mem_inst.mem[5] = 32'd0`
- Console output included `PHASE 6F INVALID OPCODE TEST PASSED`.

Commands run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase6f_invalid_opcode_xsim_regression_20260708_122920.txt`

Waveform notes:

- The generated waveform file is `tb_phase6_invalid_opcode.vcd`.

Conclusion:

The Phase 6F custom-ISA program test passed. It verifies that invalid opcodes are safely ignored at program level without changing CPU RTL or instruction encodings.

## Phase 8B Multi-Cycle CPU FSM Skeleton Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/cpu_core_multicycle.sv`
- `tb/tb_cpu_core_multicycle_fsm.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Reset returns the multi-cycle skeleton to `FETCH`.
- Reset returns PC to `32'h0000_0000`.
- Reset clears the instruction register to NOP.
- Reset deasserts `reg_write` and `mem_write`.
- `FETCH` captures a NOP instruction into `instruction_reg`.
- `FETCH` captures the current instruction PC.
- Sequential PC advance by 4.
- `DECODE` extracts opcode, `rd`, `rs1`, `rs2`, `imm13` and sign-extended immediate fields.
- NOP is recognised as valid and returns safely to `FETCH`.
- Invalid opcode `4'hb` is marked invalid.
- Invalid opcode does not assert register or memory write enables.

Result:

- Standalone XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 8B test.
- Testbench summary reported 34 tests run and 0 tests failed.
- Console output included `PHASE 8B MULTI-CYCLE FSM TEST PASSED`.
- The existing `rtl/cpu_core.sv` implementation was not replaced or modified.

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_fsm.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_fsm -s tb_cpu_core_multicycle_fsm_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_fsm_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after the snapshot was built.
- `xsim` still ran successfully and the self-checking testbench reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_fsm.vcd`.

Conclusion:

The Phase 8B multi-cycle CPU skeleton passed its focused FSM safety test. It verifies reset, NOP decode, invalid-opcode safety and sequential PC stepping without changing the existing working CPU core or instruction encodings.

## Phase 8C Multi-Cycle CPU Arithmetic Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/cpu_core_multicycle.sv`
- `tb/tb_cpu_core_multicycle_arithmetic.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Arithmetic multi-cycle sequence `FETCH -> DECODE -> EXECUTE -> WRITEBACK -> FETCH`.
- Register operand capture during `DECODE`.
- ALU result capture during `EXECUTE`.
- Register writeback during `WRITEBACK`.
- `ADDI`, `ADD`, `SUB`, `AND`, `OR` and `XOR`.
- Negative immediate sign extension using `ADDI x8, x0, -1`.
- `x0` write protection using `ADDI x0, x0, 123`.
- `reg_write` pulses only during arithmetic `WRITEBACK` cycles that write a non-zero destination register.
- `mem_write` remains low throughout the arithmetic program.

Result:

- Standalone Phase 8C XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 8C test.
- Testbench summary reported 13 tests run and 0 tests failed.
- Console output included `PHASE 8C MULTI-CYCLE ARITHMETIC TEST PASSED`.
- The existing `rtl/cpu_core.sv` implementation was not replaced or modified.

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_arithmetic.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_arithmetic -s tb_cpu_core_multicycle_arithmetic_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_arithmetic_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after some snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_arithmetic.vcd`.

Conclusion:

The Phase 8C multi-cycle CPU arithmetic test passed. It verifies arithmetic execution, signed immediate handling, writeback timing, `x0` protection and memory-write safety in the separate multi-cycle CPU without changing the existing working CPU core or instruction encodings.

## Phase 8D Multi-Cycle CPU Memory Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/cpu_core_multicycle.sv`
- `tb/tb_cpu_core_multicycle_memory.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- LOAD sequence `FETCH -> DECODE -> EXECUTE -> MEMORY -> WRITEBACK -> FETCH`.
- STORE sequence `FETCH -> DECODE -> EXECUTE -> MEMORY -> FETCH`.
- Base-plus-offset address calculation using `rs1 + sign-extended imm13`.
- STORE writes `rs2` data to the internal multi-cycle data memory.
- LOAD reads from the internal multi-cycle data memory and writes to `rd`.
- LOAD with a negative offset using `LOAD x6, [x5 - 4]`.
- LOAD to `x0` leaves `x0` unchanged.
- STORE does not assert `reg_write`.
- STORE asserts `mem_write` only during the `MEMORY` state.
- LOAD register writeback occurs only during `WRITEBACK`.
- Phase 8C arithmetic behaviour remains covered by the full regression.

Result:

- Standalone Phase 8D XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 8D test.
- Testbench summary reported 14 tests run and 0 tests failed.
- Console output included `PHASE 8D MULTI-CYCLE MEMORY TEST PASSED`.
- The existing `rtl/cpu_core.sv` implementation was not replaced or modified.

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_memory.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_memory -s tb_cpu_core_multicycle_memory_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_memory_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after some snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_memory.vcd`.

Conclusion:

The Phase 8D multi-cycle CPU memory test passed. It verifies LOAD/STORE address calculation, memory access state timing, LOAD writeback, STORE write safety and `x0` protection in the separate multi-cycle CPU without changing the existing working CPU core or instruction encodings.

## Phase 8E Multi-Cycle CPU Branch/Jump Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/cpu_core_multicycle.sv`
- `tb/tb_cpu_core_multicycle_branch_jump.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- BEQ sequence `FETCH -> DECODE -> EXECUTE -> FETCH`.
- JUMP sequence `FETCH -> DECODE -> EXECUTE -> FETCH`.
- BEQ taken control flow using equal source registers.
- BEQ not-taken control flow using unequal source registers.
- Forward JUMP skipping an unwanted instruction.
- Backward JUMP loop using a negative immediate offset.
- Branch target calculation using `instruction_pc + (imm_ext_reg << 2)`.
- BEQ and JUMP do not assert `reg_write`.
- BEQ and JUMP do not assert `mem_write`.
- Loop execution with ADD, SUB, BEQ, JUMP and STORE.
- Final STORE after the loop writes data memory word 0.

Result:

- Standalone Phase 8E XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 8E test.
- Testbench summary reported 23 tests run and 0 tests failed.
- Console output included `PHASE 8E MULTI-CYCLE BRANCH/JUMP TEST PASSED`.
- The existing `rtl/cpu_core.sv` implementation was not replaced or modified.

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_branch_jump.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_branch_jump -s tb_cpu_core_multicycle_branch_jump_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_branch_jump_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after some snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_branch_jump.vcd`.

Conclusion:

The Phase 8E multi-cycle CPU branch/jump test passed. It verifies BEQ taken/not-taken behaviour, forward and backward JUMP behaviour, branch target calculation, loop execution and control-instruction write safety in the separate multi-cycle CPU without changing the existing working CPU core or instruction encodings.

## Phase 8F Multi-Cycle CPU Full-Program Verification

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/cpu_core_multicycle.sv`
- `tb/tb_cpu_core_multicycle_full_programs.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Arithmetic edge program covering ADDI, ADD, SUB, negative immediate sign extension, ADD wraparound, SUB underflow and `x0` protection.
- Memory offset program covering STORE, LOAD, base + 0 addressing, base + 4 addressing, negative offset load and final data memory contents.
- Branch control program covering BEQ taken, BEQ not taken, skipped instruction protection and fall-through execution.
- Jump control program covering forward JUMP and skipped instruction protection.
- Simple loop program covering repeated ADD/SUB, BEQ loop exit, backward JUMP and final STORE to data memory.
- Invalid opcode safety program covering `valid_instr` low for invalid opcodes, no invalid register writes, no invalid memory writes and valid instructions before/after invalid opcodes.

Result:

- Standalone Phase 8F XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 8F test.
- Testbench summary reported 49 tests run and 0 tests failed.
- Console output included `PHASE 8F MULTI-CYCLE FULL-PROGRAM TEST PASSED`.
- The existing `rtl/cpu_core.sv`, `rtl/cpu_top.sv`, `rtl/fpga_top.sv` and Phase 6 program files were not modified.

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_full_programs.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_full_programs -s tb_cpu_core_multicycle_full_programs_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_full_programs_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase8f_xsim_regression_20260709_120546.txt`

Warning note:

- `xelab` reported the known object-directory cleanup warning after some snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_full_programs.vcd`.

Conclusion:

The Phase 8F full-program verification test passed. It confirms that the separate multi-cycle CPU now passes full custom-ISA program verification across arithmetic, memory, branch, jump, loop and invalid-opcode safety scenarios without replacing the original CPU core or changing instruction encodings.

## Phase 10A Multi-Cycle CPU Performance Benchmarking

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/cpu_core_multicycle.sv`
- `tb/tb_cpu_core_multicycle_performance.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Arithmetic-heavy benchmark program.
- Memory-heavy benchmark program.
- Branch/jump benchmark program.
- Simple loop benchmark program.
- Multi-cycle completion counting for arithmetic, ADDI, LOAD, STORE, BEQ, JUMP, NOP and invalid instruction classes.
- CPI, estimated MIPS at 100 MHz and estimated runtime reporting.
- Final architectural state checks for each benchmark.

Result:

- Standalone Phase 10A XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 10A test.
- Testbench summary reported 41 tests run and 0 tests failed.
- Console output included `PHASE 10A MULTI-CYCLE PERFORMANCE TEST PASSED`.
- The existing RTL was not modified.

Benchmark summary:

| Benchmark | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Arithmetic-heavy | 42 | 11 | 3.818 | 26.190 |
| Memory-heavy | 50 | 12 | 4.167 | 24.000 |
| Branch/jump | 39 | 11 | 3.545 | 28.205 |
| Simple loop | 71 | 20 | 3.550 | 28.169 |

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\cpu_core_multicycle.sv tb\tb_cpu_core_multicycle_performance.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_performance -s tb_cpu_core_multicycle_performance_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_performance_sim -runall
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after the snapshot was built.
- `xsim` still ran successfully and the self-checking testbench reported PASS.

Transcript:

- `reports/simulation_transcripts/phase10a_xsim_regression_20260709_190808.txt`

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_performance.vcd`.

Conclusion:

The Phase 10A performance benchmark test passed. It provides simulation-based CPI, MIPS and runtime estimates for the separate multi-cycle CPU while hardware bring-up remains pending.

## Phase 10B Single-Cycle-Style CPU Performance Benchmarking

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/alu.sv`
- `rtl/register_file.sv`
- `rtl/program_counter.sv`
- `rtl/instruction_memory.sv`
- `rtl/data_memory.sv`
- `rtl/fetch_unit.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/cpu_core.sv`
- `tb/tb_cpu_core_singlecycle_performance.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Arithmetic-heavy benchmark program equivalent to the Phase 10A multi-cycle benchmark.
- Memory-heavy benchmark program equivalent to the Phase 10A multi-cycle benchmark.
- Branch/jump benchmark program equivalent to the Phase 10A multi-cycle benchmark.
- Simple loop benchmark program equivalent to the Phase 10A multi-cycle benchmark.
- Instruction class counts for arithmetic, LOAD, STORE, BEQ, JUMP, NOP and invalid instructions.
- CPI and MIPS reporting using the original single-cycle-style estimated Fmax of 86.6 MHz.
- Theoretical 100 MHz MIPS reporting, marked as not timing-safe because the Phase 7 implementation did not meet 100 MHz timing.

Result:

- Standalone Phase 10B XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 10B test.
- Testbench summary reported 41 tests run and 0 tests failed.
- Console output included `PHASE 10B SINGLE-CYCLE-STYLE PERFORMANCE TEST PASSED`.
- The existing RTL was not modified.

Benchmark summary:

| Benchmark | Cycles | Completed instructions | CPI | MIPS at 86.6 MHz estimated Fmax | Theoretical MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: | ---: |
| Arithmetic-heavy | 11 | 11 | 1.000 | 86.600 | 100.000, not timing-safe |
| Memory-heavy | 12 | 12 | 1.000 | 86.600 | 100.000, not timing-safe |
| Branch/jump | 11 | 11 | 1.000 | 86.600 | 100.000, not timing-safe |
| Simple loop | 20 | 20 | 1.000 | 86.600 | 100.000, not timing-safe |

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\alu.sv rtl\register_file.sv rtl\program_counter.sv rtl\instruction_memory.sv rtl\data_memory.sv rtl\fetch_unit.sv rtl\instruction_decoder.sv rtl\control_unit.sv rtl\cpu_core.sv tb\tb_cpu_core_singlecycle_performance.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_singlecycle_performance -s tb_cpu_core_singlecycle_performance_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_singlecycle_performance_sim -runall
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after the snapshot was built.
- `xsim` still ran successfully and the self-checking testbench reported PASS.

Transcript:

- `reports/simulation_transcripts/phase10b_xsim_regression_20260709_194210.txt`

Waveform notes:

- The generated waveform file is `tb_cpu_core_singlecycle_performance.vcd`.

Conclusion:

The Phase 10B single-cycle-style performance benchmark passed. It confirms the original CPU path gives CPI 1.000 in simulation for these programs, but the 100 MHz throughput number remains theoretical because the original post-route implementation did not meet 100 MHz setup timing.

## Phase 10C BRAM-Style Memory Prototype Simulations

Status: passed.

Files tested:

- `rtl/bram_instr_mem.sv`
- `tb/tb_bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `tb/tb_bram_data_mem.sv`

Simulator:

- Vivado XSim 2026.1

Instruction memory coverage:

- `$readmemh` loading from `programs/add_test.mem`.
- One-cycle synchronous read latency.
- Byte-address to word-index mapping.
- Unaligned address mapping through word addressing.
- Out-of-range read returning NOP/zero.

Instruction memory result:

- Standalone Phase 10C BRAM instruction memory simulation completed successfully.
- Testbench summary reported 9 tests run and 0 tests failed.
- Console output included `PHASE 10C BRAM INSTRUCTION MEMORY TEST PASSED`.
- Full XSim regression completed successfully after adding the Phase 10C BRAM memory tests.

Data memory coverage:

- One-cycle synchronous read latency.
- Synchronous write.
- Write/read word 0.
- Write/read word 1.
- Disabled write does not update memory.
- `mem_read = 0` returns zero after a clock edge.
- Out-of-range read returns zero.
- Out-of-range write does not corrupt valid memory.

Data memory result:

- Standalone Phase 10C BRAM data memory simulation completed successfully.
- Testbench summary reported 13 tests run and 0 tests failed.
- Console output included `PHASE 10C BRAM DATA MEMORY TEST PASSED`.

Standalone commands run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\bram_instr_mem.sv tb\tb_bram_instr_mem.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_bram_instr_mem -s tb_bram_instr_mem_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_bram_instr_mem_sim -runall

C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\bram_data_mem.sv tb\tb_bram_data_mem.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_bram_data_mem -s tb_bram_data_mem_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_bram_data_mem_sim -runall
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after each snapshot was built.
- `xsim` still ran successfully and both self-checking testbenches reported PASS.

Transcript:

- `reports/simulation_transcripts/phase10c_xsim_regression_20260709_200053.txt`

Waveform notes:

- The generated waveform files are `tb_bram_instr_mem.vcd` and `tb_bram_data_mem.vcd`.

Conclusion:

The Phase 10C standalone BRAM-style memory prototype tests passed. They verify synchronous-read instruction and data memory behaviour without modifying the verified CPU cores, existing memory modules or instruction encodings.

## Phase 10F BRAM-Aware Multi-Cycle CPU Basic Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_multicycle_bram.sv`
- `tb/tb_cpu_core_multicycle_bram_basic.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Reset state.
- `FETCH_ADDR` and `FETCH_CAPTURE` behaviour.
- Instruction register capture after synchronous instruction-memory read.
- Sequential PC advance.
- ADDI.
- ADD.
- SUB.
- AND.
- OR.
- XOR.
- STORE through BRAM data memory.
- LOAD with synchronous BRAM data capture.
- Register `x0` write protection.
- Invalid opcode safety.
- STORE write-enable pulse state.

Result:

- Standalone Phase 10F XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 10F test.
- Testbench summary reported 27 tests run and 0 tests failed.
- Console output included `PHASE 10F BRAM-AWARE CPU BASIC TEST PASSED`.
- The existing `rtl/cpu_core_multicycle.sv` baseline was not modified.

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram.sv tb\tb_cpu_core_multicycle_bram_basic.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_basic -s tb_cpu_core_multicycle_bram_basic_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_basic_sim -runall
```

Warning note:

- `xelab` reported the known object-directory cleanup warning after the snapshot was built.
- `xsim` still ran successfully and the self-checking testbench reported PASS.

Transcript:

- `reports/simulation_transcripts/phase10f_xsim_regression_20260710_102950.txt`

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_bram_basic.vcd`.

Conclusion:

The Phase 10F focused BRAM-aware CPU test passed. Branch and jump support is implemented in the new module; Phase 10G extends this path with full BRAM-aware custom-ISA program regression.

## Phase 10G BRAM-Aware Multi-Cycle CPU Full-Program Verification

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_multicycle_bram.sv`
- `tb/tb_cpu_core_multicycle_bram_full_programs.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Arithmetic edge program covering ADDI, ADD, SUB, negative immediate sign extension, ADD wraparound, SUB underflow and `x0` protection.
- Memory offset program covering STORE, LOAD, base + 0 addressing, base + 4 addressing, negative offset load and final BRAM data memory contents.
- Branch control program covering BEQ taken, BEQ not taken, skipped instruction protection and fall-through execution.
- Jump control program covering forward JUMP and skipped instruction protection.
- Simple loop program covering repeated ADD/SUB, BEQ loop exit, backward JUMP and final STORE to BRAM data memory.
- Invalid opcode safety program covering `valid_instr` low for invalid opcodes, no invalid register writes, no invalid memory writes and valid instructions before/after invalid opcodes.
- Control-signal safety checks that `reg_write` only occurs during WRITEBACK, `mem_write` only occurs during STORE MEMORY_ADDR, and BEQ/JUMP never assert register or memory writes.

Result:

- Standalone Phase 10G XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 10G test.
- Testbench summary reported 135 tests run and 0 tests failed.
- Console output included `PHASE 10G BRAM-AWARE FULL-PROGRAM TEST PASSED`.
- The existing `rtl/cpu_core_multicycle.sv` baseline was not modified.

Performance summary:

| Program | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| BRAM arithmetic edge | 48 | 10 | 4.800 | 20.833 |
| BRAM memory offset | 49 | 9 | 5.444 | 18.367 |
| BRAM branch control | 46 | 10 | 4.600 | 21.739 |
| BRAM jump control | 31 | 7 | 4.429 | 22.581 |
| BRAM simple loop | 73 | 16 | 4.562 | 21.918 |
| BRAM invalid opcode safety | 24 | 6 | 4.000 | 25.000 |
| Aggregate | 271 | 58 | 4.672 | 21.402 |

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram.sv tb\tb_cpu_core_multicycle_bram_full_programs.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_full_programs -s tb_cpu_core_multicycle_bram_full_programs_phase10g_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_full_programs_phase10g_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase10g_xsim_regression_20260710_105251.txt`

Warning note:

- `xelab` reported the known object-directory cleanup warning after snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_bram_full_programs.vcd`.

Conclusion:

The Phase 10G full-program verification test passed. It confirms that the separate BRAM-aware multi-cycle CPU now supports the full custom ISA in simulation, including BEQ/JUMP control flow and invalid opcode safety, without modifying the existing verified `cpu_core_multicycle.sv` baseline or changing instruction encodings.

## Phase 11A BRAM-Aware Prefetch CPU Basic Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_multicycle_bram_prefetch.sv`
- `tb/tb_cpu_core_multicycle_bram_prefetch_basic.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Reset state and `prefetch_valid` reset behaviour.
- Sequential arithmetic execution through the prefetch path.
- LOAD/STORE execution with synchronous BRAM data-memory timing.
- Taken BEQ and JUMP wrong-path prefetch invalidation.
- BEQ not-taken fall-through behaviour.
- Register `x0` write protection.
- Invalid opcode safety.
- Control-signal safety checks that `reg_write` only occurs during WRITEBACK and `mem_write` only occurs during STORE `MEMORY_ADDR`.

Result:

- Standalone Phase 11A XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 11A test.
- Testbench summary reported 52 tests run and 0 tests failed.
- Console output included `PHASE 11A BRAM PREFETCH BASIC TEST PASSED`.
- The existing `rtl/cpu_core_multicycle_bram.sv`, `rtl/cpu_core_multicycle.sv` and `rtl/cpu_core.sv` baselines were not modified.

Sequential arithmetic benchmark:

| Design | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Phase 10G BRAM-aware baseline arithmetic edge | 48 | 10 | 4.800 | 20.833 |
| Phase 11A BRAM-aware prefetch prototype | 30 | 10 | 3.000 | 33.333 |

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram_prefetch.sv tb\tb_cpu_core_multicycle_bram_prefetch_basic.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_prefetch_basic -s tb_cpu_core_multicycle_bram_prefetch_basic_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_prefetch_basic_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase11a_xsim_regression_20260710_113107.txt`

Warning note:

- `xelab` reported the known object-directory cleanup warning after the snapshot was built.
- `xsim` still ran successfully and the self-checking testbench reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_bram_prefetch_basic.vcd`.

Conclusion:

The Phase 11A basic prefetch CPU test passed. The separate prefetch variant improves the small sequential arithmetic benchmark from 48 cycles to 30 cycles compared with the Phase 10G BRAM-aware baseline, while preserving existing CPU baselines and instruction encodings. Full custom-ISA prefetch verification remains future work.

## Phase 11B BRAM-Aware Prefetch CPU Full-Program Verification

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_multicycle_bram_prefetch.sv`
- `tb/tb_cpu_core_multicycle_bram_prefetch_full_programs.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Arithmetic edge program covering ADDI, ADD, SUB, negative immediate sign extension, ADD wraparound, SUB underflow and `x0` protection.
- Memory offset program covering STORE, LOAD, base + 0 addressing, base + 4 addressing, negative offset load and final BRAM data memory contents.
- Branch control program covering BEQ taken, BEQ not taken, wrong-path prefetch discard, skipped instruction protection and fall-through execution.
- Jump control program covering forward JUMP, wrong-path prefetch discard and skipped instruction protection.
- Simple loop program covering repeated ADD/SUB, BEQ loop exit, backward JUMP and final STORE to BRAM data memory.
- Invalid opcode safety program covering `valid_instr` low for invalid opcodes, no invalid register writes, no invalid memory writes and valid instructions before/after invalid opcodes.
- Control-signal safety checks that `reg_write` only occurs during WRITEBACK, `mem_write` only occurs during STORE `MEMORY_ADDR`, and BEQ/JUMP never assert register or memory writes.

Result:

- Standalone Phase 11B XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 11B test.
- Testbench summary reported 135 tests run and 0 tests failed.
- Console output included `PHASE 11B BRAM PREFETCH FULL-PROGRAM TEST PASSED`.
- The existing `rtl/cpu_core_multicycle_bram.sv`, `rtl/cpu_core_multicycle.sv` and `rtl/cpu_core.sv` baselines were not modified.

Performance summary:

| Program | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Prefetch arithmetic edge | 30 | 10 | 3.000 | 33.333 |
| Prefetch memory offset | 33 | 9 | 3.667 | 27.273 |
| Prefetch branch control | 30 | 10 | 3.000 | 33.333 |
| Prefetch jump control | 23 | 7 | 3.286 | 30.435 |
| Prefetch simple loop | 49 | 16 | 3.062 | 32.653 |
| Prefetch invalid opcode safety | 14 | 6 | 2.333 | 42.857 |
| Aggregate | 179 | 58 | 3.086 | 32.402 |

Comparison with Phase 10G BRAM-aware baseline:

| Metric | Phase 10G BRAM-aware baseline | Phase 11B prefetch CPU |
| --- | ---: | ---: |
| Cycles | 271 | 179 |
| Completed instructions | 58 | 58 |
| CPI | 4.672 | 3.086 |
| Estimated MIPS at 100 MHz | 21.402 | 32.402 |

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram_prefetch.sv tb\tb_cpu_core_multicycle_bram_prefetch_full_programs.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_prefetch_full_programs -s tb_cpu_core_multicycle_bram_prefetch_full_programs_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_prefetch_full_programs_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase11b_xsim_regression_20260710_120845.txt`

Warning note:

- `xelab` reported the known object-directory cleanup warning after snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_bram_prefetch_full_programs.vcd`.

Conclusion:

The Phase 11B full-program verification test passed. The separate BRAM-aware prefetch CPU now passes full custom-ISA simulation coverage and improves aggregate CPI from 4.672 to 3.086 compared with the Phase 10G BRAM-aware baseline. Synthesis and implementation evidence for the prefetch path remains future work.

## Phase 11D BRAM-Aware Control-Flow-Optimised Prefetch CPU Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_multicycle_bram_prefetch_ctrlopt.sv`
- `tb/tb_cpu_core_multicycle_bram_prefetch_ctrlopt.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Sequential arithmetic benchmark to check normal prefetch behaviour did not regress.
- Memory offset benchmark to check LOAD/STORE BRAM timing stayed correct.
- BEQ taken and BEQ not taken control flow.
- Forward JUMP control flow.
- Backward JUMP simple loop execution with final STORE result.
- Invalid opcode safety mixed with normal execution.
- Register `x0` protection.
- Final BRAM data memory checks.
- Control-signal safety checks that `reg_write` only occurs during WRITEBACK, `mem_write` only occurs during STORE `MEMORY_ADDR`, and BEQ/JUMP never assert register or memory writes.

Result:

- Standalone Phase 11D XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 11D test.
- Testbench summary reported 135 tests run and 0 tests failed.
- Console output included `PHASE 11D BRAM PREFETCH CTRLOPT TEST PASSED`.
- The existing `rtl/cpu_core_multicycle_bram_prefetch.sv`, `rtl/cpu_core_multicycle_bram.sv`, `rtl/cpu_core_multicycle.sv` and `rtl/cpu_core.sv` baselines were not modified.

Performance summary:

| Program | Cycles | Completed instructions | CPI | Estimated MIPS at 100 MHz |
| --- | ---: | ---: | ---: | ---: |
| Ctrlopt arithmetic edge | 30 | 10 | 3.000 | 33.333 |
| Ctrlopt memory offset | 33 | 9 | 3.667 | 27.273 |
| Ctrlopt branch control | 29 | 10 | 2.900 | 34.483 |
| Ctrlopt jump control | 21 | 7 | 3.000 | 33.333 |
| Ctrlopt simple loop | 46 | 16 | 2.875 | 34.783 |
| Ctrlopt invalid opcode safety | 14 | 6 | 2.333 | 42.857 |
| Aggregate | 173 | 58 | 2.983 | 33.526 |

Comparison with Phase 11B prefetch baseline:

| Metric | Phase 11B prefetch CPU | Phase 11D ctrlopt prefetch CPU |
| --- | ---: | ---: |
| Cycles | 179 | 173 |
| Completed instructions | 58 | 58 |
| CPI | 3.086 | 2.983 |
| Estimated MIPS at 100 MHz | 32.402 | 33.526 |

Standalone command run from the repository root:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_multicycle_bram_prefetch_ctrlopt.sv tb\tb_cpu_core_multicycle_bram_prefetch_ctrlopt.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_multicycle_bram_prefetch_ctrlopt -s tb_cpu_core_multicycle_bram_prefetch_ctrlopt_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_multicycle_bram_prefetch_ctrlopt_sim -runall
```

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase11d_xsim_regression_20260711_113910.txt`

Warning note:

- `xelab` reported the known object-directory cleanup warning after snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_multicycle_bram_prefetch_ctrlopt.vcd`.

Conclusion:

The Phase 11D control-flow-optimised prefetch CPU test passed. The separate ctrlopt variant reduced aggregate cycle count from 179 to 173 and improved aggregate CPI from 3.086 to 2.983 compared with the Phase 11B prefetch baseline. The improvement is concentrated in taken BEQ, JUMP and loop benchmarks. This is simulation evidence only; synthesis, implementation and hardware validation remain future work.

## Phase 12B Pipelined CPU Skeleton Simulation

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/cpu_core_pipeline.sv`
- `tb/tb_cpu_core_pipeline_skeleton.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Reset clears fetch request, IF/ID and retirement valid state.
- Initial stale BRAM output after reset is not accepted.
- Sequential fetch requests advance through byte PCs `0, 4, 8, 12, 16`.
- Synchronous BRAM responses are paired with the saved fetch request PC.
- IF/ID stores valid, PC and instruction state.
- Software NOPs retire exactly once.
- Invalid opcode `4'hf` becomes a safe bubble and does not retire.
- Later NOP instructions continue after the invalid opcode.
- Enable low pauses fetch, request metadata, IF/ID state and retirement.
- Resume continues without duplicated or skipped fetch/retirement events.

Result:

- Focused Phase 12B XSim simulation completed successfully.
- Full XSim regression completed successfully after adding the Phase 12B test.
- Testbench summary reported 278 tests run and 0 tests failed.
- Console output included `PHASE 12B PIPELINE SKELETON TEST PASSED`.
- The existing Phase 10 and Phase 11 CPU baselines were not modified.

Regression command run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

Transcript:

- `reports/simulation_transcripts/phase12b_xsim_regression_20260711_132223.txt`

Warning note:

- `xelab` reported the known object-directory cleanup warning after snapshots were built.
- `xsim` still ran successfully and the self-checking testbenches reported PASS.

Waveform notes:

- The generated waveform file is `tb_cpu_core_pipeline_skeleton.vcd`.

Conclusion:

The Phase 12B pipelined CPU skeleton test passed. The new separate pipeline path now proves synchronous instruction-BRAM request/response pairing, IF/ID valid-bit handling, safe NOP retirement, invalid-opcode bubble conversion and enable/pause behaviour.

## Phase 12 Full Pipelined CPU Custom-ISA Verification

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_full.sv`
- `tb/tb_cpu_core_pipeline_full.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Full custom-ISA program execution on the separate pipelined CPU path.
- ADD, SUB, AND, OR, XOR and ADDI execution.
- Register writeback and `x0` protection.
- EX/MEM and MEM/WB forwarding for ALU dependencies.
- LOAD and STORE using synchronous BRAM-style data memory.
- One-cycle load-use hazard detection and pipeline stall handling.
- STORE-data forwarding.
- BEQ taken and not-taken behaviour.
- Forward JUMP and backward JUMP loop behaviour.
- Wrong-path flush and invalidation after taken control flow.
- Invalid opcode safety.
- Architectural retirement interface and no duplicate retirement for non-loop tests.

Result:

- Full XSim regression completed successfully after adding the Phase 12 full pipeline test.
- Phase 12 full pipeline testbench summary reported 2,793 tests run and 0 tests failed.
- Console output included `PIPELINE FULL CUSTOM ISA TEST PASSED`.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 457 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.433 |
| Aggregate MIPS at 100 MHz | 69.803 |

Vivado implementation summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline`.
- Post-route WNS: +0.185 ns.
- Post-route TNS: 0.000 ns.
- Estimated Fmax: approximately 101.9 MHz.
- Practical estimated MIPS: approximately 71.1.
- 100 MHz timing passed.
- Bitstream generation passed.

Transcript:

- `reports/simulation_transcripts/phase12_pipeline_regression_20260711_143721.txt`

Report:

- `reports/phase12_pipeline_performance_comparison.md`

Conclusion:

The separate Phase 12 pipelined CPU passes full custom-ISA simulation and meets the Basys 3 100 MHz post-route timing target. Practical estimated throughput improves over Phase 11E, from about 37.8 MIPS to about 71.1 MIPS, but the 90 MIPS primary target is not yet achieved.

## Phase 13A Jumpfast Pipeline Verification

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_jumpfast.sv`
- `tb/tb_cpu_core_pipeline_jumpfast.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Single forward JUMP target request.
- Consecutive JUMPs.
- Backward JUMP loop.
- Pause immediately after a fast JUMP target request.
- Older taken BEQ overriding a younger wrong-path JUMP.
- JUMP near a load-use/fetch-buffer condition.
- Wrong-path STORE protection.
- Full custom-ISA benchmark suite matching the Phase 12 pipeline benchmark mix.

Result:

- Focused Phase 13A test passed with 3,232 tests run and 0 tests failed.
- Full local XSim regression completed successfully after adding the Phase 13A test.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 427 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Aggregate MIPS at 100 MHz | 74.707 |

Vivado implementation summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline_jumpfast`.
- Post-route WNS: +0.182 ns.
- Post-route TNS: 0.000 ns.
- Estimated Fmax: approximately 101.9 MHz.
- Practical estimated MIPS: approximately 76.1.
- 100 MHz timing passed.
- Bitstream generation passed.

Transcripts:

- `reports/simulation_transcripts/phase13a_jumpfast_focused_final_20260711_193050.txt`
- `reports/simulation_transcripts/phase13a_xsim_regression_final_20260711_193104.txt`

Report:

- `reports/phase13a_jump_target_request.md`

Conclusion:

The separate Phase 13A jumpfast pipeline keeps the Phase 12 baseline intact, preserves full custom-ISA correctness, meets the 100 MHz Basys 3 timing target, and improves practical estimated throughput from about 71.1 MIPS to about 76.1 MIPS. The 90 MIPS target remains future optimisation work.

## Phase 13B BEQ Target-Prefetch Pipeline Verification

Status: passed, but experimental.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem_dualread.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_branchprefetch.sv`
- `tb/tb_cpu_core_pipeline_branchprefetch.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Taken forward `BEQ` using the prefetched target response.
- Not-taken `BEQ` discarding the speculative target response.
- Load-to-`BEQ` dependency with the existing load-use stall preserved.
- Invalid opcode at a branch target.
- Pause while a branch target response is pending.
- Retained Phase 13A fast `JUMP` behaviour.
- Wrong-path register write and STORE protection.
- Full custom-ISA aggregate benchmark suite matching the Phase 13A comparison workload.

Result:

- Full local XSim regression completed successfully after adding the Phase 13B test.
- Phase 13B testbench summary reported 4,004 tests run and 0 tests failed.
- Console output included `PHASE 13B BRANCH-PREFETCH PIPELINE TEST PASSED`.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 424 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.329 |
| Aggregate MIPS at 100 MHz | 75.236 |
| Branch-heavy benchmark cycles | 75 |
| Branch-heavy retired instructions | 45 |
| Branch-heavy CPI | 1.667 |
| Branch-heavy target prefetch hits | 16 |
| Branch-heavy target prefetch discards | 7 |

Post-route implementation summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline_branchprefetch`.
- Post-route WNS: +0.008 ns.
- Post-route TNS: 0.000 ns.
- Estimated Fmax: approximately 100.1 MHz.
- Practical estimated MIPS: approximately 75.3.
- BRAM use: 1.5 Block RAM Tiles / 3 RAMB18.
- Bitstream generation passed.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_branchprefetch.tcl
```

Transcript:

- `reports/simulation_transcripts/phase13b_xsim_regression_final_20260711_203157.txt`

Report:

- `reports/phase13b_beq_target_prefetch.md`

Conclusion:

The separate Phase 13B branch-prefetch pipeline is functionally correct and meets the 100 MHz Basys 3 timing target, but it does not replace Phase 13A as the preferred implementation. It improves aggregate CPI slightly, from 1.339 to 1.329, but increases BRAM use from 2 to 3 RAMB18 and reduces practical estimated throughput from about 76.1 MIPS to about 75.3 MIPS.

## Phase 13C Timing-Optimised Pipeline Verification

Status: passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_timingopt.sv`
- `tb/tb_cpu_core_pipeline_timingopt.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Full custom-ISA aggregate benchmark suite matching the Phase 13A comparison workload.
- Phase 13A fast `JUMP` behaviour retained.
- BEQ taken/not-taken behaviour retained.
- Forwarding, store-data forwarding and load-use stalls retained.
- Wrong-path register write and STORE protection retained.
- Invalid opcode safety and `x0` protection retained.

Result:

- Full local XSim regression completed successfully after adding the Phase 13C test.
- Phase 13C testbench summary reported 3,232 tests run and 0 tests failed.
- Console output included `PHASE 13C TIMINGOPT PIPELINE TEST PASSED`.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 427 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Aggregate MIPS at 100 MHz | 74.707 |

Post-route implementation and timing-sweep summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline_timingopt`.
- Standard 10.000 ns implementation WNS: +0.759 ns.
- Standard 10.000 ns implementation TNS: 0.000 ns.
- Tightest tested passing routed period: 9.100 ns with Vivado performance directives.
- Verified post-route Fmax from implementation: 109.890 MHz.
- WNS at 9.100 ns: +0.166 ns.
- TNS at 9.100 ns: 0.000 ns.
- WHS at 9.100 ns: +0.034 ns.
- BRAM use: 1 Block RAM Tile / 2 RAMB18.
- Bitstream generation passed.
- Practical estimated MIPS: approximately 82.1.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_timingopt.tcl
$env:PHASE13C_PERIODS='9.240'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_fmax_sweep_pipeline_timingopt.tcl
$env:PHASE13C_PERIOD='9.100'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_timingopt_perf.tcl
```

Transcript:

- `reports/simulation_transcripts/phase13c_final_xsim_regression_20260712_140137.txt`

Report:

- `reports/phase13c_timing_closure.md`

Conclusion:

The separate Phase 13C timing-optimised pipeline preserves the Phase 13A CPI and aggregate retired instruction count while increasing verified post-route Fmax. Practical estimated throughput improves from about 76.1 MIPS to about 82.1 MIPS. The 90 MIPS target is not yet achieved, so the remaining timing work should focus on the data-memory-to-ID/EX operand critical-path family.

## Phase 13D Load-Forwarding Timing Experiment

Status: passed, but not preferred.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_loadtiming.sv`
- `tb/tb_cpu_core_pipeline_loadtiming.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- ALU and load dependency behaviour through the full custom-ISA aggregate benchmark.
- LOAD-to-ALU and LOAD-to-BEQ behaviour with existing load-use stalls preserved.
- STORE data forwarding and wrong-path STORE protection.
- BEQ taken/not-taken and fast JUMP behaviour retained.
- Pause/resume, invalid opcode safety and `x0` protection retained.

Result:

- Full local XSim regression completed successfully after adding the Phase 13D test.
- Phase 13D testbench summary reported 3,262 tests run and 0 tests failed.
- Console output included `Phase 13D loadtiming PIPELINE TEST PASSED`.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 434 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.361 |
| Aggregate MIPS at 100 MHz | 73.502 |

Post-route implementation summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline_loadtiming`.
- Period tested: 9.100 ns.
- Verified post-route Fmax from implementation: 109.890 MHz.
- WNS at 9.100 ns: +0.044 ns.
- TNS at 9.100 ns: 0.000 ns.
- WHS at 9.100 ns: +0.112 ns.
- BRAM use: 1 Block RAM Tile / 2 RAMB18.
- Bitstream generation passed.
- Practical estimated MIPS: approximately 80.7.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
$env:PHASE13D_PERIOD='9.100'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_loadtiming.tcl
```

Transcript:

- `reports/simulation_transcripts/phase13d_xsim_regression_20260712_145218.txt`

Report:

- `reports/phase13d_load_forwarding_timing.md`

Conclusion:

The separate Phase 13D load-forwarding timing experiment is functionally correct and timing-clean at 9.100 ns, but it adds seven aggregate cycles by replacing the decode-time WB-to-ID bypass with a one-cycle decode stall. Practical estimated throughput drops from the Phase 13C result of about 82.1 MIPS to about 80.7 MIPS. Phase 13D should remain documented as an unsuccessful experiment and did not replace Phase 13C.

## Phase 13E Forwarding-Path Timing Experiment

Status: passed and preferred over Phase 13C.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Phase 13C forwarding behaviour retained, including WB-to-ID bypass.
- Split ALU/load writeback forwarding sources and precomputed bypass selects.
- ALU dependencies, load-use dependencies, LOAD-to-ALU, LOAD-to-BEQ and STORE data forwarding.
- BEQ taken/not-taken, fast JUMP, pause/resume, invalid opcode safety and wrong-path STORE protection.
- Full aggregate benchmark matching the Phase 13C instruction mix and measurement boundaries.

Result:

- Focused Phase 13E test passed with 3,232 tests run and 0 tests failed.
- Full local XSim regression completed successfully after adding the Phase 13E test.
- Console output included `Phase 13E forwardtiming PIPELINE TEST PASSED`.
- Known `xelab` object-directory cleanup warnings appeared after successful snapshot builds; `xsim` still ran and all self-checking tests passed.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 427 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Aggregate MIPS at 100 MHz | 74.707 |

Post-route implementation summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline_forwardtiming`.
- Best verified period tested: 8.900 ns.
- Verified post-route Fmax from implementation: 112.360 MHz.
- WNS at 8.900 ns: +0.059 ns.
- TNS at 8.900 ns: 0.000 ns.
- WHS at 8.900 ns: +0.040 ns.
- BRAM use: 1 Block RAM Tile / 2 RAMB18.
- LUTs: 1,359.
- FFs: 1,510.
- Bitstream generation passed.
- Practical estimated MIPS: approximately 83.9.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
$env:PHASE13E_PERIOD='9.100'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming.tcl
$env:PHASE13E_PERIOD='8.900'; C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming.tcl
```

Transcripts:

- `reports/simulation_transcripts/phase13e_forwardtiming_focused_20260712_193438.txt`
- `reports/simulation_transcripts/phase13e_xsim_regression_20260712_193518.txt`

Report:

- `reports/phase13e_forwarding_timing.md`

Conclusion:

The separate Phase 13E forwarding-path timing experiment preserves Phase 13C CPI while improving verified post-route Fmax from 109.890 MHz to 112.360 MHz. Practical estimated throughput improves from about 82.1 MIPS to about 83.9 MIPS, so Phase 13E becomes the preferred measured implementation path. The 90 MIPS target is still not reached.

## Phase 13G Registered Target-Buffer Experiment

Status: focused simulation passed; implementation passed; not preferred over Phase 13E.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline_targetbuf_reg.sv`
- `tb/tb_cpu_core_pipeline_targetbuf_reg.sv`

Simulator:

- Vivado XSim 2026.1

Tests covered:

- Registered one-entry JUMP target-buffer lookup.
- First JUMP target miss and repeated JUMP target hit behaviour.
- Backward JUMP loop with target-buffer hits.
- BEQ behaviour retained from Phase 13E.
- Older BEQ flushing younger JUMP behaviour.
- Pause/resume, invalid opcode safety, wrong-path STORE protection and no duplicate retirement through the inherited Phase 13 pipeline checks.
- Full aggregate benchmark matching the Phase 13E instruction mix and measurement boundaries.

Result:

- Focused Phase 13G test passed with 3,264 tests run and 0 tests failed.
- Console output included `Phase 13G targetbuf_reg PIPELINE TEST PASSED`.
- Full local regression was rerun during Phase 13H after Phase 13G was added. The Phase 13G snapshot name in the regression script was shortened to avoid a Vivado/XSim snapshot cleanup/kernel issue, and the final full regression completed successfully.

Performance summary from simulation:

| Metric | Value |
| --- | ---: |
| Aggregate cycles | 427 |
| Aggregate retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Aggregate MIPS at 100 MHz | 74.707 |
| Target-buffer hits | 18 |
| Target-buffer misses | 1 |

Post-route implementation summary:

- Basys 3 part: `xc7a35tcpg236-1`.
- Top module: `fpga_top_pipeline_targetbuf_reg`.
- Verified period tested: 8.900 ns.
- Verified post-route Fmax from implementation: 112.360 MHz.
- WNS at 8.900 ns: +0.058 ns.
- TNS at 8.900 ns: 0.000 ns.
- WHS at 8.900 ns: +0.041 ns.
- BRAM use: 1 Block RAM Tile / 2 RAMB18.
- LUTs: 1,447.
- FFs: 1,615.
- Bitstream generation passed.
- Practical estimated MIPS: approximately 83.9.

Transcript:

- `reports/simulation_transcripts/phase13g_targetbuf_reg_focused_20260713_112502.txt`

Report:

- `reports/phase13g_registered_target_buffer.md`

Conclusion:

The separate Phase 13G registered target-buffer experiment fixes the Phase 13F timing problem by registering the target-buffer hit before use. However, the extra register stage also removes the Phase 13F CPI benefit. Phase 13G matches Phase 13E CPI and Fmax while using more LUTs and FFs, so Phase 13E remains the preferred measured implementation path.

## Phase 13H Preferred Pipeline Consolidation

Status: passed; Phase 13E remains preferred.

Files reviewed:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming.sv`
- `scripts/run_xsim_regression.ps1`
- `scripts/run_vivado_impl_pipeline_forwardtiming.tcl`
- `reports/phase13e_forwarding_timing.md`
- `reports/phase13g_registered_target_buffer.md`

Simulator:

- Vivado XSim 2026.1

Result:

- Full local XSim regression was rerun after Phase 13G was added.
- Final transcript: `reports/simulation_transcripts/phase13h_xsim_regression_final_20260713_124649.txt`.
- The final transcript includes `All XSim regression tests completed.`
- Phase 13E, Phase 13F and Phase 13G pipeline tests all reported 0 failures.
- A previous full-regression attempt hit a Vivado/XSim snapshot cleanup/kernel issue on the Phase 13G snapshot. A shorter Phase 13G snapshot name in `scripts/run_xsim_regression.ps1` fixed the regression-script issue without changing RTL.

Final Phase 13E timing sweep:

| Period | WNS | TNS | WHS | THS | Status |
| ---: | ---: | ---: | ---: | ---: | --- |
| 8.900 ns | +0.059 ns | 0.000 ns | +0.040 ns | 0.000 ns | Passed |
| 8.850 ns | +0.126 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed, final accepted result |
| 8.800 ns | -0.026 ns | -0.161 ns | +0.039 ns | 0.000 ns | Failed setup |

Final accepted result:

| Metric | Value |
| --- | ---: |
| Preferred implementation | Phase 13E forwarding-timing pipeline |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Final verified period | 8.850 ns |
| Final verified Fmax | 112.994 MHz |
| Practical estimated MIPS | ~84.4 |
| LUTs | 1,383 |
| FFs | 1,513 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |

Report:

- `reports/phase13h_preferred_pipeline_summary.md`

Conclusion:

Phase 13H confirms that Phase 13E is the current preferred measured FPGA implementation path. The final verified result is about 84.4 practical estimated MIPS. The 90 MIPS target is not yet reached.

## Phase 13I Implementation Strategy Sweep

Status: passed; Phase 13I becomes the preferred implementation strategy for the unchanged Phase 13E RTL.

Files reviewed:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming.tcl`
- `reports/phase13h_preferred_pipeline_summary.md`

Files added:

- `scripts/run_vivado_phase13i_strategy_sweep.tcl`
- `reports/phase13i_strategy_sweep.md`

Functional verification:

- No RTL, testbench, instruction encoding or benchmark program changed in Phase 13I.
- No new functional testbench was required.
- The functional evidence remains the Phase 13H full XSim regression: `reports/simulation_transcripts/phase13h_xsim_regression_final_20260713_124649.txt`.

Vivado implementation strategy sweep:

| Strategy | Period | WNS | TNS | WHS | THS | Status |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Phase 13H baseline | 8.850 ns | +0.126 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed |
| Phase 13H baseline | 8.800 ns | -0.026 ns | -0.161 ns | +0.039 ns | 0.000 ns | Failed setup |
| `route_highcost` | 8.800 ns | -0.087 ns | -0.512 ns | +0.039 ns | 0.000 ns | Failed setup |
| `fanout_opt` | 8.800 ns | +0.012 ns | 0.000 ns | +0.039 ns | 0.000 ns | Passed |
| `fanout_opt` | 8.750 ns | +0.012 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed |
| `fanout_opt` | 8.700 ns | +0.034 ns | 0.000 ns | +0.094 ns | 0.000 ns | Passed |
| `fanout_opt` | 8.650 ns | +0.059 ns | 0.000 ns | +0.057 ns | 0.000 ns | Passed |

Final accepted result:

| Metric | Value |
| --- | ---: |
| Preferred RTL | Phase 13E forwarding-timing pipeline |
| Preferred implementation strategy | Phase 13I `fanout_opt` |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Final verified period | 8.650 ns |
| Final verified Fmax | 115.607 MHz |
| Practical estimated MIPS | ~86.4 |
| LUTs | 1,363 |
| FFs | 1,510 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |

Report:

- `reports/phase13i_strategy_sweep.md`

Conclusion:

Phase 13I improves the preferred measured result from about 84.4 MIPS to about 86.4 MIPS without changing CPU behaviour. The 90 MIPS target is still not reached.

## Phase 14A Deeper Pipeline Architecture Plan

Status: planning-only; no RTL or simulation changes.

Files reviewed:

- `rtl/cpu_core_pipeline_forwardtiming.sv`
- `rtl/fpga_top_pipeline_forwardtiming.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming.sv`
- `reports/phase13i_strategy_sweep.md`
- `reports/phase13h_preferred_pipeline_summary.md`
- `reports/phase13e_forwarding_timing.md`

Planning output:

- `reports/phase14a_deeper_pipeline_plan.md`

Summary:

- Phase 14A proposes a future six-stage pipeline: IF -> ID -> OP -> EX -> MEM -> WB.
- The new OP stage would separate operand read, bypass preparation and forwarding selection from decode/execute timing.
- The current Phase 13I result remains the preferred measured implementation until a future Phase 14 implementation passes full regression and beats about 86.4 practical estimated MIPS.
- No new simulation was run because this phase did not add or modify RTL.

## Phase 14B Six-Stage Pipeline Skeleton

Status: focused simulation passed; full local regression passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_skeleton.sv`

Focused transcript:

- `reports/simulation_transcripts/phase14b_pipeline6_skeleton_focused_20260713_192051.txt`

Full regression transcript:

- `reports/simulation_transcripts/phase14b_full_xsim_regression_20260713_192118.txt`

Coverage:

- Reset clears fetch request state, pipeline valid bits, retirement pulse and retired count.
- Synchronous instruction-BRAM responses are paired with saved request PCs.
- Sequential request PCs are issued at 0, 4, 8, 12 and 16 bytes.
- A known instruction advances through IF/ID, ID/OP, OP/EX, EX/MEM and MEM/WB in order.
- `enable = 0` pauses fetch metadata and all pipeline registers without retirement.
- Pause/resume preserves a pending BRAM response using a small paused-response buffer.
- NOP flows as a valid software instruction and retires once.
- Invalid opcode becomes a hardware bubble and does not retire.
- No register-write or memory-write side-effect pulse occurs.

Result:

- Focused checks run: 198
- Focused failures: 0
- Full local XSim regression completed successfully after adding the Phase 14B test.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

Conclusion:

Phase 14B proves the separate IF -> ID -> OP -> EX -> MEM -> WB skeleton structure. It does not implement arithmetic, memory, control-flow redirects, forwarding or timing measurement yet, so no performance improvement is claimed. Phase 13E with the Phase 13I `fanout_opt` implementation remains the preferred measured path.

## Phase 14C Six-Stage Pipeline Arithmetic

Status: focused simulation passed; full local regression passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_arithmetic.sv`

Focused transcript:

- `reports/simulation_transcripts/phase14c_pipeline6_arithmetic_focused_20260713_194940.txt`

Full regression transcript:

- `reports/simulation_transcripts/phase14c_full_xsim_regression_20260713_195034.txt`

Coverage:

- Reset clears pipeline and internal architectural registers.
- ADDI writes `x1 = 5`, `x2 = 7` and sign-extends `-1` into `x8`.
- ADD, SUB, AND, OR and XOR execute correctly.
- Writes to `x0` are ignored.
- Back-to-back arithmetic dependencies are handled with simple forwarding from OP/EX, EX/MEM and MEM/WB sources.
- NOP retires safely without a register write.
- Invalid opcode becomes a bubble and does not retire or write.
- No memory-write pulse occurs in Phase 14C.
- Pause/resume holds pipeline and register state safely.

Result:

- Focused checks run: 377
- Focused failures: 0
- Full local XSim regression completed successfully after adding the Phase 14C test.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

Conclusion:

Phase 14C proves arithmetic execution for the separate six-stage pipeline path. It does not implement LOAD/STORE, BEQ/JUMP, full memory/control forwarding or Phase 14 timing measurement, so no performance improvement is claimed. Phase 13E with the Phase 13I `fanout_opt` implementation remains the preferred measured path.

## Phase 14D Six-Stage Pipeline Memory

Status: focused simulation passed; full local regression passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_memory.sv`

Focused transcript:

- `reports/simulation_transcripts/phase14d_pipeline6_memory_focused_20260713_202559.txt`

Full regression transcript:

- `reports/simulation_transcripts/phase14d_full_xsim_regression_20260713_202642.txt`

Coverage:

- Reset clears pipeline and internal architectural registers.
- STORE writes data memory word 16 using `[x1 + 0]`.
- LOAD reads back data from `[x1 + 0]`.
- STORE and LOAD work with a `+4` byte offset.
- Negative-offset LOAD reads `[x5 - 4]`.
- STORE-data forwarding works for a recently produced arithmetic result.
- LOAD-use arithmetic dependency is handled safely.
- LOAD-use STORE dependency is handled safely.
- Writes to `x0` from LOAD and ADDI are ignored.
- Invalid opcode becomes a bubble and does not retire, write a register or write memory.
- NOP retires safely without register or memory side effects.
- Pause/resume during data-memory activity holds state and does not duplicate STORE writes.

Result:

- Focused checks run: 489
- Focused failures: 0
- Full local XSim regression completed successfully after adding the Phase 14D test.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

Conclusion:

Phase 14D proves LOAD/STORE execution for the separate six-stage pipeline path using synchronous data memory. It does not implement BEQ/JUMP redirects, wrong-path protection, full custom-ISA benchmarking or Phase 14 timing measurement, so no performance improvement is claimed. Phase 13E with the Phase 13I `fanout_opt` implementation remains the preferred measured path.

## Phase 14E Six-Stage Pipeline Control Flow

Status: focused simulation passed; full local regression passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_control.sv`

Focused transcript:

- `reports/simulation_transcripts/phase14e_pipeline6_control_focused_20260713_205349.txt`

Full regression transcript:

- `reports/simulation_transcripts/phase14e_full_xsim_regression_20260713_205407.txt`

Coverage:

- BEQ not taken executes the fall-through path.
- BEQ taken redirects to the target and flushes the wrong-path instruction.
- Wrong-path STORE after BEQ is blocked.
- JUMP forward redirects to the target and flushes the wrong-path instruction.
- Wrong-path STORE after JUMP is blocked.
- BEQ consumes forwarded arithmetic operands.
- BEQ after LOAD is held or forwarded safely through the existing load-use handling.
- Backward loop with BEQ exit and JUMP back-edge reaches the expected final register and memory state.
- Invalid opcode at a redirected target remains a safe bubble.
- NOP remains safe.
- Pause/resume around a control redirect holds state and suppresses retirement, register writes and memory writes.

Result:

- Focused checks run: 2,812
- Focused failures: 0
- Full local XSim regression completed successfully after adding the Phase 14E test.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

Conclusion:

Phase 14E proves BEQ and JUMP redirect correctness for the separate six-stage pipeline path, including stale fetch-response invalidation and wrong-path side-effect protection. It does not include branch prediction, target buffering, full custom-ISA benchmarking or Phase 14 timing measurement, so no performance improvement is claimed. Phase 13E with the Phase 13I `fanout_opt` implementation remains the preferred measured path.

## Phase 14F Six-Stage Pipeline Full Program Verification

Status: focused simulation passed; full local regression passed.

Files tested:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `tb/tb_cpu_core_pipeline6_full_program.sv`

Focused transcript:

- `reports/simulation_transcripts/phase14f_pipeline6_full_program_focused_20260714_110746.txt`

Full regression transcript:

- `reports/simulation_transcripts/phase14f_full_xsim_regression_20260714_110824.txt`

Coverage:

- ADDI, ADD, SUB, AND, OR and XOR execute in a full-program context.
- Negative imm13 sign extension is checked.
- `x0` protection is checked for both LOAD and ADDI paths.
- STORE and LOAD execute with positive and negative signed offsets.
- Load-use arithmetic and load-use STORE dependencies are checked.
- BEQ taken, BEQ not taken, forward JUMP and backward JUMP loop execution are checked.
- Wrong-path register write and wrong-path STORE protection are checked.
- Invalid opcode safety is checked.
- NOP safety is checked.
- Pause/resume during in-flight execution holds state and suppresses side effects.
- Final register state, final data memory state and repeated loop retirement counts are checked.

Result:

- Focused checks run: 97
- Focused failures: 0
- Enabled cycles: 95
- Retired instructions: 58
- CPI: 1.638
- Branch redirects: 2
- Jump redirects: 3
- Total redirects: 5
- Flush pulses: 5
- Load-use stalls: 10
- Memory writes: 11
- Full local XSim regression completed successfully after adding the Phase 14F test.
- The known Vivado/XSim `xelab` object-directory cleanup warning appeared after snapshot builds, but XSim completed and self-checking tests passed.

Conclusion:

Phase 14F proves full custom-ISA style program execution for the separate six-stage pipeline path and measures simulation CPI. The measured CPI of 1.638 is higher than the Phase 13I preferred CPI of 1.339, so Phase 14 requires enough post-route Fmax improvement to replace Phase 13I.

## Phase 14G Six-Stage Pipeline Vivado Timing

Status: Vivado implementation and timing sweep passed; Phase 14G becomes the preferred measured implementation result.

Implementation script:

- `scripts/run_vivado_impl_pipeline6.tcl`

Source files used:

- `rtl/cpu_defs_pkg.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`
- `rtl/cpu_core_pipeline6.sv`
- `rtl/fpga_top_pipeline6.sv`
- `constraints/basys3.xdc`

Timing sweep result:

| Period | Fmax | WNS | TNS | WHS | Bitstream | MIPS using CPI 1.638 |
| ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 8.000 ns | 125.000 MHz | +0.841 ns | 0.000 ns | +0.058 ns | pass | 76.313 |
| 7.500 ns | 133.333 MHz | +0.694 ns | 0.000 ns | +0.098 ns | pass | 81.400 |
| 7.000 ns | 142.857 MHz | +0.451 ns | 0.000 ns | +0.059 ns | pass | 87.214 |
| 6.800 ns | 147.059 MHz | +0.344 ns | 0.000 ns | +0.057 ns | pass | 89.780 |
| 6.750 ns | 148.148 MHz | +0.533 ns | 0.000 ns | +0.082 ns | pass | 90.445 |
| 6.700 ns | 149.254 MHz | +0.337 ns | 0.000 ns | +0.054 ns | pass | 91.119 |
| 6.650 ns | 150.376 MHz | +0.212 ns | 0.000 ns | +0.034 ns | pass | 91.805 |
| 6.500 ns | 153.846 MHz | +0.129 ns | 0.000 ns | +0.033 ns | pass | 93.923 |
| 6.400 ns | 156.250 MHz | +0.216 ns | 0.000 ns | +0.059 ns | pass | 95.391 |
| 6.200 ns | 161.290 MHz | +0.088 ns | 0.000 ns | +0.037 ns | pass | 98.468 |
| 6.100 ns | 163.934 MHz | +0.041 ns | 0.000 ns | +0.101 ns | pass | 100.082 |
| 6.000 ns | 166.667 MHz | +0.024 ns | 0.000 ns | +0.058 ns | pass | 101.750 |

Best verified result:

- Best passing period tested: 6.000 ns
- Verified Fmax: 166.667 MHz
- Phase 14F CPI used: 1.638
- Practical estimated MIPS: 101.750
- LUTs: 1,308
- FFs: 1,602
- BRAM: 1 Block RAM Tile / 2 RAMB18
- DSP: 0
- THS: 0.000 ns
- Bitstream: generated

Critical path:

- Source: `cpu_inst/op_ex_reg_reg[operand_b][1]/C`
- Destination: `cpu_inst/op_ex_reg_reg[store_data][1]/R`
- Data path delay: 5.376 ns
- Logic delay: 1.891 ns
- Route delay: 3.485 ns
- Logic levels: 6

Conclusion:

Phase 14G beats the Phase 13I result of about 86.4 MIPS and reaches the 90 MIPS target. It also crosses 100 MIPS in the measured post-route sweep, with a practical estimated result of about 101.8 MIPS. The raw Vivado output remains under `reports/phase14g_impl/`; the human-readable summary is `reports/phase14g_pipeline6_timing.md`.

## Phase 15A Basys 3 Slow-Enable Bring-Up Wrapper

Status: Vivado implementation and bitstream generation passed; physical board observation is the next evidence step.

Files added:

- `rtl/fpga_top_pipeline6_bringup.sv`
- `scripts/run_vivado_impl_pipeline6_bringup.tcl`
- `reports/phase15a_basys3_bringup.md`

Vivado implementation:

- Top: `fpga_top_pipeline6_bringup`
- Target: Basys 3, `xc7a35tcpg236-1`
- Clock: 10.000 ns / 100 MHz
- Bitstream: `reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit`

Board control mapping:

- BTNC / `rst_btn`: synchronized CPU reset
- SW0 / `sw[0]`: run enable
- SW1 / `sw[1]`: slow mode select

LED mapping:

- `led[3:0]`: fetch PC word index
- `led[8:4]`: IF/ID, ID/OP, OP/EX, EX/MEM and MEM/WB valid bits
- `led[9]`: stall/load-use stall
- `led[10]`: redirect pulse
- `led[11]`: retirement pulse
- `led[12]`: register-write pulse
- `led[13]`: memory-write pulse
- `led[14]`: slow mode active
- `led[15]`: run enable active

Implementation result:

- WNS: +2.444 ns
- TNS: 0.000 ns
- WHS: +0.062 ns
- THS: 0.000 ns
- LUTs: 1,321
- FFs: 1,633
- BRAM: 1 Block RAM Tile / 2 RAMB18
- DSP: 0
- Bitstream generation: passed

Board test procedure:

1. Program `fpga_top_pipeline6_bringup.bit` in Vivado Hardware Manager.
2. Confirm DONE/startup status is high.
3. Set SW0 low and SW1 high.
4. Press and release BTNC reset.
5. Set SW0 high.
6. Observe slow LED stepping.
7. Set SW0 low again and confirm the LED state freezes.

Conclusion:

Phase 15A provides a hardware-observable wrapper for the Phase 14G CPU without changing the CPU core or instruction encodings. It does not replace the Phase 14G performance result; it makes board bring-up practical using the 100 MHz clock and a slow CPU-enable pulse.

## Phase 15B Sticky Event LEDs

Status: Vivado implementation and bitstream generation passed; physical board observation is the next evidence step.

Files changed:

- `rtl/fpga_top_pipeline6_bringup.sv`
- `reports/phase15b_sticky_event_leds.md`
- `README.md`
- `docs/verification.md`

Problem addressed:

- Phase 15A mapped LEDs 9-13 directly to one-cycle event pulses.
- In slow mode, the CPU advances using one 100 MHz clock-enable pulse.
- A one-cycle event pulse is about 10 ns wide, so it is not human-visible on the Basys 3 LEDs.

Phase 15B behavior:

- LEDs 9-13 are now sticky event indicators.
- BTNC reset clears the sticky flags.
- SW0 pause does not clear the sticky flags.
- SW1 slow/full-speed mode changes do not clear the sticky flags.

Updated LED mapping:

- `led[3:0]`: fetch PC word index
- `led[8:4]`: IF/ID, ID/OP, OP/EX, EX/MEM and MEM/WB valid bits
- `led[9]`: sticky stall/load-use stall observed
- `led[10]`: sticky redirect observed
- `led[11]`: sticky retire observed
- `led[12]`: sticky register-write observed
- `led[13]`: sticky memory-write observed
- `led[14]`: slow mode active
- `led[15]`: run enable active

Vivado implementation:

- Script: `scripts/run_vivado_impl_pipeline6_bringup.tcl`
- Top: `fpga_top_pipeline6_bringup`
- Bitstream: `reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit`

Implementation result:

- WNS: +1.472 ns
- TNS: 0.000 ns
- WHS: +0.039 ns
- THS: 0.000 ns
- LUTs: 1,323
- FFs: 1,638
- BRAM: 1 Block RAM Tile / 2 RAMB18
- DSP: 0
- Bitstream generation: passed

Hardware test procedure:

1. Program the Phase 15B bring-up bitstream.
2. Set SW0 = 0.
3. Set SW1 = 1 for slow mode.
4. Press and release BTNC reset.
5. Confirm LEDs 9-13 are initially off.
6. Set SW0 = 1.
7. Watch `led[3:0]` and `led[8:4]` step through the sequence.
8. Confirm `led[11]` turns on after at least one instruction retires.
9. Confirm `led[12]` turns on after at least one register write occurs, if the loaded program writes a register.
10. Confirm `led[13]` turns on after a store occurs, if the loaded program contains a store.
11. Confirm `led[10]` turns on after a branch or jump redirect occurs, if the loaded program contains one.
12. Turn SW0 off and confirm the CPU freezes but sticky event LEDs remain on.
13. Press BTNC reset and confirm sticky event LEDs clear.

Conclusion:

Phase 15B makes the bring-up LEDs useful for physical evidence by converting short event pulses into reset-cleared sticky indicators. This is an observability change only; it does not change `cpu_core_pipeline6.sv`, instruction encodings or the Phase 14G performance result.

## Phase 16A Hardware MIPS 7-Segment Counter

Status: Vivado implementation and bitstream generation passed for the 100 MHz Basys 3 hardware MIPS counter wrapper.

Files added:

- `rtl/fpga_top_pipeline6_perf7seg.sv`
- `scripts/run_vivado_impl_pipeline6_perf7seg.tcl`
- `reports/phase16a_hardware_mips_7seg.md`

Purpose:

- Count retired instructions from `cpu_core_pipeline6` in real FPGA hardware.
- Use a one-second measurement window at the normal 100 MHz Basys 3 board clock.
- Display integer MIPS on the four-digit 7-segment display.
- Keep Phase 14G timing/performance evidence unchanged.

Top-level wrapper:

- `fpga_top_pipeline6_perf7seg`

Switch and reset mapping:

| Board control | Function |
| --- | --- |
| BTNC | synchronized reset |
| SW0 | full-speed run enable |
| SW1 | reserved for later display/debug selection |

Measurement convention:

```text
MIPS = retired instructions in one second / 1,000,000
```

The CPU runs from the real 100 MHz board clock. SW0 controls the CPU clock-enable input; no fabric-derived CPU clock is created.

Expected approximate display value:

```text
100 MHz / 1.638 CPI = 61.05 MIPS
```

The display is therefore expected to show about `0061` when the loaded program has similar CPI behavior. The actual value depends on `programs/fpga_led_demo.mem`.

LED mapping:

| LED | Signal |
| --- | --- |
| `led[3:0]` | fetch PC word index |
| `led[8:4]` | pipeline valid bits |
| `led[9]` | sticky measurement-window-completed flag |
| `led[10]` | sticky redirect observed |
| `led[11]` | sticky retire observed |
| `led[12]` | sticky register-write observed |
| `led[13]` | sticky memory-write observed |
| `led[14]` | measurement active |
| `led[15]` | run enable |

Vivado command used:

```powershell
& 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch -source scripts/run_vivado_impl_pipeline6_perf7seg.tcl
```

Implementation result:

| Metric | Result |
| --- | ---: |
| Target period | 10.000 ns |
| WNS | +2.336 ns |
| TNS | 0.000 ns |
| WHS | +0.038 ns |
| THS | 0.000 ns |
| LUTs | 1,388 |
| FFs | 1,719 |
| BRAM | 1 Block RAM Tile / 2 RAMB18 |
| DSP | 0 |
| Total on-chip power estimate | 0.099 W |
| Bitstream generation | Passed |

Bitstream path:

- `reports/phase16a_perf7seg_impl/bitstreams/fpga_top_pipeline6_perf7seg.bit`

Hardware test procedure:

1. Program the Basys 3 with `reports/phase16a_perf7seg_impl/bitstreams/fpga_top_pipeline6_perf7seg.bit`.
2. Confirm DONE/startup status is high.
3. Set `SW0 = 0`.
4. Press and release BTNC reset.
5. Confirm the 7-segment display shows `0000` or the reset value.
6. Set `SW0 = 1`.
7. Wait at least two seconds for the first one-second measurement window to complete.
8. Observe the displayed integer MIPS value.
9. Set `SW0 = 0` and confirm the displayed value remains latched.
10. Press BTNC reset and confirm the display clears.

Limitations:

- Phase 16A measures the CPU at the 100 MHz board clock only.
- It does not prove 166.667 MHz physical operation.
- The measured MIPS depends on the instruction program loaded in instruction memory.
- Integer display loses fractional precision.

Conclusion:

Phase 16A adds a hardware-visible performance counter wrapper without modifying `cpu_core_pipeline6.sv`, Phase 13E/13I RTL, instruction encodings or Phase 14G timing evidence. The wrapper is ready for board measurement at 100 MHz.

## Phase 16B CPU Bitstream Comparison Bundle

Status: local comparison bundle generated successfully.

Files added:

- `scripts/collect_cpu_comparison_bitstreams.ps1`
- `reports/phase16b_cpu_bitstream_bundle.md`

Generated local artifacts:

- `reports/phase16b_cpu_bitstream_bundle/manifest.csv`
- `reports/phase16b_cpu_bitstream_bundle/bitstreams/`

Command used:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\collect_cpu_comparison_bitstreams.ps1
```

Result:

- 16 selected CPU/bring-up bitstreams were found and copied into the bundle.
- No selected bitstreams were missing.

Important measurement note:

- `phase16a_pipeline6_perf7seg.bit` is the only bundled bitstream with the 7-segment hardware MIPS counter.
- Earlier CPU bitstreams are LED/debug or bring-up wrappers unless a dedicated MIPS-counter wrapper is added later.
- The Phase 16A board reading of about 63 MIPS is close to the expected 100 MHz estimate of about 61 MIPS for CPI 1.638.

Conclusion:

Phase 16B makes board programming and architecture comparison easier by collecting the generated CPU bitstreams into one local bundle. It does not modify CPU RTL and does not create new performance claims.

## Phase 16C Full-Speed MIPS-Counter Comparison Bitstreams

Status: Vivado implementation and bitstream generation passed for six representative full-speed MIPS-counter CPU wrappers.

Files added:

- `rtl/fpga_top_cpu_mips_compare.sv`
- `scripts/run_vivado_impl_cpu_mips_compare.tcl`
- `scripts/build_cpu_mips_compare_bitstreams.ps1`
- `reports/phase16c_cpu_mips_compare_bitstreams.md`

Generated local artifacts:

- `reports/phase16c_cpu_mips_compare_impl/`
- `reports/phase16c_cpu_mips_compare_bitstreams/`

Command used:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_cpu_mips_compare_bitstreams.ps1
```

The Vivado command needed unsandboxed execution because Vivado performs temporary writeability checks that fail inside the restricted sandbox.

Comparison bitstreams:

| CPU ID | Bitstream | CPU path | 100 MHz timing |
| ---: | --- | --- | --- |
| 0 | `phase08_multicycle_perf7seg.bit` | Phase 8G multi-cycle CPU | Pass |
| 1 | `phase10h_bram_multicycle_perf7seg.bit` | Phase 10H BRAM multi-cycle CPU | Pass |
| 2 | `phase11e_ctrlopt_prefetch_perf7seg.bit` | Phase 11E ctrlopt prefetch CPU | Pass |
| 3 | `phase12_pipeline_perf7seg.bit` | Phase 12 five-stage pipeline | Pass |
| 4 | `phase13e_13i_forwardtiming_perf7seg.bit` | Phase 13E/13I forwarding-timing pipeline | Pass |
| 5 | `phase14g_pipeline6_perf7seg.bit` | Phase 14G six-stage pipeline | Pass |

Timing summary:

| CPU | WNS | TNS | WHS | THS |
| --- | ---: | ---: | ---: | ---: |
| Phase 8G multi-cycle | +0.581 ns | 0.000 ns | +0.046 ns | 0.000 ns |
| Phase 10H BRAM multi-cycle | +2.799 ns | 0.000 ns | +0.104 ns | 0.000 ns |
| Phase 11E ctrlopt prefetch | +0.334 ns | 0.000 ns | +0.133 ns | 0.000 ns |
| Phase 12 pipeline | +0.099 ns | 0.000 ns | +0.035 ns | 0.000 ns |
| Phase 13E/13I forwardtiming | +0.256 ns | 0.000 ns | +0.038 ns | 0.000 ns |
| Phase 14G pipeline6 | +2.253 ns | 0.000 ns | +0.056 ns | 0.000 ns |

Board procedure:

1. Program a bitstream from `reports/phase16c_cpu_mips_compare_bitstreams/`.
2. Set `SW0 = 0`.
3. Press and release BTNC reset.
4. Set `SW1 = 1` and confirm the static CPU ID.
5. Set `SW1 = 0`.
6. Set `SW0 = 1`.
7. Wait at least two seconds.
8. Record the displayed integer MIPS value.

Conclusion:

Phase 16C makes direct board MIPS comparison practical for the representative CPU families without modifying the CPU cores. All six generated wrappers pass 100 MHz timing and generate bitstreams.

## Final Hardware Performance Summary

Status: Basys 3 hardware MIPS measurements recorded at the fixed 100 MHz board clock.

Hardware-measured MIPS table:

| CPU version | Hardware-measured MIPS at 100 MHz | Calculated CPI |
| --- | ---: | ---: |
| Phase 8 MC | 26 | 3.85 |
| Phase 10 BRAM + MC | 21 | 4.76 |
| Phase 11E Control Optimised | 35 | 2.86 |
| Phase 12 Pipeline, 5 Stage | 77 | 1.30 |
| Phase 13 Forward Timing | 87 | 1.15 |
| Phase 14G Pipeline, 6 Stage | 63 | 1.59 |

Calculation:

```text
CPI = 100 / MIPS
MIPS = clock frequency in MHz / CPI
```

At the fixed 100 MHz Basys 3 board clock, the Phase 13 five-stage forwarded pipeline produced the best measured hardware throughput, around 87 MIPS. The Phase 14G six-stage pipeline measured around 63 MIPS at the same board clock. This does not mean the six-stage design failed; it shows a CPI versus clock-frequency trade-off.

Phase 13 versus Phase 14G:

- Phase 13 five-stage pipeline:
  - Hardware measured at 100 MHz: approximately 87 MIPS.
  - Implied CPI: approximately 1.15.
  - Strongest result for fixed 100 MHz Basys 3 board operation.
- Phase 14G six-stage pipeline:
  - Hardware measured at 100 MHz: approximately 63 MIPS.
  - Implied CPI: approximately 1.59.
  - Post-route timing-clean result: 6.000 ns.
  - Timing-clean frequency: 166.667 MHz.
  - Simulation CPI used for estimate: 1.638.
  - Estimated peak practical throughput: 166.667 / 1.638 = approximately 101.8 MIPS.

Break-even calculation:

```text
required frequency = 87 * 1.638 = approximately 142.5 MHz
```

Since Phase 14G closed timing at 166.667 MHz, the timing estimate suggests it could exceed Phase 13 if the board implementation is clocked above approximately 142.5 MHz. The current physical hardware MIPS display measurement was performed at 100 MHz.

Conclusion:

- At the fixed 100 MHz board clock, Phase 13 is the best hardware-measured design.
- For timing closure and estimated peak frequency, Phase 14G is the strongest design.
- The project demonstrates a real CPU engineering trade-off between CPI and maximum clock frequency.

## Phase 15A/15B Physical Bring-Up Evidence

Status: physical bring-up path prepared and observed through slow stepping and sticky LEDs.

Phase 15A hardware evidence summary:

- Phase 15A added a slow-enable Basys 3 bring-up wrapper.
- SW0 is run enable.
- SW1 selects slow mode.
- BTNC is reset.
- `LED[3:0]` shows fetch PC word index.
- `LED[8:4]` shows pipeline valid bits.

Phase 15B hardware evidence summary:

- Phase 15B added sticky event LEDs.
- `LD10` latches when a branch/jump redirect occurs.
- `LD11` latches when an instruction retires.
- `LD12` latches when a register write occurs.
- The sticky LEDs remain on when SW0 is turned off, proving pause/freeze while preserving evidence.
- BTNC reset clears the sticky LEDs.

## Phase 16A Physical Hardware MIPS Measurement

Status: Basys 3 board measurement recorded.

Measurement method:

- The FPGA counts retired instructions using the CPU `retire_valid` debug signal.
- The FPGA counts a one-second measurement window using the 100 MHz board clock.
- MIPS is calculated as retired instructions in one second divided by 1,000,000.
- The 7-segment display showed `0063` during the Phase 16A hardware test.
- This corresponds to approximately 63 MIPS at the 100 MHz board clock.
- This implies `CPI = 100 / 63 = approximately 1.59`.
- This is close to the Phase 14F/14G simulation CPI estimate of approximately 1.638.

Hardware test sequence:

1. Program the Phase 16A bitstream.
2. Confirm DONE/startup status high.
3. Press BTNC reset.
4. Set SW0 on for full-speed run.
5. Wait at least two measurement windows.
6. Read the 7-segment display.
7. Observed value: `0063`.
8. Interpret as approximately 63 MIPS at 100 MHz.

Caution:

The 63 MIPS value is a direct hardware measurement at the 100 MHz Basys 3 board clock. It should not be confused with the Phase 14G post-route timing estimate of approximately 101.8 MIPS, which assumes a 166.667 MHz clock.

Limitations:

- The hardware MIPS counter currently measures at the 100 MHz board clock.
- The Phase 16A measurement does not prove 166.667 MHz physical operation.
- The measured MIPS depends on the benchmark program loaded into instruction memory.
- The 7-segment display currently shows integer MIPS, so fractional precision is lost.
- Future work could add an MMCM/Clocking Wizard experiment to measure at higher hardware frequencies.
- Future work could use a benchmark program identical to the simulation benchmark for stricter comparison.

Recommended future work:

- Phase 16B: benchmark alignment so simulation and hardware use the same workload.
- Phase 16C: optional MMCM/Clocking Wizard high-frequency hardware MIPS test.
- Phase 16D: UART or ILA output for detailed performance counters.
- Final report: architecture diagrams, pipeline diagrams, performance plots and board evidence photos.

## Phase 17A Forward-Timing Hardware Profiling Procedure

Status: profiling wrapper and Vivado script added; board counter values pending.

Files added:

- `rtl/fpga_top_pipeline_forwardtiming_profile.sv`
- `scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl`
- `reports/phase17a_forwardtiming_profile.md`

Purpose:

- Profile the Phase 13 forward-timing five-stage CPU because it is the best fixed-100 MHz board-measured path.
- Measure integer MIPS over a one-second 100 MHz board-clock window.
- Show integer MIPS and CPI x100 on the 7-segment display.
- Preserve the unchanged `cpu_core_pipeline_forwardtiming.sv` RTL.

Board controls:

- BTNC: reset.
- SW0: run enable.
- SW1 = 0: integer MIPS.
- SW1 = 1: CPI x100.

Hardware procedure:

1. Build the bitstream with `scripts/run_vivado_impl_pipeline_forwardtiming_profile.tcl`.
2. Program `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`.
3. Press and release BTNC reset.
4. Set SW0 on.
5. Wait at least two one-second measurement windows.
6. Set SW1 low and read the displayed MIPS value.
7. Set SW1 high and read CPI x100.
8. Record the result in `reports/phase17b_forwardtiming_bottleneck_analysis.md`.

Expected approximate result:

- MIPS: about 87 at the 100 MHz board clock.
- CPI x100 display: about 115.

Front-end check:

- `xvlog` compile passed for the Phase 17A profiling wrapper source order.
- `xelab` elaboration passed for `fpga_top_pipeline_forwardtiming_profile`.
- The first sandboxed elaboration built the snapshot but hit the known XSim object-directory cleanup access warning; rerunning with normal filesystem access completed successfully.
- Vivado implementation and bitstream generation passed at 10.000 ns with the registered CPI x100 display mode.
- Timing result: WNS +0.313 ns, TNS 0.000 ns, WHS +0.037 ns, THS 0.000 ns.
- Bitstream: `reports/phase17a_forwardtiming_profile_impl/bitstreams/fpga_top_pipeline_forwardtiming_profile.bit`.

## Phase 17C Regression Procedure

Status: focused XSim passed; full local regression was started but interrupted before completion.

Phase 17C created a separate optimised copy of the Phase 13 forward-timing pipeline:

- `rtl/cpu_core_pipeline_forwardtiming_opt.sv`
- `rtl/fpga_top_pipeline_forwardtiming_opt.sv`
- `tb/tb_cpu_core_pipeline_forwardtiming_opt.sv`

The original Phase 13E/13I files were not modified.

Optimisation tested:

- direct EX-stage branch-target request for taken BEQ redirects;
- existing ID-stage fast JUMP behaviour preserved;
- load-use detection and forwarding behaviour otherwise preserved.

Focused command sequence:

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat -sv rtl\cpu_defs_pkg.sv rtl\bram_instr_mem.sv rtl\bram_data_mem.sv rtl\cpu_core_pipeline_forwardtiming_opt.sv tb\tb_cpu_core_pipeline_forwardtiming_opt.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat tb_cpu_core_pipeline_forwardtiming_opt -s tb_cpu_core_pipeline_forwardtiming_opt_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat tb_cpu_core_pipeline_forwardtiming_opt_sim -runall
```

Focused XSim result:

- Tests run: 3,217.
- Tests failed: 0.
- Aggregate cycles: 424.
- Aggregate retired instructions: 319.
- Aggregate CPI: 1.329.
- Aggregate MIPS at 100 MHz from simulation CPI: 75.236.
- Console output included `Phase 17C forwardtiming_opt PIPELINE TEST PASSED`.

Vivado implementation:

- Script: `scripts/run_vivado_impl_pipeline_forwardtiming_opt.tcl`.
- Target period: 10.000 ns.
- Bitstream generation completed, but timing failed setup.
- WNS -0.552 ns, TNS -2.159 ns, WHS +0.088 ns, THS 0.000 ns.
- LUTs 1,387, FFs 1,469, BRAM 1 Block RAM Tile / 2 RAMB18, DSP 0.

Decision:

- Phase 17C is functionally correct in simulation but is not an accepted hardware improvement.
- The direct branch-compare/redirect path into instruction BRAM is too timing-expensive.
- Phase 13E/13I remains the preferred five-stage CPU path.

## Phase 17D Forward-Timing Timing Sweep Procedure

Status: optimised-path sweep script added; sweep stopped after the 10.000 ns implementation failed setup timing.

File added:

- `scripts/run_vivado_impl_pipeline_forwardtiming_opt_sweep.tcl`
- `reports/phase17d_forwardtiming_opt_timing_sweep.md`

Purpose:

- Determine whether the Phase 17C optimised forward-timing CPU can close timing at or above 100 MHz.

Default periods:

- 10.000 ns
- 9.500 ns
- 9.000 ns
- 8.750 ns
- 8.650 ns
- 8.500 ns
- 8.250 ns
- 8.000 ns

Run command:

```powershell
vivado -mode batch -source scripts\run_vivado_impl_pipeline_forwardtiming_opt_sweep.tcl
```

Decision rule:

- A period only counts as passing if WNS is non-negative, TNS is zero, hold timing passes and bitstream generation succeeds.
- Higher-frequency hardware MIPS should not be claimed until a later board clocking experiment measures it physically.

Actual result:

| Period | WNS | TNS | WHS | THS | Status |
| ---: | ---: | ---: | ---: | ---: | --- |
| 10.000 ns | -0.552 ns | -2.159 ns | +0.088 ns | 0.000 ns | Failed setup |

Tighter periods were not run because the design already failed the 100 MHz baseline constraint.

## Future Verification Work

- Preserve the Phase 14G six-stage pipeline timing evidence and prepare a supervisor-facing final implementation summary.
- Capture physical Basys 3 evidence for the Phase 15B sticky-event slow-enable bitstream, Phase 16A 7-segment MIPS counter bitstream and Phase 16C full-speed comparison MIPS bitstreams.
- Continue adding verification entries for future RTL modules and integration tests.
- Save useful waveform screenshots in `docs/images/`.
- Keep testbenches self-checking.
- Use `$fatal` or an equivalent failure mechanism when checks fail.
- Record simulator, files tested, coverage points and conclusions for each simulation.
