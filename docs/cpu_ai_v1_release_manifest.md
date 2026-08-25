# CPU AI v1.0 release manifest

Status: release candidate (Stage 28). No commit or tag is created by this
manifest.

| Field | Value |
|---|---|
| Release | CPU AI v1.0 |
| Branch / source HEAD | `gpu-development` / `81a14ff6409f3d800a34f15e7578729162fafe41` |
| Board / FPGA | Digilent Basys 3 / `xc7a35tcpg236-1` |
| Tool / clock | Vivado 2026.1 / 80 MHz |
| UART | 115200 8-N-1 (discover the COM port; COM4 was used for evidence) |
| Canonical cores | `rtl/cpu_core_pipeline_timingopt.sv`; `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv` |
| Validation top | `rtl/basys3_ai_cpu_validation_top.sv` |
| Host / signoff | `tools/ai_cpu_host.py`; `scripts/run_ai_cpu_stage27c_signoff.ps1` |
| Build / program | `scripts/run_ai_cpu_bitstream_isolated.ps1`; `scripts/program_ai_cpu_isolated.ps1` |
| Bitstreams | `.ai_cpu_baseline/ai_cpu_baseline.bit`; `.ai_cpu_optimized/ai_cpu_optimized.bit` |

## Final implementation

Baseline: WNS +2.194 ns, WHS +0.038 ns, TNS/THS 0, 0 failing endpoints,
2087 LUT, 1890 FF, 1 RAMB18, 0 DSP.

Optimized: WNS +0.141 ns, WHS +0.058 ns, TNS/THS 0, 0 failing endpoints,
2992 LUT, 2199 FF, 1 RAMB18, 5 DSP.

## Physical Basys 3 evidence

| Workload | Baseline cycles | Optimized cycles | Speedup | Result |
|---|---:|---:|---:|---|
| DOT4 | 42 | 17 | 2.4706x | PASS |
| DOT64 | 73 | 32 | 2.2813x | PASS |
| MATVEC | 27 | 20 | 1.3500x | PASS |
| EDGE | 16 | 17 | 0.9412x | PASS; optimized slowdown |

All results matched independent golden references. Optimized stability was
100/100 jobs, with zero UART errors, timeouts, mismatches, or nondeterminism.

## SHA-256 artifact inventory

```text
66159a2d3df72d80b6ea497d8ba1a2dc47531c0e3637f69da82a0af725a06b7a  rtl/cpu_core_pipeline_timingopt.sv
40ec351532aecebcf3699bcba190b49246b2899bc69aa22ce9c2b7df3a6fb9ef  rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv
8ecc294f59d7499accb3faddcfd47e7d9c48c706e0def2e48c5cbbd1e62dc0f7  rtl/cpu_core_pipeline_timingopt_validation.sv
8afbfab14aadb39b1a0775811dc3aa4ca88b2beb8fb4c3b2f4b2522878e2464f  rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2_validation.sv
890b35d277f69d823b8bfebbf990f5363421f814307a6e7e056c22e3d477c1ee  rtl/ai_cpu_uart_controller.sv
3542a008e0e2da70bce89ebf2f6bac8f91ad5f54d40f697ae9e18ca48efd9e60  rtl/ai_cpu_validation_wrapper.sv
a97e2cd349413568b420b30a7b485b1e2b774029c99ce506fb19de32e0db1b00  rtl/basys3_ai_cpu_validation_top.sv
05ed3ea17b8d57b24fffbda273a8b43711eca1b7f04455da38f4414d10bbe5b6  programs/ai_dot4_70_baseline.mem
7e598f356f7d44d3f7b6d8fa1579b3e3f806897dac6a5c004eea2717204c285c  programs/ai_dot4_70_dot4acc.mem
b48ce88b77f60a0cd3139a0245f02f61f189416c51a5d13c158e2c77f960a699  programs/ai_dot64_baseline.mem
d4b96e2a4b7d05febf43cb93e0e78c2804285dfa92373f179b8a31e649faa4a5  programs/ai_dot64_dot4acc.mem
d8f31d0a9cbea8214f965cc4497908fc1bf46d05473a2090d084e3d6e264a22a  programs/ai_matvec_baseline.mem
8fa2f7071009bb640cf30772f1ad334abe987e79bc1e4107d3d1cafba0df9e37  programs/ai_matvec_dot4acc.mem
0a4ffff49512ff7f36b1e0445f817d6185fa1ff2d3c1010bc2619a54189f7e43  programs/ai_edge_baseline.mem
0a521cc0a428866095085d7823a30aaefab9ca7341a3daa8e4b5dfcd478a63ec  programs/ai_edge_dot4acc.mem
9a3f5b9f5f3a4774db1e7c9804e3f2179c706fcc1ce298ae5c2533fe6e303768  tools/ai_cpu_host.py
04628226cc18eba77af2c27331adbea019e24b2c082cd24dbc5bd3a4f8ce438d  scripts/run_ai_cpu_stage27c_signoff.ps1
c6cd26d15beaeb9d82420314cdd1e89da97889a9fdaee4d79d1c5dbe7ce6edbd  scripts/run_ai_cpu_bitstream_isolated.ps1
195ac6e50ba397419a8d4d6d230e73d4266baafd07ba2b5e0223e8c25e2d5a80  .ai_cpu_baseline/ai_cpu_baseline.bit
5c6cc3b968f22cfc8d020e5dcf777b185c29bfc2d0b679fc64fb3f92f5bfdc5f  .ai_cpu_optimized/ai_cpu_optimized.bit
```

Bitstreams are generated artifacts and remain excluded from Git; hashes above
identify the validated local files.

## Claim boundary

These results cover the tested kernels only. They do not establish universal
AI, GPU-class, NPU-class, or ML-inference acceleration.
