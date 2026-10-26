param([int]$Port=2492)
$ErrorActionPreference='Stop'
$baseline=Join-Path $PSScriptRoot 'shot-selection-baseline/getVehicleShot.sqf'
$manifest=Get-Content (Join-Path $PSScriptRoot 'shot-selection-baseline/manifest.json') -Raw | ConvertFrom-Json
if ((Get-FileHash $baseline -Algorithm SHA256).Hash -ne $manifest.'getVehicleShot.sqf') {throw 'Selector baseline hash mismatch.'}
$header='IVCS_Review_BeforeVehicleShot={'+[IO.File]::ReadAllText($baseline)+'};'+"`r`n"
$script=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-shot-selection-'+[guid]::NewGuid().ToString('N')+'.sqf')
[IO.File]::WriteAllText($script,$header+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'shot-selection.sqf')),[Text.UTF8Encoding]::new($false))
try { & (Join-Path $PSScriptRoot '../tasks/run.ps1') -TestScript $script -Port $Port -TimeoutSeconds 240 }
finally {Remove-Item -LiteralPath $script -ErrorAction SilentlyContinue}
