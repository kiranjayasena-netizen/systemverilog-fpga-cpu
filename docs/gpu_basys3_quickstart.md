# Basys 3 quick start

Use Vivado 2026.1 and target `xc7a35tcpg236-1`. Build the board top with:

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_final_gpu_synth.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_final_gpu_impl.tcl
```

The board top uses the 100 MHz Basys 3 clock and an MMCM-derived 80 MHz GPU
clock. LEDs indicate busy, done, clock lock, and heartbeat. For the Basys 3
USB-UART bridge, FPGA pin B18 is `uart_rx` and A18 is `uart_tx`.

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

The validated local setup used COM4, 115200 baud, 8 data bits, no parity,
and one stop bit. The UART receiver validates the start bit midpoint and the
stop bit before raising its one-cycle `valid` pulse. After programming, a
basic acceptance check is:

```powershell
python tools/vector_gpu_host.py --port COM4 --ping
python tools/vector_gpu_host.py --port COM4 --status --repeat 10
python tools/vector_gpu_host.py --port COM4 --write-memory 15 112233445566778899aabbccddeeff00
python tools/vector_gpu_host.py --port COM4 --read-memory 15
python tools/vector_gpu_host.py --port COM4 --demo array_add
python tools/vector_gpu_host.py --port COM4 --run-all-demos --repeat 25
```
