# Supervisor Questions

## Project Scope

- Is a simple single-cycle CPU sufficient for the project, or should the design aim for a multi-cycle CPU?
- What level of instruction set complexity is expected?
- Should the CPU support load/store memory operations in the first complete version?
- Are interrupts, pipelining or external memory expected, or are they out of scope?

## FPGA Target

- Which FPGA board should be the primary target?
- Is the current Vivado project target, AC701 / `xc7a200tfbg676-2`, appropriate?
- Is there a required clock frequency target?

## Verification

- What level of verification evidence is expected for each module?
- Are self-checking testbenches and waveform screenshots sufficient for early modules?
- Should any formal verification or assertion-based verification be included?

## Reports and Analysis

- Which reports should be included in the final submission?
- Should timing closure analysis focus on worst negative slack, maximum clock frequency, or both?
- How much resource usage discussion is expected?
- Should power analysis be included if the design is small?

## Documentation

- What format is expected for the final project report?
- How detailed should weekly progress notes be?
- Should Git commit history be used as evidence of progress?
