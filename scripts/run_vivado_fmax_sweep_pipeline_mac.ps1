# Reproducible Fmax sweep controller for the Phase 12 MAC8 pipeline.
#
# Vivado 2026.1 has no supported implementation-seed control. The Seeds
# parameter labels independent fresh Vivado processes; results.csv records
# seed_applied=false so these repetitions are not misrepresented as placer
# seeds. The default flow performs one run at every frequency, then four more
# independent runs at 100 MHz and at the observed pass/fail boundary.
# Use -Resume to reuse the newest fully routed, error-free result for each
# requested frequency/repetition key and run only missing cases.

[CmdletBinding()]
param(
    [double[]] $FrequenciesMHz = @(95, 100, 102, 104, 106, 108, 110),
    [int[]] $Seeds = @(1, 2, 3, 4, 5),
    [string] $VivadoPath = "",
    [string] $CoreRtl = "rtl/cpu_core_pipeline_full.sv",
    [string] $TopRtl = "rtl/fpga_top_pipeline.sv",
    [string] $TopModule = "fpga_top_pipeline",
    [string] $ReportName = "ai_mac_fmax_sweep",
    [string] $BitstreamName = "fpga_top_pipeline_mac.bit",
    [switch] $AllSeedsAtAllFrequencies,
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
    if ($null -ne $command) {
        return $command.Source
    }

    foreach ($candidate in @(
        "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat",
        "C:\Xilinx\Vivado\2026.1\bin\vivado.bat"
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
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
    if ($Row.implementation_success -ne "true") { return $false }
    if ($Row.routing_success -ne "true") { return $false }
    if ($Row.flow_error) { return $false }
    if ([double]::Parse($Row.post_route_setup_wns_ns, [Globalization.CultureInfo]::InvariantCulture) -lt 0.0) { return $false }
    if ([double]::Parse($Row.post_route_hold_wns_ns, [Globalization.CultureInfo]::InvariantCulture) -lt 0.0) { return $false }
    if ([int]$Row.failing_setup_endpoints -ne 0) { return $false }
    if ([int]$Row.failing_hold_endpoints -ne 0) { return $false }
    return $true
}

function Convert-ToRepositoryRelativePath {
    param([string] $Path)

    if (-not $Path) { return $Path }
    $normalizedPath = $Path.Replace("\", "/")
    $normalizedRoot = ([string] $RepoRoot).Replace("\", "/").TrimEnd("/")
    if ($normalizedPath.StartsWith("$normalizedRoot/", [StringComparison]::OrdinalIgnoreCase)) {
        return $normalizedPath.Substring($normalizedRoot.Length + 1)
    }
    return $normalizedPath
}

$Vivado = Resolve-Vivado $VivadoPath
$TclScript = Join-Path $RepoRoot "scripts\run_vivado_impl_pipeline_mac_sweep.tcl"
$ReportRoot = Join-Path $RepoRoot "reports\$ReportName"
$SweepId = "sweep_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$SweepRoot = Join-Path $ReportRoot "runs\$SweepId"
$ResultPath = Join-Path $ReportRoot "results.csv"

New-Item -ItemType Directory -Force -Path $SweepRoot | Out-Null

$Rows = [System.Collections.Generic.List[object]]::new()
$CompletedKeys = [System.Collections.Generic.HashSet[string]]::new()

function Add-DerivedResultFields {
    param(
        $Row,
        [int] $VivadoExitCode
    )

    $estimatedFmax = $null
    if ($Row.routing_success -eq "true" -and $Row.post_route_setup_wns_ns) {
        $setupWns = [double]::Parse($Row.post_route_setup_wns_ns, [Globalization.CultureInfo]::InvariantCulture)
        $appliedPeriod = [double]::Parse($Row.applied_period_ns, [Globalization.CultureInfo]::InvariantCulture)
        $criticalPeriod = $appliedPeriod - $setupWns
        if ($criticalPeriod -gt 0.0) {
            $estimatedFmax = 1000.0 / $criticalPeriod
        }
    }

    $Row | Add-Member -Force -NotePropertyName vivado_exit_code -NotePropertyValue $VivadoExitCode
    $Row | Add-Member -Force -NotePropertyName estimated_routed_fmax_mhz -NotePropertyValue $(
        if ($null -eq $estimatedFmax) { "" } else { $estimatedFmax.ToString("0.000", [Globalization.CultureInfo]::InvariantCulture) }
    )
    foreach ($pathProperty in @("run_directory", "timing_report_path", "critical_path_report_path")) {
        if ($null -ne $Row.PSObject.Properties[$pathProperty]) {
            $Row.$pathProperty = Convert-ToRepositoryRelativePath $Row.$pathProperty
        }
    }
    return $Row
}

function Invoke-SweepRun {
    param(
        [double] $FrequencyMHz,
        [int] $Seed
    )

    $frequencyText = $FrequencyMHz.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)
    $periodNs = 1000.0 / $FrequencyMHz
    $periodText = $periodNs.ToString("0.000000000000", [Globalization.CultureInfo]::InvariantCulture)
    $frequencyLabel = Get-FrequencyLabel $FrequencyMHz
    $key = "$frequencyLabel|$Seed"
    if (-not $CompletedKeys.Add($key)) {
        return
    }

    $runDirectory = Join-Path $SweepRoot "f_${frequencyLabel}_seed_${Seed}"
    New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
    $vivadoLog = Join-Path $runDirectory "vivado.log"
    $vivadoJournal = Join-Path $runDirectory "vivado.jou"
    $consoleLog = Join-Path $runDirectory "console.log"

    Write-Host "Running ${frequencyText} MHz (${periodText} ns), independent repetition $Seed"
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell converts native stderr into error records. Keep a
        # failed Vivado flow in its console log so run_result.csv can still be
        # imported and the remaining sweep cases can continue.
        $ErrorActionPreference = "Continue"
        & $Vivado -mode batch -log $vivadoLog -journal $vivadoJournal -source $TclScript `
            -tclargs $periodText $frequencyText $Seed $runDirectory $CoreRtl $TopRtl $TopModule $BitstreamName *> $consoleLog
        $vivadoExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }

    $runResult = Join-Path $runDirectory "run_result.csv"
    if (Test-Path -LiteralPath $runResult) {
        $row = Import-Csv -LiteralPath $runResult
        $Rows.Add((Add-DerivedResultFields -Row $row -VivadoExitCode $vivadoExitCode))
    } else {
        Write-Warning "Vivado produced no run_result.csv for ${frequencyText} MHz repetition $Seed (exit $vivadoExitCode). See $consoleLog"
        $Rows.Add([pscustomobject]@{
            target_frequency_mhz = $frequencyText
            target_period_ns = $periodText
            implementation_seed = $Seed
            seed_applied = "false"
            synthesis_success = "false"
            implementation_success = "false"
            placement_success = "false"
            routing_success = "false"
            bitstream_status = "not_attempted"
            run_directory = $runDirectory
            flow_error = "Vivado exit $vivadoExitCode without run_result.csv"
            vivado_exit_code = $vivadoExitCode
            estimated_routed_fmax_mhz = ""
        })
    }
}

$sortedFrequencies = $FrequenciesMHz | Sort-Object -Unique
$sortedSeeds = $Seeds | Sort-Object -Unique
if ($sortedFrequencies.Count -eq 0) { throw "At least one frequency is required." }
if ($sortedSeeds.Count -eq 0) { throw "At least one independent-run label is required." }

if ($Resume) {
    $runRoot = Join-Path $ReportRoot "runs"
    if (Test-Path -LiteralPath $runRoot) {
        $candidateResults = Get-ChildItem -LiteralPath $runRoot -Recurse -Filter run_result.csv -File |
            Sort-Object LastWriteTime -Descending
        foreach ($candidateResult in $candidateResults) {
            $row = Import-Csv -LiteralPath $candidateResult.FullName
            if ($row.implementation_success -ne "true" -or $row.routing_success -ne "true" -or
                $row.bitstream_status -ne "passed" -or $row.flow_error) {
                continue
            }

            $frequency = [double]::Parse($row.target_frequency_mhz, [Globalization.CultureInfo]::InvariantCulture)
            $seed = [int]$row.implementation_seed
            if ($sortedFrequencies -notcontains $frequency -or $sortedSeeds -notcontains $seed) {
                continue
            }

            $key = "$(Get-FrequencyLabel $frequency)|$seed"
            if ($CompletedKeys.Add($key)) {
                $Rows.Add((Add-DerivedResultFields -Row $row -VivadoExitCode 0))
            }
        }
        Write-Host "Resumed $($Rows.Count) completed routed runs from $runRoot"
    }
}

$initialSeed = $sortedSeeds[0]
foreach ($frequency in $sortedFrequencies) {
    Invoke-SweepRun -FrequencyMHz $frequency -Seed $initialSeed
}

if ($AllSeedsAtAllFrequencies) {
    $expandedFrequencies = $sortedFrequencies
} else {
    $initialRows = $Rows | Where-Object { [int]$_.implementation_seed -eq $initialSeed }
    $passingFrequencies = @($initialRows | Where-Object { Test-TimingPass $_ } | ForEach-Object { [double]$_.target_frequency_mhz })
    $highestPass = if ($passingFrequencies.Count -gt 0) { ($passingFrequencies | Measure-Object -Maximum).Maximum } else { $null }
    $firstFail = $null
    if ($null -ne $highestPass) {
        $higherRows = $initialRows | Where-Object { [double]$_.target_frequency_mhz -gt $highestPass } | Sort-Object { [double]$_.target_frequency_mhz }
        $firstFailRow = $higherRows | Where-Object { -not (Test-TimingPass $_) } | Select-Object -First 1
        if ($null -ne $firstFailRow) { $firstFail = [double]$firstFailRow.target_frequency_mhz }
    }

    $boundaryFrequencies = @($highestPass, $firstFail) | Where-Object { $null -ne $_ }
    if ($sortedFrequencies -contains 100.0) {
        # Force array concatenation even when the pipeline above returned one
        # scalar value; numeric += would otherwise turn 104 + 100 into 204.
        $boundaryFrequencies = @($boundaryFrequencies) + @(100.0)
    }
    $expandedFrequencies = $boundaryFrequencies | Sort-Object -Unique
}

foreach ($frequency in $expandedFrequencies) {
    foreach ($seed in $sortedSeeds) {
        Invoke-SweepRun -FrequencyMHz $frequency -Seed $seed
    }
}

New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$Rows | Sort-Object @{Expression={ [double]$_.target_frequency_mhz }}, @{Expression={ [int]$_.implementation_seed }} | `
    Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath $ResultPath

Write-Host ""
Write-Host "Fmax sweep summary (seed_applied is false; labels are independent runs):"
$Rows | Sort-Object @{Expression={ [double]$_.target_frequency_mhz }}, @{Expression={ [int]$_.implementation_seed }} | `
    Select-Object target_frequency_mhz, target_period_ns, applied_period_ns, implementation_seed, routing_success, `
        post_route_setup_wns_ns, post_route_hold_wns_ns, failing_setup_endpoints, bitstream_status | `
    Format-Table -AutoSize
Write-Host "Results: $ResultPath"
