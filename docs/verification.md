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

## Future Verification Work

- Continue adding verification entries for future RTL modules and integration tests.
- Save useful waveform screenshots in `docs/images/`.
- Keep testbenches self-checking.
- Use `$fatal` or an equivalent failure mechanism when checks fail.
- Record simulator, files tested, coverage points and conclusions for each simulation.
