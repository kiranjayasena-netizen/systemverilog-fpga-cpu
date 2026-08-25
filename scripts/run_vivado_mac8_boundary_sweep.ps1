# Resumable boundary sweep for cpu_core_pipeline_mac8_timingopt.
#
# The default flow first runs 104--108 MHz once, extends to 109/110 MHz only
# when 108 MHz passes, diagnoses 100/102 MHz only when 104 MHz fails, and then
# ensures five fresh deterministic executions at 104 MHz, the highest initial
# pass, and the first initial fail. Repetition numbers are labels, not seeds.

[CmdletBinding()]
param(
    [double[]] $InitialFrequenciesMHz = @(104, 105, 106, 107, 108),
    [int] $RequiredRepetitions = 5,
    [string] $VivadoPath = "",
    [string] $ReportName = "ai_mac8_boundary_sweep",
    [switch] $Resume,
    [switch] $SkipVariationStudy
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Resolve-Vivado {
    param([string] $RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath)) {
            throw "Vivado executable not found: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $command = Get-Command vivado -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }

    foreach ($candidate in @(
        "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat",
        "C:\Xilinx\Vivado\2026.1\bin\vivado.bat"
    )) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw "Vivado 2026.1 was not found. Pass -VivadoPath or use a Vivado-enabled PowerShell."
}

function Get-FrequencyLabel {
    param([double] $FrequencyMHz)
    return $FrequencyMHz.ToString("0.000", [Globalization.CultureInfo]::InvariantCulture).Replace(".", "p")
}

function Test-TimingPass {
    param($Row)

    if ($null -eq $Row) { return $false }
    if ($Row.implementation_success -ne "true" -or $Row.routing_success -ne "true" -or $Row.flow_error) { return $false }
    if (-not $Row.post_route_setup_wns_ns -or -not $Row.post_route_hold_wns_ns) { return $false }
    if ([double]::Parse($Row.post_route_setup_wns_ns, [Globalization.CultureInfo]::InvariantCulture) -lt 0.0) { return $false }
    if ([double]::Parse($Row.post_route_hold_wns_ns, [Globalization.CultureInfo]::InvariantCulture) -lt 0.0) { return $false }
    if ([int]$Row.failing_setup_endpoints -ne 0 -or [int]$Row.failing_hold_endpoints -ne 0) { return $false }
    return $true
}

function Convert-ToRepositoryRelativePath {
    param([string] $Path)

    if (-not $Path) { return $Path }
    $normalizedPath = $Path.Replace("\", "/")
    $normalizedRoot = ([string]$RepoRoot).Replace("\", "/").TrimEnd("/")
    if ($normalizedPath.StartsWith("$normalizedRoot/", [StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedPath.Substring($normalizedRoot.Length + 1)
    }
    return $normalizedPath
}

$Vivado = Resolve-Vivado $VivadoPath
$TclScript = Join-Path $RepoRoot "scripts\run_vivado_impl_mac8_boundary.tcl"
$ReportRoot = Join-Path $RepoRoot "reports\$ReportName"
$RunRoot = Join-Path $ReportRoot "runs"
$SweepId = "sweep_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$SweepRoot = Join-Path $RunRoot $SweepId
$ResultPath = Join-Path $ReportRoot "results.csv"
New-Item -ItemType Directory -Force -Path $SweepRoot | Out-Null
$CurrentRows = @{}

function Get-CompletedRow {
    param([string] $ImplementationIdentifier)

    if (-not (Test-Path -LiteralPath $RunRoot)) { return $null }
    foreach ($file in (Get-ChildItem -LiteralPath $RunRoot -Recurse -Filter run_result.csv -File | Sort-Object LastWriteTime -Descending)) {
        $row = Import-Csv -LiteralPath $file.FullName
        if ($row.implementation_identifier -ne $ImplementationIdentifier) { continue }
        if ($row.implementation_success -eq "true" -and $row.routing_success -eq "true" -and
            $row.bitstream_status -eq "passed" -and -not $row.flow_error) {
            return $row
        }
    }
    return $null
}

function Export-ConsolidatedResults {
    $rows = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $RunRoot) {
        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($file in (Get-ChildItem -LiteralPath $RunRoot -Recurse -Filter run_result.csv -File | Sort-Object LastWriteTime -Descending)) {
            $row = Import-Csv -LiteralPath $file.FullName
            if (-not $seen.Add($row.implementation_identifier)) { continue }

            $estimatedFmax = ""
            if (Test-TimingPass $row) {
                $wns = [double]::Parse($row.post_route_setup_wns_ns, [Globalization.CultureInfo]::InvariantCulture)
                $period = [double]::Parse($row.applied_period_ns, [Globalization.CultureInfo]::InvariantCulture)
                $criticalPeriod = $period - $wns
                if ($criticalPeriod -gt 0.0) {
                    $estimatedFmax = (1000.0 / $criticalPeriod).ToString("0.000", [Globalization.CultureInfo]::InvariantCulture)
                }
            }

            $row | Add-Member -Force -NotePropertyName estimated_routed_fmax_mhz -NotePropertyValue $estimatedFmax
            $row | Add-Member -Force -NotePropertyName vivado_exit_code -NotePropertyValue $(if ($row.flow_error) { 1 } else { 0 })
            foreach ($property in @("run_directory", "timing_report_path", "critical_path_report_path")) {
                $row.$property = Convert-ToRepositoryRelativePath $row.$property
            }
            $rows.Add($row)
        }
    }

    New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
    $rows | Sort-Object @{Expression={$_.implementation_strategy}}, @{Expression={[double]$_.target_frequency_mhz}}, @{Expression={[int]$_.repetition_number}} |
        Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath $ResultPath
    return $rows
}

function Invoke-BoundaryRun {
    param(
        [double] $FrequencyMHz,
        [int] $Repetition,
        [string] $Strategy = "default"
    )

    $frequencyText = $FrequencyMHz.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)
    $frequencyLabel = Get-FrequencyLabel $FrequencyMHz
    $identifier = "${Strategy}_f_${frequencyLabel}_rep_${Repetition}"
    if ($CurrentRows.ContainsKey($identifier)) {
        return $CurrentRows[$identifier]
    }
    if ($Resume) {
        $completed = Get-CompletedRow $identifier
        if ($null -ne $completed) {
            Write-Host "Reusing completed routed result: $identifier"
            $CurrentRows[$identifier] = $completed
            return $completed
        }
    }

    $periodText = (1000.0 / $FrequencyMHz).ToString("0.000000000000", [Globalization.CultureInfo]::InvariantCulture)
    $runDirectory = Join-Path $SweepRoot $identifier
    New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
    $vivadoLog = Join-Path $runDirectory "vivado.log"
    $vivadoJournal = Join-Path $runDirectory "vivado.jou"
    $consoleLog = Join-Path $runDirectory "console.log"

    Write-Host "Running $identifier (${frequencyText} MHz, ${periodText} ns)"
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Vivado -mode batch -log $vivadoLog -journal $vivadoJournal -source $TclScript `
            -tclargs $periodText $frequencyText $Repetition $runDirectory $Strategy $identifier *> $consoleLog
        $vivadoExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPreference
    }

    $runResult = Join-Path $runDirectory "run_result.csv"
    if (-not (Test-Path -LiteralPath $runResult)) {
        Write-Warning "No run_result.csv for $identifier (Vivado exit $vivadoExitCode); see $consoleLog"
        [pscustomobject]@{
            implementation_identifier = $identifier
            target_frequency_mhz = $frequencyText
            target_period_ns = $periodText
            applied_period_ns = ""
            repetition_number = $Repetition
            implementation_strategy = $Strategy
            synthesis_directive = "Default"
            opt_directive = "Default"
            place_directive = $(if ($Strategy -eq "place_extra_net_delay_high") { "ExtraNetDelay_high" } else { "Default" })
            route_directive = $(if ($Strategy -eq "route_aggressive_explore") { "AggressiveExplore" } else { "Default" })
            deterministic_repetition = $(if ($Strategy -eq "default") { "true" } else { "false" })
            seed_applied = "false"
            vivado_version = ""
            fpga_part = "xc7a35tcpg236-1"
            top_module = "fpga_top_pipeline_mac8_timingopt"
            clock_name = "sys_clk_pin"
            synthesis_success = "false"
            synthesis_wns_ns = ""
            implementation_success = "false"
            placement_success = "false"
            routing_success = "false"
            post_route_setup_wns_ns = ""
            setup_tns_ns = ""
            failing_setup_endpoints = ""
            post_route_hold_wns_ns = ""
            hold_tns_ns = ""
            failing_hold_endpoints = ""
            critical_path_data_delay_ns = ""
            critical_path_logic_delay_ns = ""
            critical_path_routing_delay_ns = ""
            logic_levels = ""
            critical_path_startpoint = ""
            critical_path_endpoint = ""
            lut_count = ""
            ff_count = ""
            dsp_count = ""
            bram_tiles = ""
            bitstream_status = "not_attempted"
            run_directory = $runDirectory
            timing_report_path = ""
            critical_path_report_path = ""
            flow_error = "Vivado exit $vivadoExitCode without run_result.csv"
        } | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath $runResult
        $CurrentRows[$identifier] = Import-Csv -LiteralPath $runResult
        Export-ConsolidatedResults | Out-Null
        return $CurrentRows[$identifier]
    }

    $row = Import-Csv -LiteralPath $runResult
    $CurrentRows[$identifier] = $row
    Export-ConsolidatedResults | Out-Null
    if ($vivadoExitCode -ne 0 -or $row.flow_error) {
        Write-Warning "$identifier recorded a flow failure; later runs will continue"
    }
    return $row
}

if ($RequiredRepetitions -lt 5) {
    throw "RequiredRepetitions must be at least 5."
}

$initial = $InitialFrequenciesMHz | Sort-Object -Unique
$selectionFrequencies = @($initial)
foreach ($frequency in $initial) {
    Invoke-BoundaryRun -FrequencyMHz $frequency -Repetition 1 | Out-Null
}

$row108 = $CurrentRows["default_f_108p000_rep_1"]
if ($null -ne $row108 -and (Test-TimingPass $row108)) {
    foreach ($frequency in @(109.0, 110.0)) {
        Invoke-BoundaryRun -FrequencyMHz $frequency -Repetition 1 | Out-Null
        $selectionFrequencies += $frequency
    }
}

$row104 = $CurrentRows["default_f_104p000_rep_1"]
if ($null -eq $row104 -or -not (Test-TimingPass $row104)) {
    foreach ($frequency in @(100.0, 102.0)) {
        Invoke-BoundaryRun -FrequencyMHz $frequency -Repetition 1 | Out-Null
        $selectionFrequencies += $frequency
    }
}

$initialRows = @()
foreach ($frequency in @($selectionFrequencies | Sort-Object -Unique)) {
    $row = $CurrentRows["default_f_$(Get-FrequencyLabel $frequency)_rep_1"]
    if ($null -ne $row) { $initialRows += $row }
}
$passingRows = @($initialRows | Where-Object { Test-TimingPass $_ })
$failingRows = @($initialRows | Where-Object { -not (Test-TimingPass $_) })
if ($passingRows.Count -eq 0 -or $failingRows.Count -eq 0) {
    throw "Initial sweep did not identify both a passing and failing frequency."
}

$highestInitialPass = ($passingRows | ForEach-Object {[double]$_.target_frequency_mhz} | Measure-Object -Maximum).Maximum
$firstInitialFail = ($failingRows | ForEach-Object {[double]$_.target_frequency_mhz} | Measure-Object -Minimum).Minimum
$repeatFrequencies = @(104.0, $highestInitialPass, $firstInitialFail) | Sort-Object -Unique
foreach ($frequency in $repeatFrequencies) {
    for ($repetition = 1; $repetition -le $RequiredRepetitions; $repetition++) {
        Invoke-BoundaryRun -FrequencyMHz $frequency -Repetition $repetition | Out-Null
    }
}

if (-not $SkipVariationStudy) {
    foreach ($strategy in @("place_extra_net_delay_high", "route_aggressive_explore")) {
        Invoke-BoundaryRun -FrequencyMHz $firstInitialFail -Repetition 1 -Strategy $strategy | Out-Null
    }
}

$finalRows = Export-ConsolidatedResults
Write-Host ""
Write-Host "Boundary sweep completed. Deterministic repetition labels are not placement seeds."
$finalRows | Sort-Object @{Expression={[double]$_.target_frequency_mhz}}, implementation_strategy, @{Expression={[int]$_.repetition_number}} |
    Select-Object target_frequency_mhz,repetition_number,implementation_strategy,routing_success,post_route_setup_wns_ns,post_route_hold_wns_ns,failing_setup_endpoints,bitstream_status |
    Format-Table -AutoSize
Write-Host "Results: $ResultPath"
