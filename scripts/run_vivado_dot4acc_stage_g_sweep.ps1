# Resumable default-flow post-route characterization of the fixed DOT4ACC CPU.
# Repetition labels identify fresh deterministic Vivado processes; they are not
# placement seeds because Vivado 2026.1 exposes no supported seed in this flow.

[CmdletBinding()]
param(
    [double[]] $CoarseFrequenciesMHz = @(100, 101, 102, 103, 104),
    [int] $RequiredRepetitions = 5,
    [double] $MaximumFrequencyMHz = 120,
    [string] $VivadoPath = "",
    [string] $ReportName = "dot4acc_stage_g",
    [switch] $Resume
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

function Convert-ToDouble {
    param([string] $Value)
    if (-not $Value) { return $null }
    $number = 0.0
    if ([double]::TryParse($Value, [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }
    return $null
}

function Test-TimingPass {
    param($Row)
    if ($null -eq $Row) { return $false }
    if ($Row.implementation_success -ne "true" -or $Row.routing_success -ne "true" -or $Row.flow_error) { return $false }
    if ($Row.bitstream_status -ne "passed") { return $false }
    $setup = Convert-ToDouble $Row.wns_ns
    $hold = Convert-ToDouble $Row.worst_hold_slack_ns
    if ($null -eq $setup -or $setup -lt 0.0 -or $null -eq $hold -or $hold -lt 0.0) { return $false }
    if ([int]$Row.failing_setup_endpoints -ne 0 -or [int]$Row.failing_hold_endpoints -ne 0) { return $false }
    $pulse = Convert-ToDouble $Row.pulse_width_wns_ns
    if ($null -ne $pulse -and $pulse -lt 0.0) { return $false }
    if ($Row.failing_pulse_width_endpoints -and [int]$Row.failing_pulse_width_endpoints -ne 0) { return $false }
    return $true
}

function Get-CriticalPathCategory {
    param($Row)
    # These categories were validated against the routed pin/cell/net reports
    # emitted by report_dot4acc_post_route_details.tcl.  Cell names alone are
    # insufficient because synthesis absorbs several control cones into the
    # dot4acc_pipeline_inst hierarchy.
    if ($Row.critical_startpoint -like "*data_mem_inst/mem_reg/CLKARDCLK" -and
        $Row.critical_endpoint -like "*dot_chain*_reg*/R") {
        return "LOAD writeback/forwarding -> branch redirect cancellation -> DOT chain-state reset"
    }
    if ($Row.critical_startpoint -like "*id_ex_reg_reg[[]rs2[]]*" -and
        $Row.critical_endpoint -like "*fetch_pc_reg*/CE") {
        return "DOT dependency and branch/redirect -> frontend clock-enable control"
    }
    return "Other routed control/data path; inspect detailed report"
}

if ($RequiredRepetitions -lt 5) { throw "RequiredRepetitions must be at least 5." }

$Vivado = Resolve-Vivado $VivadoPath
$TclScript = Join-Path $RepoRoot "scripts\run_vivado_impl_dot4acc_stage_g.tcl"
$ReportRoot = Join-Path $RepoRoot "reports\$ReportName"
$RunRoot = Join-Path $ReportRoot "runs"
$SweepRoot = Join-Path $RunRoot "sweep_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$ResultPath = Join-Path $ReportRoot "results.csv"
New-Item -ItemType Directory -Force -Path $SweepRoot | Out-Null
$CurrentRows = @{}

function Get-RunIdentifier {
    param([double] $FrequencyMHz, [int] $Repetition)
    return "default_f_$(Get-FrequencyLabel $FrequencyMHz)_rep_$Repetition"
}

function Get-CompletedRow {
    param([string] $Identifier)
    if (-not (Test-Path -LiteralPath $RunRoot)) { return $null }
    foreach ($file in (Get-ChildItem -LiteralPath $RunRoot -Recurse -Filter run_result.csv -File |
            Sort-Object LastWriteTime -Descending)) {
        $row = Import-Csv -LiteralPath $file.FullName
        if ($row.implementation_identifier -ne $Identifier) { continue }
        if ($row.implementation_success -eq "true" -and $row.routing_success -eq "true" -and
            $row.bitstream_status -eq "passed" -and -not $row.flow_error) {
            return $row
        }
    }
    return $null
}

function Add-DerivedFields {
    param($Row, [string] $RunResultPath)
    $setup = Convert-ToDouble $Row.wns_ns
    $hold = Convert-ToDouble $Row.worst_hold_slack_ns
    $pulse = Convert-ToDouble $Row.pulse_width_wns_ns
    $period = Convert-ToDouble $Row.applied_period_ns
    $estimatedFmax = ""
    if ($null -ne $setup -and $null -ne $period -and ($period - $setup) -gt 0.0) {
        $estimatedFmax = (1000.0 / ($period - $setup)).ToString("0.000", [Globalization.CultureInfo]::InvariantCulture)
    }
    $runDirectory = Split-Path -Parent $RunResultPath
    $consoleLog = Join-Path $runDirectory "console.log"
    $warningCount = 0
    $criticalWarningCount = 0
    $errorCount = 0
    if (Test-Path -LiteralPath $consoleLog) {
        $criticalWarningCount = @(Select-String -LiteralPath $consoleLog -Pattern '^CRITICAL WARNING:' -ErrorAction SilentlyContinue).Count
        $warningCount = @(Select-String -LiteralPath $consoleLog -Pattern '^WARNING:' -ErrorAction SilentlyContinue).Count
        $errorCount = @(Select-String -LiteralPath $consoleLog -Pattern '^ERROR:' -ErrorAction SilentlyContinue).Count
    }
    $Row | Add-Member -Force NoteProperty setup_pass $(if ($null -ne $setup -and $setup -ge 0.0 -and [int]$Row.failing_setup_endpoints -eq 0) { "true" } else { "false" })
    $Row | Add-Member -Force NoteProperty hold_pass $(if ($null -ne $hold -and $hold -ge 0.0 -and [int]$Row.failing_hold_endpoints -eq 0) { "true" } else { "false" })
    $Row | Add-Member -Force NoteProperty pulse_width_pass $(if ($null -eq $pulse -or $pulse -ge 0.0) { "true" } else { "false" })
    $Row | Add-Member -Force NoteProperty overall_pass $(if (Test-TimingPass $Row) { "true" } else { "false" })
    $Row | Add-Member -Force NoteProperty estimated_routed_fmax_mhz $estimatedFmax
    $Row | Add-Member -Force NoteProperty warning_count $warningCount
    $Row | Add-Member -Force NoteProperty critical_warning_count $criticalWarningCount
    $Row | Add-Member -Force NoteProperty error_count $errorCount
    $Row | Add-Member -Force NoteProperty critical_path_category (Get-CriticalPathCategory $Row)
    $checkTimingPath = Join-Path $runDirectory "methodology\check_timing.rpt"
    $checkTimingText = if (Test-Path -LiteralPath $checkTimingPath) { Get-Content -Raw -LiteralPath $checkTimingPath } else { "" }
    foreach ($field in @(
        @{Name="no_clock_pins"; Pattern='checking no_clock \(([0-9]+)\)'},
        @{Name="pulse_width_clock_pins"; Pattern='checking pulse_width_clock \(([0-9]+)\)'},
        @{Name="unconstrained_internal_endpoints"; Pattern='checking unconstrained_internal_endpoints \(([0-9]+)\)'},
        @{Name="missing_input_delays"; Pattern='checking no_input_delay \(([0-9]+)\)'},
        @{Name="missing_output_delays"; Pattern='checking no_output_delay \(([0-9]+)\)'},
        @{Name="combinational_loops"; Pattern='checking loops \(([0-9]+)\)'},
        @{Name="latch_loops"; Pattern='checking latch_loops \(([0-9]+)\)'}
    )) {
        $value = if ($checkTimingText -match $field.Pattern) { $Matches[1] } else { "" }
        $Row | Add-Member -Force NoteProperty $field.Name $value
    }
    foreach ($property in @(
        "run_directory", "timing_report_path", "critical_path_report_path",
        "hold_path_report_path", "check_timing_report_path", "methodology_report_path",
        "clock_interaction_report_path", "drc_report_path"
    )) {
        if ($null -ne $Row.PSObject.Properties[$property]) {
            $Row.$property = Convert-ToRepositoryRelativePath $Row.$property
        }
    }
    return $Row
}

function Export-ConsolidatedResults {
    $rows = [System.Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $RunRoot) {
        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($file in (Get-ChildItem -LiteralPath $RunRoot -Recurse -Filter run_result.csv -File |
                Sort-Object LastWriteTime -Descending)) {
            $row = Import-Csv -LiteralPath $file.FullName
            if (-not $seen.Add($row.implementation_identifier)) { continue }
            $rows.Add((Add-DerivedFields -Row $row -RunResultPath $file.FullName))
        }
    }
    New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
    $rows | Sort-Object @{Expression={[double]$_.frequency_mhz}}, @{Expression={[int]$_.run_id}} |
        Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath $ResultPath
    return $rows
}

function Invoke-StageFRun {
    param([double] $FrequencyMHz, [int] $Repetition)
    $identifier = Get-RunIdentifier $FrequencyMHz $Repetition
    if ($CurrentRows.ContainsKey($identifier)) { return $CurrentRows[$identifier] }
    if ($Resume) {
        $completed = Get-CompletedRow $identifier
        if ($null -ne $completed) {
            Write-Host "Reusing completed routed result: $identifier"
            $CurrentRows[$identifier] = $completed
            return $completed
        }
    }

    $frequencyText = $FrequencyMHz.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)
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
            -tclargs $periodText $frequencyText $Repetition $runDirectory $identifier *> $consoleLog
        $vivadoExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPreference
    }

    $runResult = Join-Path $runDirectory "run_result.csv"
    if (-not (Test-Path -LiteralPath $runResult)) {
        throw "Vivado produced no run_result.csv for $identifier (exit $vivadoExitCode); see $consoleLog"
    }
    $row = Import-Csv -LiteralPath $runResult
    $CurrentRows[$identifier] = $row
    Export-ConsolidatedResults | Out-Null
    if ($vivadoExitCode -ne 0 -or $row.flow_error) {
        Write-Warning "$identifier recorded a flow failure; later requested runs will continue"
    }
    return $row
}

function Get-RowsAtFrequency {
    param([double] $FrequencyMHz)
    $label = Get-FrequencyLabel $FrequencyMHz
    return @($CurrentRows.Keys | Where-Object { $_ -like "default_f_${label}_rep_*" } |
        ForEach-Object { $CurrentRows[$_] })
}

function Ensure-Repetitions {
    param([double] $FrequencyMHz)
    for ($repetition = 1; $repetition -le $RequiredRepetitions; $repetition++) {
        Invoke-StageFRun $FrequencyMHz $repetition | Out-Null
    }
}

function Test-RepeatablePass {
    param([double] $FrequencyMHz)
    $rows = Get-RowsAtFrequency $FrequencyMHz
    return $rows.Count -ge $RequiredRepetitions -and
        @($rows | Where-Object { Test-TimingPass $_ }).Count -eq $rows.Count
}

function Test-RepeatableFail {
    param([double] $FrequencyMHz)
    $rows = Get-RowsAtFrequency $FrequencyMHz
    return $rows.Count -ge $RequiredRepetitions -and
        @($rows | Where-Object { Test-TimingPass $_ }).Count -eq 0
}

# F3/F4: establish five clean 100 MHz executions first.
Ensure-Repetitions 100.0
$coarse = @($CoarseFrequenciesMHz | Sort-Object -Unique)
$highestObservedPass = $null
$firstObservedFail = $null
if (Test-RepeatablePass 100.0) {
    # F5: one ascending coarse run, stopping after the first setup/hold failure.
    $highestObservedPass = 100.0
    foreach ($frequency in $coarse) {
        if ($frequency -le 100.0) { continue }
        $row = Invoke-StageFRun $frequency 1
        if (Test-TimingPass $row) {
            $highestObservedPass = $frequency
        } else {
            $firstObservedFail = $frequency
            break
        }
    }
    if ($null -eq $firstObservedFail) {
        $frequency = (($coarse | Measure-Object -Maximum).Maximum + 2.0)
        while ($frequency -le $MaximumFrequencyMHz) {
            $row = Invoke-StageFRun $frequency 1
            if (Test-TimingPass $row) {
                $highestObservedPass = $frequency
                $frequency += 2.0
            } else {
                $firstObservedFail = $frequency
                break
            }
        }
    }
} else {
    # A 100 MHz failure is evidence, not permission to optimize. Search down in
    # bounded 2 MHz steps, then apply the same 1 MHz boundary rule.
    $firstObservedFail = 100.0
    for ($frequency = 98.0; $frequency -ge 80.0; $frequency -= 2.0) {
        $row = Invoke-StageFRun $frequency 1
        if (Test-TimingPass $row) {
            $highestObservedPass = $frequency
            break
        }
        $firstObservedFail = $frequency
    }
}
if ($null -eq $firstObservedFail) {
    throw "No failing frequency found through $MaximumFrequencyMHz MHz; extend the bounded sweep explicitly."
}
if ($null -eq $highestObservedPass) {
    throw "No passing frequency found in the bounded 80--100 MHz fallback sweep."
}

# F6: narrow an integer-MHz gap without fractional-MHz vanity searches.
for ($frequency = [math]::Floor($highestObservedPass) + 1.0;
     $frequency -lt $firstObservedFail; $frequency += 1.0) {
    $row = Invoke-StageFRun $frequency 1
    if (Test-TimingPass $row) {
        $highestObservedPass = $frequency
    } else {
        $firstObservedFail = $frequency
        break
    }
}

# F7: five-run candidate proof, with conservative fallback on any mixed pass set.
Ensure-Repetitions $highestObservedPass
while (-not (Test-RepeatablePass $highestObservedPass) -and $highestObservedPass -gt 100.0) {
    $highestObservedPass -= 1.0
    Ensure-Repetitions $highestObservedPass
}
if (-not (Test-RepeatablePass $highestObservedPass)) {
    throw "No repeatable passing point found in the bounded search."
}

$candidateFail = $highestObservedPass + 1.0
while ($candidateFail -le $MaximumFrequencyMHz) {
    Ensure-Repetitions $candidateFail
    if (Test-RepeatableFail $candidateFail) { break }
    $candidateFail += 1.0
}
if ($candidateFail -gt $MaximumFrequencyMHz) {
    throw "No five-of-five failing point found through $MaximumFrequencyMHz MHz."
}

$finalRows = Export-ConsolidatedResults
Write-Host ""
Write-Host "DOT4ACC Stage G1 default-flow sweep completed. Repetition labels are not placement seeds."
$finalRows | Sort-Object @{Expression={[double]$_.frequency_mhz}}, @{Expression={[int]$_.run_id}} |
    Select-Object frequency_mhz,run_id,wns_ns,worst_hold_slack_ns,setup_pass,hold_pass,overall_pass,lut,ff,dsp48,ramb18 |
    Format-Table -AutoSize
Write-Host "Highest repeatable pass: $highestObservedPass MHz"
Write-Host "Lowest five-of-five fail above it: $candidateFail MHz"
Write-Host "Results: $ResultPath"

