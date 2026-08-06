# MAC8 Fmax Sweep

## Scope And Method

Vivado 2026.1 synthesized, placed and routed the Phase 12 MAC8 design with:

- FPGA part: `xc7a35tcpg236-1`
- top module: `fpga_top_pipeline`
- instruction image: `programs/ai_dot_product_mac.mem`
- frequency grid: 95, 100, 102, 104, 106, 108 and 110 MHz
- implementation flow: `opt_design`, `place_design`, `route_design`, timing
  reports and bitstream generation

The controller first ran every frequency once. It then repeated the highest
passing point (100 MHz) and first failing point (102 MHz) until each had five
independent Vivado-process results. Vivado 2026.1 exposes no supported placer
seed for this non-project flow, so the repetition numbers are labels only;
`seed_applied=false` is recorded in the CSV. These repetitions test exact-flow
reproducibility and must not be described as a placement-seed distribution.

Run a new sweep with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_vivado_fmax_sweep_pipeline_mac.ps1
```

An interrupted sweep can reuse fully routed, error-free run records and
execute only missing frequency/repetition keys:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_vivado_fmax_sweep_pipeline_mac.ps1 -Resume
```

Generated checkpoints, bitstreams, logs and detailed timing reports remain
under the ignored `reports/ai_mac_fmax_sweep/runs/` tree. The consolidated,
tracked result is `reports/ai_mac_fmax_sweep/results.csv`.

## Results

Timing pass requires successful implementation and routing, non-negative
setup and hold WNS, and zero failing setup and hold endpoints.

| Target | Repetitions | Timing passes | Setup WNS | Hold WNS | Failing setup endpoints | Bitstreams |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 95 MHz | 1 | 1/1 | +0.121 ns | +0.058 ns | 0 | 1/1 passed |
| 100 MHz | 5 | 5/5 | +0.031 ns | +0.040 ns | 0 | 5/5 passed |
| 102 MHz | 5 | 0/5 | -0.074 ns | +0.057 ns | 36 | 5/5 passed |
| 104 MHz | 1 | 0/1 | -0.273 ns | +0.034 ns | 68 | 1/1 passed |
| 106 MHz | 1 | 0/1 | -0.389 ns | +0.033 ns | 126 | 1/1 passed |
| 108 MHz | 1 | 0/1 | -0.933 ns | +0.036 ns | 291 | 1/1 passed |
| 110 MHz | 1 | 0/1 | -0.644 ns | +0.056 ns | 158 | 1/1 passed |

All 15 designs routed fully, generated bitstreams and passed hold timing. The
tested setup boundary for this exact flow and frequency grid is therefore:

```text
100 MHz <= Fmax < 102 MHz
```

The 100 MHz route has an inferred critical period of 9.969 ns, or 100.311 MHz,
from `10.000 ns - 0.031 ns`. This agrees with the measured bracket but remains
a slack-derived estimate, not an independently tested operating frequency.

The 100 MHz worst setup path runs from data BRAM through writeback/frontend
control to the fetch-buffer instruction reset input. It is not the DSP path.
The design uses 1,454 LUTs, 1,507 FFs, one DSP and one BRAM tile at 100 MHz.

## Interpretation And Limits

The five repeated 100 MHz and 102 MHz runs were identical, confirming that
the current tool invocation is deterministic. They do not quantify variation
across supported placer seeds because no such control was available. The
non-monotonic slack above 102 MHz reflects different constraint-driven
implementation results, so the per-route slack estimates at those failing
points should not be treated as a monotonic Fmax curve.

The measured sweep closes the Phase 2 MAC8 frequency-characterization step.
Any packed INT8 extension should preserve the 100 MHz reference point and be
designed with retiming or explicit multi-cycle execution rather than adding a
larger combinational expression to the current execute stage.
