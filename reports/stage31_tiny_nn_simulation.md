# Stage 31 Tiny NN Simulation

Golden reference: `tools/ai_tiny_nn_golden.py` (`AI_TINY_NN_GOLDEN_PASS`).

The first frozen-CPU integration run reached DONE but produced zero output
stores for both generated images.  This is recorded as **INCOMPLETE** pending
program/pipeline integration debugging.  No CPU-AI speedup is reported.

| Test | Golden scores | Baseline | DOT4ACC | Status |
|---|---|---|---|---|
| 1 | 12, 15 (class 1) | 0, 0 | 0, 0 | blocked |
| 2 | 8, 7 (class 0) | 0, 0 | 0, 0 | blocked |
| 3 | 6, -3 (class 0) | 0, 0 | 0, 0 | blocked |
| 4 | 18, -7 (class 0) | 0, 0 | 0, 0 | blocked |

The failing run is reproducible with `scripts/run_ai_cpu_tiny_nn_xsim.tcl`.
