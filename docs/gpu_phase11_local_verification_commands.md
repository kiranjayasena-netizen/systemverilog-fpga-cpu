# Stage 11 local Vivado commands

Run from `C:\FPGA\systemverilog-fpga-cpu` in PowerShell after the Stage 11
RTL/testbench files have been added:

```powershell
$vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'

& $vivado -mode batch -source scripts/run_vector_stage11_depth6_xsim.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_depth8_xsim.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_equivalence_xsim.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_bench_xsim.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_depth8_bench_xsim.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_depth6_synth.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_depth8_synth.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_depth6_80mhz_impl.tcl
& $vivado -mode batch -source scripts/run_vector_stage11_depth8_80mhz_impl.tcl
```

Each script must use a disk-backed temporary project, target
`xc7a35tcpg236-1`, and print a unique completion marker. Do not commit
`.stage11_*`, `.Xil`, `.runs`, simulation databases, or checkpoints.
