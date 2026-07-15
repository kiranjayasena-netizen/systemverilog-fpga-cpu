param(
    [string]$VivadoBat = "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat",
    [string[]]$Only = @()
)

$ErrorActionPreference = "Stop"

$cpus = @(
    @{ Select = 0; Name = "phase08_multicycle" },
    @{ Select = 1; Name = "phase10h_bram_multicycle" },
    @{ Select = 2; Name = "phase11e_ctrlopt_prefetch" },
    @{ Select = 3; Name = "phase12_pipeline" },
    @{ Select = 4; Name = "phase13e_13i_forwardtiming" },
    @{ Select = 5; Name = "phase14g_pipeline6" }
)

if ($Only.Count -gt 0) {
    $cpus = $cpus | Where-Object { $Only -contains $_.Name }
}

if (-not (Test-Path $VivadoBat)) {
    throw "Vivado executable not found: $VivadoBat"
}

foreach ($cpu in $cpus) {
    Write-Host ""
    Write-Host "=== Building $($cpu.Name) MIPS-counter bitstream (CPU_SELECT=$($cpu.Select)) ==="
    $env:CPU_MIPS_SELECT = [string]$cpu.Select
    $env:CPU_MIPS_NAME = [string]$cpu.Name
    & $VivadoBat -mode batch -source scripts/run_vivado_impl_cpu_mips_compare.tcl
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado failed for $($cpu.Name) with exit code $LASTEXITCODE"
    }
}

Remove-Item Env:\CPU_MIPS_SELECT -ErrorAction SilentlyContinue
Remove-Item Env:\CPU_MIPS_NAME -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Phase 16C MIPS-counter bitstream build complete."
Write-Host "Outputs: reports/phase16c_cpu_mips_compare_impl/<cpu>/bitstreams/"
