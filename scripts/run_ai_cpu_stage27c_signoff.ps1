param([string]$Vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
# Isolate Vivado's per-user TclStore/configuration so XSim runs are
# reproducible on hosts with a corrupted or unwritable global TclStore.
$iso = Join-Path $root '.vivado_signoff_user'
$tmp = Join-Path $root '.vivado_signoff_temp'
New-Item -ItemType Directory -Force (Join-Path $iso 'Roaming'),(Join-Path $iso 'Local'),$tmp | Out-Null
$env:APPDATA = Join-Path $iso 'Roaming'
$env:LOCALAPPDATA = Join-Path $iso 'Local'
$env:USERPROFILE = $iso
$env:HOME = $iso
$env:TEMP = $tmp
$env:TMP = $tmp
$env:XILINX_TCLAPP_REPO = 'C:/AMDDesignTools/2026.1/Vivado/data/XilinxTclStore'

function Run-Xsim([string]$script, [string]$log, [string]$simlog, [string[]]$markers) {
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $Vivado -mode batch -source $script 2>&1 | Tee-Object -FilePath $log
  $ErrorActionPreference = $oldEap
  if ($LASTEXITCODE -ne 0) { throw "$script failed" }
  $text = (Get-Content $log -Raw) + "`n" + (Get-Content $simlog -Raw)
  foreach ($m in $markers) { if ($text -notmatch [regex]::Escape($m)) { throw "Missing marker $m in $log" } }
}

Run-Xsim 'scripts/run_ai_cpu_baseline_equivalence_xsim.tcl' '.stage27c_baseline.log' '.ai_cpu_baseline_eq_xsim/xsim.log' @('AI_CPU_BASELINE_EQUIVALENCE_PASS')
Run-Xsim 'scripts/run_ai_cpu_optimized_equivalence_xsim.tcl' '.stage27c_optimized.log' '.ai_cpu_optimized_eq_xsim/xsim.log' @('AI_CPU_OPTIMIZED_EQUIVALENCE_PASS','AI_CPU_DOT64_CYCLE_EQUIVALENCE_PASS')
Run-Xsim 'scripts/run_ai_cpu_uart_xsim.tcl' '.stage27c_uart.log' '.ai_cpu_uart_xsim/xsim.log' @('AI_CPU_UART_PROTOCOL_PASS')
Run-Xsim 'scripts/run_ai_cpu_validation_wrapper_xsim.tcl' '.stage27c_wrapper.log' '.ai_cpu_validation_wrapper_xsim/xsim.log' @('AI_CPU_VALIDATION_WRAPPER_SMOKE PASS')
Run-Xsim 'scripts/run_ai_cpu_validation_e2e_xsim.tcl' '.stage27c_e2e.log' '.ai_cpu_validation_e2e_xsim/xsim.log' @(
  'AI_CPU_VALIDATION_E2E_PASS',
  'AI_CPU_DOT4_END_TO_END_PASS',
  'AI_CPU_DOT64_END_TO_END_PASS',
  'AI_CPU_MATVEC_END_TO_END_PASS',
  'AI_CPU_EDGE_END_TO_END_PASS',
  'AI_CPU_COMPLETION_SEMANTICS_PASS',
  'AI_CPU_CYCLE_COUNTER_WORKLOAD_PASS',
  'AI_CPU_RESET_RESTART_PASS')

# Repeat the complete workload simulation twice more.  This verifies that
# execution-only cycle counts remain deterministic across fresh jobs while
# the E2E bench itself exercises cross-workload reset/restart transitions.
$reference = Get-Content '.ai_cpu_validation_e2e_xsim/xsim.log' -Raw
for ($r = 2; $r -le 3; $r++) {
  $log = ".stage27c_e2e_run${r}.log"
  Run-Xsim 'scripts/run_ai_cpu_validation_e2e_xsim.tcl' $log '.ai_cpu_validation_e2e_xsim/xsim.log' @(
    'AI_CPU_VALIDATION_E2E_PASS','AI_CPU_DOT4_END_TO_END_PASS',
    'AI_CPU_DOT64_END_TO_END_PASS','AI_CPU_MATVEC_END_TO_END_PASS',
    'AI_CPU_EDGE_END_TO_END_PASS','AI_CPU_COMPLETION_SEMANTICS_PASS',
    'AI_CPU_CYCLE_COUNTER_WORKLOAD_PASS','AI_CPU_RESET_RESTART_PASS')
  $current = Get-Content '.ai_cpu_validation_e2e_xsim/xsim.log' -Raw
  foreach ($needle in @('DOT4_END_TO_END_PASS BASE=00000046 OPT=00000046 BASE_CYCLES=41 OPT_CYCLES=16',
                        'DOT64_END_TO_END_PASS BASE=00000040 OPT=00000040 BASE_CYCLES=72 OPT_CYCLES=31')) {
    if ($current -notmatch [regex]::Escape($needle)) { throw "Non-deterministic cycle/result in E2E run ${r}: $needle" }
  }
}

Write-Host 'AI_CPU_STAGE27C_SIGNOFF_PASS'
