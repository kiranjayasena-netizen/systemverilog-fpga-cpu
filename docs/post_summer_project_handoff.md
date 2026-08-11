# Post-Summer-Project Handoff

## Immutable reference

`summer-project-final` is the immutable tag for the completed engineering
baseline. It points to consolidation commit `2731a78`, which contains the
final project summary, machine-readable results, and reproducibility guide.
Do not move, recreate, or force-update this tag.

The frozen CPU is:

- Functional architecture: H1.3b
- Physical implementation: `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Wrapper: `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Constraints: `constraints/basys3.xdc`
- Physical point: 93 MHz PASS 5/5 on `xc7a35tcpg236-1`

Authoritative navigation starts at:

- [`reports/final_project_results.md`](../reports/final_project_results.md)
- [`reports/final_project_results.csv`](../reports/final_project_results.csv)
- [`reports/final_cpu_architecture.md`](../reports/final_cpu_architecture.md)
- [`docs/reproducibility.md`](reproducibility.md)
- [`docs/thesis_extension_plan.md`](thesis_extension_plan.md)

## Future branching policy

Do not develop thesis work directly on the summer-project branch. After the
research question is approved, create a deliberate branch from the tag, for
example:

```text
summer-project-final -> thesis-development
```

or `feature/thesis-extension`. Do not create that branch automatically as
part of project closure.

Recommended workflow:

1. Checkout the immutable tag and create the thesis branch.
2. Record one research hypothesis before editing RTL.
3. Change one architectural idea at a time.
4. Simulate and prove golden correctness.
5. Measure cycles, instruction mix, and stalls.
6. Physically validate timing/resources using the same FPGA and flow.
7. Compare against `summer-project-final`, never against a moving baseline.

Future documentation commits may be added after the tag, but the tag itself
must continue to identify the frozen consolidation commit.

## Optional Basys 3 demonstration

A separate presentation wrapper could reset the CPU, run a fixed known
benchmark, compare the stored result with a golden value, and expose PASS,
FAIL, or completion on LEDs. This wrapper must remain separate from the frozen
CPU core and must not redefine cycle or timing evidence. It is a demonstration
artifact, not an architecture-validation result. No demo RTL is implemented
here.

## Scope closure

The summer-project development sequence ends at Stage L. There is no Stage M
in this repository milestone. Caches, DMA, scratchpads, wider DOT, activation
instructions, timing recovery, and scalar-overlap redesign belong only to an
approved future thesis branch.
