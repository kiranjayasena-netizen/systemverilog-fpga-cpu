# Summer Plan

## Week 1 Completed Checklist

- [x] Create project repository.
- [x] Connect GitHub to ChatGPT.
- [x] Install Codex CLI.
- [x] Confirm Vivado 2026.1 is installed.
- [x] Confirm Vivado Basic licence is available.
- [x] Set up repository structure.
- [x] Create `rtl/alu.sv`.
- [x] Create `tb/alu_tb.sv`.
- [x] Run ALU simulation in Vivado XSim.
- [x] Generate and view ALU waveform.
- [x] Improve ALU testbench into a stronger self-checking testbench.
- [x] Add Week 1 documentation.
- [x] Update `.gitignore` for generated files.

## Week 2 Task List

- [x] Define the register file interface.
- [x] Create `rtl/register_file.sv`.
- [x] Create `tb/register_file_tb.sv`.
- [x] Add self-checking register file tests.
- [x] Run Vivado simulation.
- [x] Generate and inspect the register file waveform.
- [x] Save a waveform screenshot under `docs/images/`.
- [x] Update `docs/verification.md` with register file simulation results.
- [x] Review generated files before committing.
- [x] Commit and push the Week 2 work.

## Later Weeks

- FPGA top-level wrapper.
- Constraints and board bring-up.
- Timing, utilisation, power and maximum clock frequency analysis.

## ALU Datapath Alignment In Progress

- [x] Parameterise `rtl/alu.sv` with `WIDTH = 32` by default.
- [x] Update `tb/alu_tb.sv` to test the 32-bit ALU datapath.
- [x] Run the updated ALU testbench in Vivado XSim.
- [x] Refresh `docs/images/alu_waveform.png` from the updated waveform.

## Phase 2 Program Counter Completed

- [x] Create `rtl/program_counter.sv`.
- [x] Create `tb/program_counter_tb.sv`.
- [x] Run Vivado XSim simulation.
- [x] Confirm reset, update, increment, hold and custom load behaviour.
- [x] Save waveform image under `docs/images/`.
- [x] Update verification and architecture documentation.

## Phase 2 Instruction Memory Completed

- [x] Create `rtl/instruction_memory.sv`.
- [x] Create `tb/instruction_memory_tb.sv`.
- [x] Run Vivado XSim simulation.
- [x] Confirm byte-address to word-address mapping.
- [x] Confirm unaligned, unwritten and out-of-range read behaviour.
- [x] Save waveform image under `docs/images/`.
- [x] Update verification and architecture documentation.

## Phase 2 Data Memory Completed

- [x] Create `rtl/data_memory.sv`.
- [x] Create `tb/data_memory_tb.sv`.
- [x] Run Vivado XSim simulation.
- [x] Confirm reset clears memory.
- [x] Confirm aligned and unaligned word-address mapping.
- [x] Confirm disabled reads, disabled writes and out-of-range accesses behave safely.
- [x] Generate `data_memory_tb.vcd`.
- [x] Update verification and architecture documentation.

## Phase 2 Fetch Unit Completed

- [x] Create `rtl/fetch_unit.sv`.
- [x] Create `tb/fetch_unit_tb.sv`.
- [x] Integrate `program_counter` and `instruction_memory`.
- [x] Run Vivado XSim simulation.
- [x] Confirm reset, sequential fetch, enable hold and final reset behaviour.
- [x] Save waveform image under `docs/images/`.
- [x] Update verification and architecture documentation.

## Phase 2 Instruction Decoder Completed

- [x] Create `rtl/instruction_decoder.sv`.
- [x] Create `tb/instruction_decoder_tb.sv`.
- [x] Define the initial 32-bit instruction format.
- [x] Decode opcode, register fields and signed 13-bit immediate.
- [x] Run Vivado XSim simulation.
- [x] Confirm NOP, ADD, SUB, AND, OR, XOR and ADDI decode behaviour.
- [x] Confirm positive and negative immediate sign extension.
- [x] Confirm edge register values.
- [x] Update verification and architecture documentation.

## Phase 2 Control Unit Completed

- [x] Create `rtl/control_unit.sv`.
- [x] Create `tb/control_unit_tb.sv`.
- [x] Map instruction opcodes to register write, immediate select, ALU operation and valid-instruction control signals.
- [x] Run Vivado XSim simulation.
- [x] Confirm NOP, ADD, SUB, AND, OR, XOR and ADDI control behaviour.
- [x] Confirm invalid opcode defaults.
- [x] Update verification and architecture documentation.

## Phase 2 CPU Core Completed

- [x] Create `rtl/cpu_core.sv`.
- [x] Create `tb/cpu_core_tb.sv`.
- [x] Integrate fetch unit, instruction decoder, control unit, register file and ALU.
- [x] Run Vivado XSim simulation.
- [x] Confirm ADDI, ADD, SUB and XOR execution through final register checks.
- [x] Strengthen CPU core test coverage for AND, OR, negative immediates, `x0` protection, invalid opcode protection and NOP.
- [x] Generate `cpu_core_tb.vcd`.
- [x] Update verification and architecture documentation.
