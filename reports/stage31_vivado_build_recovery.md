# Stage 31 Vivado Build Recovery

## Initial failure

The Stage 31 baseline project was created successfully, but the generated
project child run failed before synthesis completed.  With Vivado 2026.1
(`C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`), the failing launcher was:

`C:\FPGA\systemverilog-fpga-cpu\.stage31_build\baseline\ai_cpu_stage31_baseline.runs\synth_1\rundef.js`

The run log reported:

`rundef.js(122, 5) JavaScript runtime error: Access denied`

The parent `wait_on_run synth_1` remained active until the diagnostic command
timed out.  The same error had previously occurred in the repository-local
Stage 31 project tree.  No bitstream was produced by project mode.

## Investigation

The repository and a short `.stage31_build` directory passed create/read/
overwrite/rename/delete filesystem tests.  No stale Vivado process remained
after the failed run; no ACL or read-only attribute problem was found on the
workspace.  COM4 was present as `USB Serial Port (COM4)`.  No Defender or
Controlled Folder Access evidence was available, and system security settings
were not changed.  The OS-level cause is therefore **not conclusively
identified**.

## Recovery

Project mode was retried once from a fresh short path with `-jobs 1`; it
reproduced the same child `rundef.js` access-denied failure.  Further retries
were stopped.  The successful recovery uses direct non-project Vivado Tcl
flows, fresh output directories, absolute source paths, and the same isolated
Vivado user-data environment.  The direct flow runs `synth_design`,
`opt_design`, `place_design`, `phys_opt_design`, `route_design`, timing and
utilization reports, checkpoints, and `write_bitstream`.  It does not program
hardware.

## Stage 31 configuration

The Stage 31 top modules bind `STAGE31_COMPLETION=1` and select the respective
baseline or DOT4ACC validation CPU.  Completion remains at byte address 172
(word index 43), token value 1.

## Baseline

- Flow: `scripts/run_ai_cpu_stage31_baseline_direct.tcl`
- Output: `.stage31_build/baseline_direct/ai_cpu_stage31_baseline.bit`
- SHA-256: `03FE49924FC9218ED53F329C6032FD808CD9EFABF49466254B4AEB3D8F56B7D2`
- Post-route WNS: `+2.301 ns`
- Post-route WHS: `+0.034 ns`
- Setup/hold failing endpoints: `0 / 0`
- Bitstream size: `2,192,237` bytes

## Optimized

- Flow: `scripts/run_ai_cpu_stage31_optimized_direct.tcl`
- Output: `.stage31_build/optimized_direct/ai_cpu_stage31_optimized.bit`
- SHA-256: `F2A407373E70087B60C19ED2F0EAD9E17FF4FD9412A5086267AEBDC1FD2F7E98`
- Post-route WNS: `+0.181 ns`
- Post-route WHS: `+0.037 ns`
- Setup/hold failing endpoints: `0 / 0`
- Bitstream size: `2,192,238` bytes

Both are fresh Stage 31 completion-enabled bitstreams and are distinct from
the legacy Stage 27 artifacts.  They are not programmed or used for physical
measurements in this recovery stage.

## Conclusion

**CONFIRMED:** the generated project child-run launcher is unusable in this
local environment because it fails at `rundef.js` with Access denied, even
with a fresh short path and one job.  The exact OS-level permission/security
cause is **NOT CONCLUSIVELY IDENTIFIED**.  The direct non-project flow avoids
that launcher and produced timing-clean 80 MHz-target bitstreams.
