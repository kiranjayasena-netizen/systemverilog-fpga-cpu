# Hardware Evidence Checklist

This checklist tracks the physical Basys 3 evidence to capture for the final report or project book.

## Required Photos/Videos

| Evidence | Expected display or indicator | Status |
| --- | --- | --- |
| Phase 13 100 MHz MIPS mode | `0087` | observed; capture photo/video |
| Phase 17B CPI x100 mode | `0115` | observed; capture photo/video |
| Phase 17B control-flush x100 mode | `1250` | observed; capture photo/video |
| Phase 17E 115 MHz MIPS mode | `0100` | observed; capture photo/video |
| Phase 17E MMCM lock | LED0 on | capture photo/video |
| Phase 17E timing summary | WNS +0.008 ns, TNS 0.000 ns, WHS +0.035 ns, THS 0.000 ns | capture screenshot or selected report excerpt |
| Phase 18 aligned benchmark MIPS mode | `0093` | observed; capture photo/video |
| Phase 18 timing summary | WNS +0.014 ns, TNS 0.000 ns, WHS +0.036 ns, THS 0.000 ns | capture screenshot or selected report excerpt |
| Board programmed in Vivado Hardware Manager | DONE/startup high | capture screenshot or board photo |

## Optional Evidence

| Evidence | Purpose |
| --- | --- |
| Short video switching display modes | Shows `0100`, `0115` and `1250` on one board run |
| Photo of switch positions | Confirms SW0 run enable and SW3:SW1 display mode |
| Screenshot of programmed bitstream path | Connects board evidence to the Phase 17E bitstream |
| Phase 18 display mode video | Shows benchmark-aligned `0093` result and optional CPI/control modes |
| Screenshot of final GitHub commit or tag | Shows final repository state |
| Vivado RTL schematic screenshot | Useful for book diagrams |
| Performance table screenshot | Useful for presentation material |

## Notes

- These images are not required for synthesis or simulation, but they are important for the final report, presentation and book.
- Copy selected photos or screenshots into `docs/images/` only when they are intentionally chosen as final evidence.
- Do not commit large raw video files unless necessary.
- Do not commit raw Vivado implementation folders or bitstreams.
- The Phase 17E `0100` result is an integer MIPS display, so it should be described as approximately 100 MIPS.
- The Phase 18 `0093` result uses `programs/final_benchmark.mem`, so it should be described as the benchmark-aligned board result rather than a replacement for the Phase 17E headline result.
