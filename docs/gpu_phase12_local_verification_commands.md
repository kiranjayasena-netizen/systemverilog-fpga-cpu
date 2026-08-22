# Stage 12 local Vivado commands

Run from `C:\FPGA\systemverilog-fpga-cpu`:

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage12_xsim.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage11_depth6_xsim.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage10b_direct_xsim.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage10a_direct_xsim.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage11_stage12_equivalence_xsim.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage12_bench_xsim.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage12_synth.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_vector_stage12_80mhz_impl.tcl
```

Compact reports are written under `reports/vector_stage12/`. Temporary
projects and simulator/implementation directories are ignored and should
not be committed.
