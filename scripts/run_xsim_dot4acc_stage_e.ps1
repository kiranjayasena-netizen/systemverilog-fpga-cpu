# Run the focused Stage E same-clock architectural benchmark suite.
# The testbench regenerates reports/dot4acc_stage_e/results.csv.

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Resolve-VivadoTool {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ToolName
    )

    $toolCommand = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($null -ne $toolCommand) {
        return $toolCommand.Source
    }

    $candidateRoots = @()
    if ($env:VIVADO_BIN) {
        $candidateRoots += $env:VIVADO_BIN
    }
    if ($env:XILINX_VIVADO) {
        $candidateRoots += (Join-Path $env:XILINX_VIVADO "bin")
    }
    $candidateRoots += "C:\AMDDesignTools\2026.1\Vivado\bin"
    $candidateRoots += "C:\Xilinx\Vivado\2026.1\bin"

    foreach ($root in $candidateRoots) {
        foreach ($extension in @(".bat", ".exe")) {
            $candidate = Join-Path $root "$ToolName$extension"
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }
    throw "Could not find $ToolName. Open a Vivado-enabled PowerShell or set VIVADO_BIN."
}

$Xvlog = Resolve-VivadoTool "xvlog"
$Xelab = Resolve-VivadoTool "xelab"
$Xsim = Resolve-VivadoTool "xsim"
$Snapshot = "tb_dot4acc_stage_e_benchmark_sim"
$Sources = @(
    "rtl/cpu_defs_pkg.sv",
    "tb/dot4acc_reference_pkg.sv",
    "rtl/bram_instr_mem.sv",
    "rtl/bram_data_mem.sv",
    "rtl/dot4acc_pipeline.sv",
    "rtl/cpu_core_pipeline_mac8_timingopt.sv",
    "rtl/cpu_core_pipeline_dot4acc_wb.sv",
    "tb/tb_dot4acc_stage_e_benchmark.sv"
)

& $Xvlog -sv $Sources
if ($LASTEXITCODE -ne 0) {
    throw "Stage E xvlog failed with exit code $LASTEXITCODE"
}

& $Xelab tb_dot4acc_stage_e_benchmark -s $Snapshot
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Stage E xelab returned $LASTEXITCODE; attempting XSim if the snapshot exists."
}

$xsimOutput = & $Xsim $Snapshot -runall 2>&1
$xsimOutput | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    throw "Stage E XSim failed with exit code $LASTEXITCODE"
}

$xsimText = $xsimOutput -join "`n"
if ($xsimText -notmatch "TEST PASSED: Stage E DOT4ACC performance benchmarking") {
    throw "Stage E transcript did not contain the expected pass marker"
}
if ($xsimText -match "FATAL_ERROR|TEST FAILED|failures: [1-9]") {
    throw "Stage E transcript contains a failure"
}
if (-not (Test-Path "reports/dot4acc_stage_e/results.csv")) {
    throw "Stage E results CSV was not generated"
}

$rows = Import-Csv "reports/dot4acc_stage_e/results.csv"
if ($rows.Count -eq 0 -or ($rows | Where-Object { $_.pass_fail -ne "PASS" })) {
    throw "Stage E CSV is empty or contains a failing row"
}

Write-Host "Stage E benchmark passed and generated $($rows.Count) result rows."
