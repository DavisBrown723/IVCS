param([int]$Port=2492)
$ErrorActionPreference='Stop'
$directory=Join-Path $PSScriptRoot 'exchange-baseline'
$manifest=Get-Content (Join-Path $directory 'manifest.json') -Raw | ConvertFrom-Json
$path=Join-Path $directory 'stepVehicle.sqf'
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest.'stepVehicle.sqf') {throw 'Exchange baseline hash mismatch'}
$header='IVCS_Exchange_Before={'+[IO.File]::ReadAllText($path)+'};'+[Environment]::NewLine
$script=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-exchange-'+[guid]::NewGuid().ToString('N')+'.sqf')
[IO.File]::WriteAllText($script,$header+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'exchange.sqf')),[Text.UTF8Encoding]::new($false))
try {& (Join-Path $PSScriptRoot '../tasks/run.ps1') -TestScript $script -Port $Port -TimeoutSeconds 240}
finally {Remove-Item -LiteralPath $script -ErrorAction SilentlyContinue}
