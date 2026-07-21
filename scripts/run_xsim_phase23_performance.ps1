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

function Invoke-XSimTest {
    param(
        [string]$Top,
        [string]$SnapshotPrefix,
        [string[]]$Sources
    )

    $snapshot = "{0}_{1}" -f $SnapshotPrefix, ([DateTimeOffset]::Now.ToUnixTimeSeconds())

    Write-Host ""
    Write-Host "Phase 23 XSim run"
    Write-Host "  Top:      $Top"
    Write-Host "  Snapshot: $snapshot"

    foreach ($src in $Sources) {
        & $xvlog -sv $src
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    & $xelab $Top -s $snapshot
    if ($LASTEXITCODE -ne 0) {
        $snapshotDir = Join-Path "xsim.dir" $snapshot
        if (-not (Test-Path $snapshotDir)) {
            exit $LASTEXITCODE
        }
        Write-Warning "xelab returned $LASTEXITCODE after snapshot creation. Continuing; this matches the known Windows object-directory cleanup warning."
    }

    & $xsim $snapshot -runall
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$commonSources = @(
    "rtl/cpu_defs_pkg.sv",
    "rtl/bram_instr_mem.sv",
    "rtl/bram_data_mem.sv",
    "rtl/cpu_core_pipeline_forwardtiming_phase23.sv"
)

Invoke-XSimTest `
    -Top "tb_phase23_forwardtiming_correctness" `
    -SnapshotPrefix "phase23_forwardtiming_correctness" `
    -Sources ($commonSources + @("tb/tb_phase23_forwardtiming_correctness.sv"))

Invoke-XSimTest `
    -Top "tb_phase23_final_benchmark" `
    -SnapshotPrefix "phase23_final_benchmark" `
    -Sources ($commonSources + @("tb/tb_phase23_final_benchmark.sv"))

Write-Host ""
Write-Host "Phase 23 XSim tests completed."
