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
- The ALU waveform screenshot should be saved as `docs/images/alu_waveform.png`.
- No waveform screenshot has been added yet.

Conclusion:

Initial ALU functional simulation passed.

## Future Verification Work

- Add verification entries for each new RTL module.
- Save useful waveform screenshots in `docs/images/`.
- Keep testbenches self-checking.
- Use `$fatal` or an equivalent failure mechanism when checks fail.
- Record simulator, files tested, coverage points and conclusions for each simulation.
