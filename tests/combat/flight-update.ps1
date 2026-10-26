param([int]$Port=2494)
$ErrorActionPreference='Stop'
$directory=Join-Path $PSScriptRoot 'flight-update-baseline'
$manifest=Get-Content (Join-Path $directory 'manifest.json') -Raw | ConvertFrom-Json
$header=''
foreach ($entry in $manifest.functions) {
    $path=Join-Path $directory $entry[0]
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest.($entry[0])) {throw 'Flight fixture baseline hash mismatch.'}
    $header+='IVCS_Flight_Before_'+$entry[1]+'={'+[IO.File]::ReadAllText($path)+'};'+[Environment]::NewLine
}
$script=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-flight-update-'+[guid]::NewGuid().ToString('N')+'.sqf')
[IO.File]::WriteAllText($script,$header+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'flight-update.sqf')),[Text.UTF8Encoding]::new($false))
try {& (Join-Path $PSScriptRoot '../tasks/run.ps1') -TestScript $script -Port $Port -TimeoutSeconds 240}
finally {Remove-Item -LiteralPath $script -ErrorAction SilentlyContinue}
