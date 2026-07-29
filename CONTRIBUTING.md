# Contributing

Corrections, documentation improvements and reproducibility reports are
welcome.

Before proposing a change:

1. Check that it applies to the current `main` branch.
2. Keep generated Vivado output, bitstreams and local project folders out of
   the commit.
3. Add or update a self-checking testbench for any RTL behaviour change.
4. Run the relevant XSim tests and record the result.
5. Preserve existing module interfaces unless the change explains and updates
   every dependent testbench, wrapper and document.

For book-specific corrections, identify the edition, page or section and the
matching repository file. Do not rewrite historical results: retain the
distinction between simulation, timing-derived estimates and physical FPGA
measurements.
