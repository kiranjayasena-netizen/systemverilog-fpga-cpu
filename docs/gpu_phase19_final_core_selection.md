# Stage 19 — Final GPU core selection

The production core is **Stage 14**, `vector_load_overlap_program_core`.

| Core | Array cycles | LUT | FF | RAMB36 | Setup WNS | Decision |
|---|---:|---:|---:|---:|---:|---|
| Stage 10B | 21 | 3109 | 1446 | 2 | +0.186 ns | historical |
| Stage 11 depth 6 | 21 | 3177 | 1450 | 2 | +0.001 ns | historical |
| Stage 12 | 21 | 3247 | 1522 | 2 | +0.348 ns | historical |
| Stage 14 | **20** | 3277 | 1522 | 2 | +0.221 ns | **selected** |

Stage 14 is the fastest verified core, adds only 30 post-route LUTs over
Stage 12, retains two RAMB36 and zero DSP, passes all historical regressions,
and closes 80 MHz. Stage 15 forwarding was rejected because the remaining
cases are blocked by the single RF write port. No Stage 16/17 RTL is carried
into production.
