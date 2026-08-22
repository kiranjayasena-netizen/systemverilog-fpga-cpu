# Basys 3 quick start

Use Vivado 2026.1 and target `xc7a35tcpg236-1`. Build the board top with:

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_final_gpu_synth.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_final_gpu_impl.tcl
```

The board top uses the 100 MHz Basys 3 clock and an MMCM-derived 80 MHz GPU
clock. LEDs indicate busy, done, clock lock, and heartbeat. UART pins are
Basys 3 A18 (RX) and B18 (TX). Physical board testing requires a connected
Basys 3 and is not performed in the automated session.

Program the generated bitstream with:

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/program_final_gpu_basys3.tcl
```

Then identify the actual COM port in Windows Device Manager and run:

```powershell
python tools/vector_gpu_host.py --port COMx --ping
python tools/vector_gpu_host.py --port COMx --status --repeat 10
```

Replace `COMx`; never assume a fixed port number.
