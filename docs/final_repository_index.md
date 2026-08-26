# Final repository index

## Canonical release RTL

- CPU baseline: `rtl/cpu_core_pipeline_timingopt.sv`
- CPU AI optimized: `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- CPU AI validation top: `rtl/basys3_ai_cpu_validation_top.sv`
- GPU core: `rtl/vector_load_overlap_program_core.sv`
- GPU board top: `rtl/basys3_vector_gpu_top.sv`

## Validation and benchmarks

- Validation RTL: `rtl/*_validation.sv`, `rtl/ai_cpu_validation_wrapper.sv`
- Programs: `programs/AI_BENCHMARKS.md` and `programs/*.mem`
- Testbenches: `tb/`
- Host tools: `tools/ai_cpu_host.py`, `tools/vector_gpu_host.py`

## Build and reports

- CPU-AI signoff: `scripts/run_ai_cpu_stage27c_signoff.ps1`
- Isolated Vivado builds: `scripts/run_ai_cpu_bitstream_isolated.ps1`
- Final reports: `reports/final_cpu/`, `reports/final_gpu/`
- Release documents: `docs/cpu_ai_v1_release_manifest.md`,
  `docs/cpu_ai_v1_reproduction.md`, and `docs/final_project_summary.md`

## Historical evidence

Other CPU/GPU RTL variants, stage reports, timing sweeps, and experiments are
retained as historical engineering evidence; they are not alternate v1.0
canonical implementations.

## Published releases

- [book-v1.0](https://github.com/kiranjayasena-netizen/systemverilog-fpga-cpu/releases/tag/book-v1.0)
- [gpu-v1.0](https://github.com/kiranjayasena-netizen/systemverilog-fpga-cpu/releases/tag/gpu-v1.0)
- [cpu-ai-v1.0](https://github.com/kiranjayasena-netizen/systemverilog-fpga-cpu/releases/tag/cpu-ai-v1.0)
