param([Parameter(Mandatory=$true)][ValidateSet('baseline','optimized')][string]$Variant,
      [string]$Vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$iso=Join-Path $repo '.vivado_hw_user'; $tmp=Join-Path $repo '.vivado_hw_temp'
New-Item -ItemType Directory -Force $iso,$tmp | Out-Null
$env:APPDATA=Join-Path $iso 'Roaming'; $env:LOCALAPPDATA=Join-Path $iso 'Local'
$env:USERPROFILE=$iso; $env:HOME=$iso; $env:TEMP=$tmp; $env:TMP=$tmp
$env:XILINX_TCLAPP_REPO='C:\AMDDesignTools\2026.1\Vivado\data\XilinxTclStore'
$tcl=Join-Path $repo ("scripts\program_ai_cpu_{0}_basys3.tcl" -f $Variant)
Write-Host "PROGRAM_TCL=$tcl"
& $Vivado -nolog -nojournal -mode batch -source $tcl
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
