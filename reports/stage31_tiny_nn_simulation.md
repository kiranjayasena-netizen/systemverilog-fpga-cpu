# Stage 31 Tiny NN Simulation

Golden reference: `tools/ai_tiny_nn_golden.py` (`AI_TINY_NN_GOLDEN_PASS`).

Stage 31 now uses an additive completion-mailbox mode in the validation
wrapper. Ordinary score stores commit without stopping execution; a final
mailbox store terminates the job. The four vectors pass in XSim.

| Test | Golden scores | Baseline | DOT4ACC | Status |
|---|---|---|---|---|
| 1 | 12, 15 (class 1) | 12, 15 | 12, 15 | PASS |
| 2 | 8, 7 (class 0) | 8, 7 | 8, 7 | PASS |
| 3 | 6, -3 (class 0) | 6, -3 | 6, -3 | PASS |
| 4 | 18, -7 (class 0) | 18, -7 | 18, -7 | PASS |

Cycles are baseline/optimized: 145/114, 146/115, 146/115, and 146/115.
These are simulation execution cycles, excluding preload and UART time.

Markers: `AI_TINY_NN_LAYER1_PASS`, `AI_TINY_NN_COMPLETION_PROTOCOL_PASS`,
`AI_TINY_NN_BASELINE_PASS`, `AI_TINY_NN_DOT4ACC_PASS`,
`AI_TINY_NN_EQUIVALENCE_PASS`, `AI_TINY_NN_END_TO_END_PASS`.

The failing run is reproducible with `scripts/run_ai_cpu_tiny_nn_xsim.tcl`.
