# CPU AI v1.0 reproduction guide

Environment: Windows, Vivado 2026.1, Python 3 with `pyserial`, Digilent Basys
3 (`xc7a35tcpg236-1`), 80 MHz validation clock, UART 115200 8-N-1.
Discover the serial port rather than assuming COM4.

## Simulation signoff

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_ai_cpu_stage27c_signoff.ps1
```

The expected marker is `AI_CPU_STAGE27C_SIGNOFF_PASS`. Simulation references
are DOT4 41/16, DOT64 72/31, MATVEC 26/19, and EDGE 15/16 cycles; these are not
hardware measurements.

## Isolated Vivado builds

The isolated wrapper avoids the local per-user TclStore project-creation
failure by providing fresh writable Vivado user-data and temporary paths:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_ai_cpu_bitstream_isolated.ps1 -Variant baseline
powershell -ExecutionPolicy Bypass -File scripts/run_ai_cpu_bitstream_isolated.ps1 -Variant optimized
```

The outputs are `.ai_cpu_baseline/ai_cpu_baseline.bit` and
`.ai_cpu_optimized/ai_cpu_optimized.bit`.

## Programming and host checks

```powershell
powershell -ExecutionPolicy Bypass -File scripts/program_ai_cpu_isolated.ps1 -Variant optimized
python tools/ai_cpu_host.py --port COM4 --ping
python tools/ai_cpu_host.py --port COM4 --status
python tools/ai_cpu_host.py --port COM4 --reset
```

Use the same programming command with `-Variant baseline` for the baseline
image. Replace COM4 with the discovered port. The host utility supports
`--write-instr ADDR WORD`, `--write-data ADDR HEXWORD`, `--start`,
`--read-data ADDR`, and `--read-cycles`; workload images and golden values are
listed in `programs/AI_BENCHMARKS.md`.

Physical execution time is `READ_CYCLES / 80,000,000`; UART transfer and host
polling time are excluded.
