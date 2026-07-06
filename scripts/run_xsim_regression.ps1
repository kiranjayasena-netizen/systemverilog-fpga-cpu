# Run all current Vivado XSim testbenches from the repository root.
#
# Usage:
#   1. Open a Vivado-enabled PowerShell, for example from the Vivado tools menu
#      or after sourcing the Vivado environment.
#   2. From the repo root, run:
#      powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
#
# This is a local developer regression script. It does not assume CI yet.

$ErrorActionPreference = "Stop"
$RunSuffix = Get-Date -Format "yyyyMMdd_HHmmss"

function Invoke-XsimTest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string[]] $Sources,

        [Parameter(Mandatory = $true)]
        [string] $Top,

        [Parameter(Mandatory = $true)]
        [string] $Snapshot
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Running $Name"
    Write-Host "============================================================"

    & xvlog -sv $Sources
    if ($LASTEXITCODE -ne 0) {
        throw "xvlog failed for $Name with exit code $LASTEXITCODE"
    }

    $snapshotName = "${Snapshot}_${RunSuffix}"

    & xelab $Top -s $snapshotName
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "xelab returned exit code $LASTEXITCODE for $Name. If the snapshot was built and only an obj cleanup warning was reported, xsim may still run successfully."
    }

    $xsimOutput = & xsim $snapshotName -runall 2>&1
    $xsimOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "xsim failed for $Name with exit code $LASTEXITCODE"
    }

    $xsimText = $xsimOutput -join "`n"
    if ($xsimText -match "FATAL_ERROR|TEST FAILED|ERROR:") {
        throw "xsim transcript for $Name contains an error or failed test"
    }

    if ($xsimText -notmatch "PASSED|passed") {
        Write-Warning "xsim transcript for $Name did not contain an explicit pass message"
    }
}

$commonCpuSources = @(
    "rtl/cpu_defs_pkg.sv",
    "rtl/alu.sv",
    "rtl/register_file.sv",
    "rtl/program_counter.sv",
    "rtl/instruction_memory.sv",
    "rtl/data_memory.sv",
    "rtl/fetch_unit.sv",
    "rtl/instruction_decoder.sv",
    "rtl/control_unit.sv",
    "rtl/cpu_core.sv"
)

Invoke-XsimTest `
    -Name "ALU" `
    -Sources @("rtl/alu.sv", "tb/alu_tb.sv") `
    -Top "alu_tb" `
    -Snapshot "alu_tb_sim"

Invoke-XsimTest `
    -Name "Register file" `
    -Sources @("rtl/register_file.sv", "tb/register_file_tb.sv") `
    -Top "register_file_tb" `
    -Snapshot "register_file_tb_sim"

Invoke-XsimTest `
    -Name "Program counter" `
    -Sources @("rtl/program_counter.sv", "tb/program_counter_tb.sv") `
    -Top "program_counter_tb" `
    -Snapshot "program_counter_tb_sim"

Invoke-XsimTest `
    -Name "Instruction memory" `
    -Sources @("rtl/instruction_memory.sv", "tb/instruction_memory_tb.sv") `
    -Top "instruction_memory_tb" `
    -Snapshot "instruction_memory_tb_sim"

Invoke-XsimTest `
    -Name "Data memory" `
    -Sources @("rtl/data_memory.sv", "tb/data_memory_tb.sv") `
    -Top "data_memory_tb" `
    -Snapshot "data_memory_tb_sim"

Invoke-XsimTest `
    -Name "Fetch unit" `
    -Sources @("rtl/program_counter.sv", "rtl/instruction_memory.sv", "rtl/fetch_unit.sv", "tb/fetch_unit_tb.sv") `
    -Top "fetch_unit_tb" `
    -Snapshot "fetch_unit_tb_sim"

Invoke-XsimTest `
    -Name "Instruction decoder" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/instruction_decoder.sv", "tb/instruction_decoder_tb.sv") `
    -Top "instruction_decoder_tb" `
    -Snapshot "instruction_decoder_tb_sim"

Invoke-XsimTest `
    -Name "Control unit" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/control_unit.sv", "tb/control_unit_tb.sv") `
    -Top "control_unit_tb" `
    -Snapshot "control_unit_tb_sim"

Invoke-XsimTest `
    -Name "CPU core direct integration" `
    -Sources ($commonCpuSources + @("tb/cpu_core_tb.sv")) `
    -Top "cpu_core_tb" `
    -Snapshot "cpu_core_tb_sim"

Invoke-XsimTest `
    -Name "CPU core file-loaded LOAD/STORE program" `
    -Sources ($commonCpuSources + @("tb/cpu_core_program_tb.sv")) `
    -Top "cpu_core_program_tb" `
    -Snapshot "cpu_core_program_tb_sim"

Invoke-XsimTest `
    -Name "CPU core branch/jump integration" `
    -Sources ($commonCpuSources + @("tb/cpu_core_branch_tb.sv")) `
    -Top "cpu_core_branch_tb" `
    -Snapshot "cpu_core_branch_tb_sim"

Invoke-XsimTest `
    -Name "CPU core file-loaded branch/jump program" `
    -Sources ($commonCpuSources + @("tb/cpu_core_branch_program_tb.sv")) `
    -Top "cpu_core_branch_program_tb" `
    -Snapshot "cpu_core_branch_program_tb_sim"

Write-Host ""
Write-Host "All XSim regression tests completed."
