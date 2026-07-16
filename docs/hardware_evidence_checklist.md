# Hardware Evidence Checklist

This checklist tracks the physical Basys 3 evidence that should be captured for the final project write-up.

## Phase 13 / Phase 17 Baseline

| Evidence | Expected display or indicator | Status |
| --- | --- | --- |
| Phase 13 100 MHz MIPS mode | `0087` | observed; capture photo/video |
| Phase 17B CPI x100 mode | `0115` | observed; capture photo/video |
| Phase 17B control-flush x100 mode | `1250` | observed; capture photo/video |

## Phase 17E 115 MHz MMCM Test

| Evidence | Expected display or indicator | Status |
| --- | --- | --- |
| MMCM lock | LED0 on | capture photo/video |
| Phase 17E MIPS mode | `0100` | observed; capture photo/video |
| Phase 17E CPI x100 mode | `0115` | observed; capture photo/video |
| Phase 17E control-flush x100 mode | `1250` | observed; capture photo/video |

## Vivado Evidence

| Evidence | Source |
| --- | --- |
| Phase 17E timing summary | `reports/phase17e_mmcm_mips_impl/` local generated reports |
| Phase 17E bitstream programming | Vivado Hardware Manager screenshot |
| DONE/startup status | Vivado Hardware Manager screenshot or board photo |

## Notes

- Do not commit raw Vivado implementation folders or bitstreams.
- Keep selected screenshots or photos under `docs/images/` only if they are intentionally chosen as final evidence.
- The Phase 17E `0100` result is an integer MIPS display, so it should be described as approximately 100 MIPS.
