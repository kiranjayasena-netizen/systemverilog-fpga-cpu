# Stage 10B local Vivado/XSim verification

Run these commands from `C:\FPGA\systemverilog-fpga-cpu` in PowerShell. They
use Vivado 2026.1 at the supplied installation path and create disk-backed
temporary projects under dot-prefixed directories. Those directories are
ignored by Git.

## Stage 10A regression

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" `
  -mode batch `
  -source scripts/run_vector_stage10a_xsim.tcl
```

Expected marker: `STAGE10A_XSIM_COMPLETE` and the testbench's 26/26 result.

## Stage 10A/10B equivalence

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" `
  -mode batch `
  -source scripts/run_vector_stage10ab_equivalence_xsim.tcl
```

Expected output contains `PASS EQUIV 1` through `PASS EQUIV 6`, followed by:

```text
Equivalence tests run: 6
Equivalence tests failed: 0
```

## Stage 10B unchanged benchmarks

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" `
  -mode batch `
  -source scripts/run_vector_stage10b_bench_xsim.tcl
```

The benchmark testbench emits machine-readable `BENCH` and `COUNTER` lines.
Use measured cycles only; do not substitute reference values.

For the four-vector array workload:

- cycles/vector = total cycles / 4
- cycles/scalar = total cycles / 16
- scalar additions/cycle = 16 / total cycles
- ALU-active fraction = 4 / total cycles

At 80 MHz, multiply additions/cycle or lane-elements/cycle by 80 MHz. These
are architectural calculations until a later physical implementation validates
the clock.

No synthesis or implementation is performed by these commands.
