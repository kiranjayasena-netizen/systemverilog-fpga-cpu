# Run all current Vivado XSim testbenches.
#
# Usage:
#   1. Open a Vivado-enabled PowerShell, for example from the Vivado tools menu
#      or after sourcing the Vivado environment.
#   2. Run:
#      powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
#
# This is a local developer regression script. It does not assume CI yet.

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot
$RunSuffix = Get-Date -Format "yyyyMMdd_HHmmss"

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
        $candidate = Join-Path $root "$ToolName.bat"
        if (Test-Path $candidate) {
            return $candidate
        }

        $candidate = Join-Path $root "$ToolName.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Could not find $ToolName. Open a Vivado-enabled PowerShell or set VIVADO_BIN to the Vivado bin directory."
}

$Xvlog = Resolve-VivadoTool "xvlog"
$Xelab = Resolve-VivadoTool "xelab"
$Xsim  = Resolve-VivadoTool "xsim"

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

    & $Xvlog -sv $Sources
    if ($LASTEXITCODE -ne 0) {
        throw "xvlog failed for $Name with exit code $LASTEXITCODE"
    }

    $snapshotName = "${Snapshot}_${RunSuffix}"

    & $Xelab $Top -s $snapshotName
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "xelab returned exit code $LASTEXITCODE for $Name. If the snapshot was built and only an obj cleanup warning was reported, xsim may still run successfully."
    }

    $xsimOutput = & $Xsim $snapshotName -runall 2>&1
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

$phase5CpuTopSources = $commonCpuSources + @(
    "rtl/cpu_top.sv"
)

$fpgaTopSources = $commonCpuSources + @(
    "rtl/slow_tick_generator.sv",
    "rtl/fpga_top.sv"
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

Invoke-XsimTest `
    -Name "Slow tick generator" `
    -Sources @("rtl/slow_tick_generator.sv", "tb/slow_tick_generator_tb.sv") `
    -Top "slow_tick_generator_tb" `
    -Snapshot "slow_tick_generator_tb_sim"

Invoke-XsimTest `
    -Name "FPGA top wrapper" `
    -Sources ($fpgaTopSources + @("tb/fpga_top_tb.sv")) `
    -Top "fpga_top_tb" `
    -Snapshot "fpga_top_tb_sim"

Invoke-XsimTest `
    -Name "Phase 5 instruction memory" `
    -Sources @("rtl/instr_mem.sv", "tb/tb_instr_mem.sv") `
    -Top "tb_instr_mem" `
    -Snapshot "tb_instr_mem_sim"

Invoke-XsimTest `
    -Name "Phase 5 data memory" `
    -Sources @("rtl/data_mem.sv", "tb/tb_data_mem.sv") `
    -Top "tb_data_mem" `
    -Snapshot "tb_data_mem_sim"

Invoke-XsimTest `
    -Name "Phase 10C BRAM-style instruction memory" `
    -Sources @("rtl/bram_instr_mem.sv", "tb/tb_bram_instr_mem.sv") `
    -Top "tb_bram_instr_mem" `
    -Snapshot "tb_bram_instr_mem_sim"

Invoke-XsimTest `
    -Name "Phase 10C BRAM-style data memory" `
    -Sources @("rtl/bram_data_mem.sv", "tb/tb_bram_data_mem.sv") `
    -Top "tb_bram_data_mem" `
    -Snapshot "tb_bram_data_mem_sim"

Invoke-XsimTest `
    -Name "Phase 5 program execution" `
    -Sources ($phase5CpuTopSources + @("tb/tb_program_execution.sv")) `
    -Top "tb_program_execution" `
    -Snapshot "tb_program_execution_sim"

Invoke-XsimTest `
    -Name "Phase 6 arithmetic edge program" `
    -Sources ($phase5CpuTopSources + @("tb/tb_phase6_arithmetic_edge.sv")) `
    -Top "tb_phase6_arithmetic_edge" `
    -Snapshot "tb_phase6_arithmetic_edge_sim"

Invoke-XsimTest `
    -Name "Phase 6B memory offset program" `
    -Sources ($phase5CpuTopSources + @("tb/tb_phase6_memory_offset.sv")) `
    -Top "tb_phase6_memory_offset" `
    -Snapshot "tb_phase6_memory_offset_sim"

Invoke-XsimTest `
    -Name "Phase 6C branch control program" `
    -Sources ($phase5CpuTopSources + @("tb/tb_phase6_branch_control.sv")) `
    -Top "tb_phase6_branch_control" `
    -Snapshot "tb_phase6_branch_control_sim"

Invoke-XsimTest `
    -Name "Phase 6D jump control program" `
    -Sources ($phase5CpuTopSources + @("tb/tb_phase6_jump_control.sv")) `
    -Top "tb_phase6_jump_control" `
    -Snapshot "tb_phase6_jump_control_sim"

Invoke-XsimTest `
    -Name "Phase 6E simple loop program" `
    -Sources ($phase5CpuTopSources + @("tb/tb_phase6_simple_loop.sv")) `
    -Top "tb_phase6_simple_loop" `
    -Snapshot "tb_phase6_simple_loop_sim"

Invoke-XsimTest `
    -Name "Phase 6F invalid opcode program" `
    -Sources ($phase5CpuTopSources + @("tb/tb_phase6_invalid_opcode.sv")) `
    -Top "tb_phase6_invalid_opcode" `
    -Snapshot "tb_phase6_invalid_opcode_sim"

Invoke-XsimTest `
    -Name "Phase 8B multi-cycle CPU FSM skeleton" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/cpu_core_multicycle.sv", "tb/tb_cpu_core_multicycle_fsm.sv") `
    -Top "tb_cpu_core_multicycle_fsm" `
    -Snapshot "tb_cpu_core_multicycle_fsm_sim"

Invoke-XsimTest `
    -Name "Phase 8C multi-cycle CPU arithmetic" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/cpu_core_multicycle.sv", "tb/tb_cpu_core_multicycle_arithmetic.sv") `
    -Top "tb_cpu_core_multicycle_arithmetic" `
    -Snapshot "tb_cpu_core_multicycle_arithmetic_sim"

Invoke-XsimTest `
    -Name "Phase 8D multi-cycle CPU memory" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/cpu_core_multicycle.sv", "tb/tb_cpu_core_multicycle_memory.sv") `
    -Top "tb_cpu_core_multicycle_memory" `
    -Snapshot "tb_cpu_core_multicycle_memory_sim"

Invoke-XsimTest `
    -Name "Phase 8E multi-cycle CPU branch/jump" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/cpu_core_multicycle.sv", "tb/tb_cpu_core_multicycle_branch_jump.sv") `
    -Top "tb_cpu_core_multicycle_branch_jump" `
    -Snapshot "tb_cpu_core_multicycle_branch_jump_sim"

Invoke-XsimTest `
    -Name "Phase 8F multi-cycle CPU full programs" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/cpu_core_multicycle.sv", "tb/tb_cpu_core_multicycle_full_programs.sv") `
    -Top "tb_cpu_core_multicycle_full_programs" `
    -Snapshot "tb_cpu_core_multicycle_full_programs_sim"

Invoke-XsimTest `
    -Name "Phase 10A multi-cycle CPU performance" `
    -Sources @("rtl/cpu_defs_pkg.sv", "rtl/cpu_core_multicycle.sv", "tb/tb_cpu_core_multicycle_performance.sv") `
    -Top "tb_cpu_core_multicycle_performance" `
    -Snapshot "tb_cpu_core_multicycle_performance_sim"

Invoke-XsimTest `
    -Name "Phase 10B single-cycle-style CPU performance" `
    -Sources ($commonCpuSources + @("tb/tb_cpu_core_singlecycle_performance.sv")) `
    -Top "tb_cpu_core_singlecycle_performance" `
    -Snapshot "tb_cpu_core_singlecycle_performance_sim"

Write-Host ""
Write-Host "All XSim regression tests completed."
