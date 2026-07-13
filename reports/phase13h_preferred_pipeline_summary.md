# Phase 13H Preferred Pipeline Summary

## Purpose

Phase 13H consolidates the Phase 13 optimisation study, reruns the full XSim regression, performs a final timing sweep on the preferred Phase 13E forwarding-timing pipeline, and records the final measured implementation status.

No new CPU architecture was created in Phase 13H. Phase 13E remains the preferred implementation unless a tighter verified timing result is found for the same Phase 13E top.

## Preferred Implementation

| Item | Value |
| --- | --- |
| Preferred CPU | Phase 13E forwarding-timing pipeline |
| RTL core | `rtl/cpu_core_pipeline_forwardtiming.sv` |
| FPGA top | `rtl/fpga_top_pipeline_forwardtiming.sv` |
| Target board | Digilent Basys 3 |
| FPGA part | `xc7a35tcpg236-1` |
| Instruction/data memory style | Synchronous BRAM |
| Aggregate cycles | 427 |
| Retired instructions | 319 |
| Aggregate CPI | 1.339 |
| Final verified period | 8.850 ns |
| Final verified Fmax | 112.994 MHz |
| Practical estimated MIPS | ~84.4 |
| 90 MIPS target | Not reached |

Practical estimated throughput is calculated as:

```text
112.994 MHz / (427 / 319) = 84.4 MIPS
```

The 90 MIPS target would require about 120.5 MHz at the current measured CPI, or a lower CPI at the same verified Fmax.

## Final Regression

The full local Vivado XSim regression was rerun after Phase 13G was added.

| Item | Result |
| --- | --- |
| Command | `powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1` |
| Final transcript | `reports/simulation_transcripts/phase13h_xsim_regression_final_20260713_124649.txt` |
| Result | Passed |
| Notes | Phase 13G initially hit a Vivado/XSim snapshot cleanup/kernel issue with the previous generated snapshot name. A shorter Phase 13G snapshot name was used in the regression script; the full regression then completed with exit code 0. |

The final transcript includes:

- `Phase 13E forwardtiming PIPELINE TEST PASSED`
- `Phase 13F targetbuf PIPELINE TEST PASSED`
- `Phase 13G targetbuf_reg PIPELINE TEST PASSED`
- `All XSim regression tests completed.`

## Timing Sweep

The final sweep was run only on the Phase 13E top. Raw generated Vivado reports remain local under `reports/phase13e_timing/` and should not be committed as generated implementation output.

| Period | Requested frequency | WNS | TNS | WHS | THS | Bitstream | Status |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 9.100 ns | 109.890 MHz | +0.166 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed | Passing prior Phase 13C/13E evidence |
| 8.900 ns | 112.360 MHz | +0.059 ns | 0.000 ns | +0.040 ns | 0.000 ns | Passed | Passing prior Phase 13E evidence |
| 8.850 ns | 112.994 MHz | +0.126 ns | 0.000 ns | +0.034 ns | 0.000 ns | Passed | Final accepted Phase 13H result |
| 8.800 ns | 113.636 MHz | -0.026 ns | -0.161 ns | +0.039 ns | 0.000 ns | Generated, but timing failed | Rejected |
| 8.750 ns | 114.286 MHz | Not run | Not run | Not run | Not run | Not run | Skipped because 8.800 ns failed |
| 8.700 ns | 114.943 MHz | Not run | Not run | Not run | Not run | Not run | Skipped because 8.800 ns failed |

The tightest verified passing period from this sweep is therefore 8.850 ns.

## Resource Usage

Final accepted Phase 13E result at 8.850 ns:

| Resource | Used | Device total | Utilisation |
| --- | ---: | ---: | ---: |
| LUTs | 1,383 | 20,800 | 6.65% |
| FFs | 1,513 | 41,600 | 3.64% |
| Block RAM Tile | 1 | 50 | 2.00% |
| RAMB18 | 2 | 100 | 2.00% |
| DSP | 0 | 90 | 0.00% |
| Total on-chip power | 0.092 W | - | Medium confidence |

BRAM inference is retained: one Block RAM Tile, implemented as two RAMB18 blocks.

## Critical Path

At 8.850 ns, the worst setup path is still in the forwarding/operand-control family:

| Item | Value |
| --- | --- |
| Slack | +0.126 ns |
| Source | `cpu_inst/mem_wb_reg_reg[rd][3]/C` |
| Destination | `cpu_inst/id_ex_reg_reg[operand_b][31]/CE` |
| Data path delay | 8.439 ns |
| Logic delay | 2.252 ns, 26.685% |
| Route delay | 6.187 ns, 73.315% |
| Logic levels | 9 |

This confirms that Phase 13E improved timing without changing the aggregate CPI, but the remaining limit is still a route-heavy writeback/operand-control path rather than instruction fetch.

## Phase Comparison

| Phase | Main idea | Cycles | Retired | CPI | Verified Fmax | Practical MIPS | Timing/resource status | Decision |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Phase 12 | First full pipelined CPU | 457 | 319 | 1.433 | ~101.9 MHz | ~71.1 | 100 MHz passed | Superseded |
| Phase 13A | Fast JUMP target request | 427 | 319 | 1.339 | ~101.9 MHz | ~76.1 | 100 MHz passed | Superseded |
| Phase 13C | Timing-optimised frontend/register cleanup | 427 | 319 | 1.339 | 109.890 MHz | ~82.1 | 9.100 ns passed | Superseded |
| Phase 13D | Remove decode-time WB-to-ID bypass | 434 | 319 | 1.361 | 109.890 MHz | ~80.7 | 9.100 ns passed | Rejected: CPI penalty |
| Phase 13E | Restructure forwarding path without CPI penalty | 427 | 319 | 1.339 | 112.994 MHz | ~84.4 | 8.850 ns passed | Preferred |
| Phase 13F | Same-cycle target buffer | 401 | 319 | 1.257 | Not timing-clean at 8.900 ns | Not accepted | WNS -2.002 ns, TNS -13.822 ns at 8.900 ns | Rejected: timing failure |
| Phase 13G | Registered target buffer | 427 | 319 | 1.339 | 112.360 MHz | ~83.9 | 8.900 ns passed, higher resources | Rejected: no performance gain |

## Why Phase 13E Is Preferred

Phase 13E is preferred because it is the best verified practical implementation:

- it preserves the aggregate CPI of the Phase 13A/13C pipeline;
- it keeps the full custom-ISA regression passing;
- it retains synchronous instruction and data BRAM inference;
- it improves verified post-route Fmax to 112.994 MHz;
- it improves practical estimated throughput to about 84.4 MIPS;
- it avoids the timing failure seen in Phase 13F;
- it avoids the CPI penalty seen in Phase 13D;
- it avoids the extra resource cost without performance gain seen in Phase 13G.

Phase 13E still does not reach 90 MIPS, so it should be described as the current strongest measured result, not as a completed 90 MIPS target.

## Rejected Experiments

Phase 13D was rejected because it removed useful decode-time WB-to-ID bypass behaviour and introduced extra stalls. It remained functionally correct, but CPI worsened from 1.339 to 1.361 without a compensating Fmax increase.

Phase 13F was rejected because the same-cycle target-buffer hit/instruction injection path improved CPI but failed post-route timing badly at 8.900 ns.

Phase 13G was rejected because registering the target-buffer lookup restored timing, but removed the CPI benefit and increased resource usage relative to Phase 13E.

## Remaining Gap To 90 MIPS

Current result:

```text
112.994 MHz / 1.339 CPI = 84.4 MIPS
```

Remaining gap:

```text
90.0 - 84.4 = about 5.6 MIPS
```

At the current CPI, reaching 90 MIPS requires about 120.5 MHz. Alternatively, at 112.994 MHz, CPI would need to improve to about 1.255.

## Recommended Future Work

Recommended next work:

1. Keep Phase 13E as the preferred measured FPGA implementation path.
2. Avoid reintroducing same-cycle target-buffer injection unless the timing path is redesigned from the start.
3. Investigate smaller timing improvements around the writeback/operand-control path, especially route-heavy control-enable paths into ID/EX.
4. Consider a carefully measured CPI improvement only if it does not add a new long frontend/control path.
5. When the Basys 3 board is available, run physical hardware bring-up using the preferred timing-clean bitstream and record real board evidence.

## Conclusion

Phase 13H confirms that Phase 13E is the preferred measured pipeline implementation. The final accepted sweep result is 8.850 ns, equivalent to 112.994 MHz, with CPI 1.339 and practical estimated throughput of about 84.4 MIPS.

The 90 MIPS target was not reached, but Phase 13E is a strong timing-clean result and the best current implementation for supervisor reporting.
