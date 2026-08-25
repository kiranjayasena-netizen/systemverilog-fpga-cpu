param(
  [Parameter(Mandatory=$true)][ValidateSet('baseline','optimized')][string]$Variant,
  [string]$Vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$isolated = Join-Path $repo '.vivado_isolated_user'
$temp = Join-Path $repo '.vivado_build_temp'
New-Item -ItemType Directory -Force $isolated,$temp | Out-Null
$env:APPDATA = Join-Path $isolated 'Roaming'
$env:LOCALAPPDATA = Join-Path $isolated 'Local'
$env:USERPROFILE = $isolated
$env:HOME = $isolated
$env:TEMP = $temp
$env:TMP = $temp
$env:XILINX_TCLAPP_REPO = 'C:\AMDDesignTools\2026.1\Vivado\data\XilinxTclStore'
$tcl = Join-Path $repo ("scripts\run_ai_cpu_{0}_bitstream.tcl" -f $Variant)
Write-Host "AI_CPU_VIVADO_ISOLATED_USER=$isolated"
Write-Host "AI_CPU_BUILD_TCL=$tcl"
& $Vivado -nolog -nojournal -mode batch -source $tcl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
