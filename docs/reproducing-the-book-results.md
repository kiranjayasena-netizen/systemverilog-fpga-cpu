# Reproducing the Book Results

## Authoritative Snapshot

| Item | Value |
| --- | --- |
| Release | `book-v1.0` |
| Commit | `d7a18dff029060ebdc1cd2616d327796523e75e3` |
| Vivado | 2026.1 |
| Simulator | Vivado XSim |
| Board | Digilent Basys 3 |
| FPGA | `xc7a35tcpg236-1` |
| Benchmark | `programs/final_benchmark.mem` |

Use the tagged release rather than a later `main` revision when reproducing
the printed edition.

## 1. Prepare the Tools

Install AMD Vivado 2026.1 with Artix-7 device support. Clone or download the
release, then open a Vivado-enabled PowerShell in the repository root.

The helper scripts locate Vivado from the active environment,
`VIVADO_BIN`, `XILINX_VIVADO`, or the documented default Windows locations.

## 2. Run Functional Verification

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

The script stops on a compilation, elaboration, simulation or self-checking
test failure. Preserve the console transcript with the date, commit and tool
version.

For the shared Phase 18 benchmark:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_phase18_final_benchmark.ps1
```

## 3. Build the Published Phase 20E Design

```powershell
vivado -mode batch -source scripts/run_vivado_impl_phase20_phase19a_119p0.tcl
```

Before accepting the bitstream, inspect the generated timing summary and
confirm:

- non-negative setup slack;
- satisfactory hold slack;
- no relevant unconstrained paths;
- the expected device and clock definitions;
- the expected utilisation and clocking resources.

Generated implementation directories and bitstreams are intentionally not
stored in Git.

## 4. Test on the Basys 3

Program the generated bitstream onto the Basys 3. Use the wrapper controls
documented in the relevant Phase 20 report and select MIPS display mode.

The retained Phase 20E physical result displayed `0104`, corresponding to
approximately 104 MIPS for the project workload at 119 MHz. This is a
workload-specific measurement, not a standard commercial CPU benchmark.

## 5. Preserve Evidence

Record:

- release tag and full commit hash;
- Vivado version and FPGA part;
- test transcript;
- timing, utilisation and power reports;
- generated bitstream checksum;
- benchmark image checksum;
- board photograph or video;
- selected clock and display mode;
- observed value.

Use `docs/hardware_evidence_checklist.md` for the full evidence checklist.

## Limitations

FPGA results can vary with tool version, implementation seed, device,
constraints and environmental conditions. Do not describe a derived frequency
as timing-clean unless implementation has passed at that constraint, and do
not describe a simulated or timing-derived throughput as physically measured.
