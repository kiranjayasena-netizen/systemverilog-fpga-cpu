# Stage 27C validation adaptation

Stage 27C creates validation-specific derivatives without changing either
canonical CPU.  The derivatives preserve the pipeline and BRAM timing and
only add explicit host memory ports, completion visibility, and exposure of
the existing cycle counter. The board tops use an 80 MHz MMCM-derived clock
from the Basys 3 100 MHz oscillator. An initial 93.75 MHz harness experiment
was not timing-clean for the optimized derivative because of the added
validation mux boundary; the conservative common rate is used here without
changing either canonical CPU.

Vivado scripts:

```powershell
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_ai_cpu_optimized_bitstream.tcl
& "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -source scripts/run_ai_cpu_baseline_bitstream.tcl
```

The current environment completed baseline synthesis with zero errors. Full
implementation and physical Basys 3 testing require the local hardware flow;
no physical result is claimed by this adaptation.

## Current status

**Stage 27C: PARTIAL — validation infrastructure implemented; mandatory
equivalence and paired verification still pending.**

The canonical baseline and DOT4ACC cores remain unchanged. The validation
path is:

```text
Host PC -> UART controller -> validation wrapper
        -> instruction/data preload and safe readback
        -> baseline or DOT4ACC validation derivative
```

Validation writes are accepted only while `load_mode` is asserted; the
wrapper holds the selected CPU in reset during that phase. During execution
the CPU exclusively owns the original synchronous memory path. Completion is
latched from the existing retiring-store condition, and the existing
`total_cycles` counter is exposed without including UART traffic.

The first 93.75 MHz harness experiment demonstrated that the added
validation boundary is not timing-clean for the optimized derivative
(setup WNS `-0.451 ns`). The harness therefore uses a common 80 MHz MMCM
clock. The optimized 80 MHz routed experiment produced setup WNS
`+0.443 ns`, hold WHS `+0.016 ns`, and zero failing endpoints. These are
validation-top measurements, not claims about the canonical core's historical
93 MHz implementation.

Required follow-up before Stage 27C can become PASS:

1. run frozen-versus-validation architectural equivalence for both cores;
2. run the UART/controller and complete wrapper simulations;
3. rebuild both paired 80 MHz bitstreams and archive compact reports;
4. program the Basys 3 locally and measure identical workloads through the
   common protocol.

Physical AI-performance results and hardware speedup are not established by
this stage.

## Verification update (2026-08-25)

The canonical/validation side-by-side simulations now pass for both cores.
The exact `programs/dot4acc_stage_d.mem` optimized workload completes in 18
cycles in both instances, with markers
`AI_CPU_BASELINE_EQUIVALENCE_PASS`, `AI_CPU_OPTIMIZED_EQUIVALENCE_PASS`, and
`AI_CPU_DOT64_CYCLE_EQUIVALENCE_PASS`. The earlier DOT retirement metadata
assertion failure was caused by a noncanonical optimized validation derivative;
it was regenerated from the frozen canonical source with validation-only ports.

The UART controller test now uses real 80 MHz / 115200-baud timing and covers
PING, RESET, WRITE_INSTR, WRITE_DATA, READ_DATA, START, STATUS, READ_CYCLES,
and invalid-opcode handling. It passes with `AI_CPU_UART_PROTOCOL_PASS`.

Both validation bitstreams were rebuilt after the RTL correction. Baseline
routed timing is WNS +1.901 ns / WHS +0.091 ns; optimized timing is WNS
+0.265 ns / WHS +0.016 ns. Both have zero failing endpoints and valid
bitstreams.

The wrapper test remains a preload smoke test. Full DOT4/DOT64/matrix-vector/
edge workload execution through UART and reset/restart simulation are still
outstanding, so Stage 27C remains PARTIAL. Physical Basys 3 testing and any
hardware speedup claim remain NOT RUN.

The workload-level wrapper E2E bench is now present as
`tb/ai_cpu_validation_e2e_tb.sv` with runner
`scripts/run_ai_cpu_validation_e2e_xsim.tcl`. It exercises host program/data
writes, clean load-mode release, execution, DONE, cycle readback, and a
second run for both derivatives. It currently exposes a workload asset
mismatch: baseline returns `0xfffffff2`, while the optimized
`ai_dot_product_dot4acc.mem` path returns `0x00000000`. The canonical
optimized `programs/dot4acc_stage_d.mem` equivalence remains PASS, so this is
not evidence against the frozen core.

The controller idle `READ_DATA` path was corrected to re-enter validation load
mode before synchronous host readback. This is synthesizable validation RTL;
paired bitstreams require rebuilding after the workload/program issue is
resolved.

DOT4 integration closure: the original optimized image loaded operands from
CPU byte addresses 64 and 68 (validation memory word indices 16 and 17), but
the E2E preload initialized unrelated locations. The original scalar image
also computed the documented `-14` example rather than `[1,2,3,4]·[5,6,7,8]`.
New source-of-truth images `programs/ai_dot4_70_baseline.mem` and
`programs/ai_dot4_70_dot4acc.mem` implement the same 70-result workload.
The E2E simulation now passes: baseline `0x46` (41 cycles), optimized
`0x46` (16 cycles), independent golden result 70, and reset/restart PASS.

DOT64 baseline-comparable, matrix-vector, and signed/edge workload assets are
not yet present in the repository, so those required E2E gates remain open.

The DOT64 E2E pair is now present and exercised by the reusable bench:
`programs/ai_dot64_baseline.mem` and `programs/ai_dot64_dot4acc.mem`. Both use
64 identical signed-INT8 one values, with packed operands initialized at word
indices 16/17 and result address 0. Results are 64/64 against the independent
golden model; baseline execution is 72 cycles and optimized execution is 31
cycles. These are simulation cycle ratios only, not physical speedup.

The historical matrix-vector workload remains embedded in
`tb/tb_dot4acc_stage_h13b_timingopt_t2_benchmark.sv`; no validated host-loadable
baseline/optimized images or E2E result table have been completed yet.

The Stage 27C completion gates remain open: the side-by-side equivalence
bench is currently a structural smoke harness rather than a completed
architectural comparison, and the UART/wrapper testbenches have not been run
to completion in this environment. The optimized 80 MHz implementation result
above remains valid from the completed run; a paired baseline 80 MHz signoff
must be regenerated locally before Stage 27D.

The validation UART and wrapper smoke simulations now elaborate and run under
XSim (`AI_CPU_UART_XSIM_COMPLETE` and
`AI_CPU_VALIDATION_WRAPPER_XSIM_COMPLETE`). These are smoke checks only: the
controller bench currently exercises PING and the wrapper bench exercises the
host preload path. They are not full DOT4/DOT64/matrix-vector end-to-end
signoff.

The low address-bit warnings in the validation BRAMs are intentional. CPU
addresses are byte addresses and the memory models select aligned 32-bit words
(`addr[ADDR_BITS+1:2]`), so `addr[1:0]` are alignment bits rather than missing
memory address bits. This preserves the canonical word-address behavior.

The first real side-by-side baseline equivalence run passed. The analogous
optimized run currently fails in the validation derivative's DOT4ACC
retirement assertion (`DOT retirement metadata misaligned`). The assertion
remains enabled; Stage 27C is therefore not signed off and Stage 27D physical
testing remains blocked.

Debug closure: the validation optimized file was not structurally derived
from the frozen optimized core; it contained unrelated deferred-load and
lookahead pipeline logic. It was replaced with an exact canonical copy and
only the validation memory ports, load-mode path, and completion latch were
reapplied. The equivalence test also initializes both data memories identically
before execution. The optimized side-by-side run now passes with matched
completion at 18 cycles for the exercised `dot4acc_stage_d.mem` workload.

Final workload closure: DOT4 70/70 (41/16 cycles), DOT64 64/64 (72/31), the
2-row matrix-vector workload `0x00000278,0xffff_ff11`/same (26/19), and the
signed edge workload 1/1 (15/16). Completion, cycle-counter, and cross-workload
reset/restart markers pass; the E2E bench was run three times with stable
DOT4/DOT64 counts. The fail-closed script emitted
`AI_CPU_STAGE27C_SIGNOFF_PASS`. Physical FPGA testing and speedup claims are
not made. A fresh paired Vivado rebuild is blocked by the local
`tclapp::load_apps` project-write error (`Could not open 'C' for writing`).
## Final 80 MHz implementation closure

Vivado 2026.1 project creation failed under the existing user TclStore with
`tclapp::load_apps` followed by `Could not open 'C' for writing`. A minimal
`create_project` reproduced the failure. Running Vivado with an isolated,
writable per-build APPDATA/USERPROFILE (via
`scripts/run_ai_cpu_bitstream_isolated.ps1`) passed project creation and both
full builds. No CPU or GPU RTL was changed for this environment fix.

Historical pre-final-rebuild reference: baseline 80 MHz, WNS +1.956 ns, WHS +0.093 ns, TNS/THS 0,
zero failing endpoints, 2077 LUT, 1883 FF, 0.5 BRAM tile (1 RAMB18), 0 DSP.
Bitstream: `.ai_cpu_baseline/ai_cpu_baseline.bit`.

Historical pre-final-rebuild reference: optimized 80 MHz, WNS +0.443 ns, WHS +0.117 ns, TNS/THS 0,
zero failing endpoints, 2953 LUT, 2192 FF, 0.5 BRAM tile (1 RAMB18), 5 DSP.
Bitstream: `.ai_cpu_optimized/ai_cpu_optimized.bit`.

Physical Basys 3 testing was subsequently run as Stage 27D; see the physical
validation report. The final UART-fix rebuilds were timing-clean: baseline
WNS/WHS +2.194/+0.038 ns (2087 LUT, 1890 FF, 1 RAMB18, 0 DSP) and optimized
+0.141/+0.058 ns (2992 LUT, 2199 FF, 1 RAMB18, 5 DSP). Stage 27C simulation
ratios remain separate from measured hardware results.
