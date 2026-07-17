param(
    [string]$VivadoBin = "C:\AMDDesignTools\2026.1\Vivado\bin"
)

$ErrorActionPreference = "Stop"

$xvlog = Join-Path $VivadoBin "xvlog.bat"
$xelab = Join-Path $VivadoBin "xelab.bat"
$xsim  = Join-Path $VivadoBin "xsim.bat"

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path $tool)) {
        throw "Vivado simulator tool not found: $tool"
    }
}

$snapshot = "phase18_final_benchmark_aligned_{0}" -f ([DateTimeOffset]::Now.ToUnixTimeSeconds())

Write-Host "Phase 18 final benchmark XSim run"
Write-Host "  Snapshot: $snapshot"

& $xvlog -sv rtl/cpu_defs_pkg.sv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $xvlog -sv rtl/bram_instr_mem.sv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $xvlog -sv rtl/bram_data_mem.sv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $xvlog -sv rtl/cpu_core_pipeline_forwardtiming.sv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $xvlog -sv tb/tb_phase18_final_benchmark_forwardtiming.sv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $xelab tb_phase18_final_benchmark_forwardtiming -s $snapshot
if ($LASTEXITCODE -ne 0) {
    $snapshotDir = Join-Path "xsim.dir" $snapshot
    if (-not (Test-Path $snapshotDir)) {
        exit $LASTEXITCODE
    }
    Write-Warning "xelab returned $LASTEXITCODE after snapshot creation. Continuing; this matches the known Windows object-directory cleanup warning."
}

& $xsim $snapshot -runall
exit $LASTEXITCODE
