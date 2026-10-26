param([int]$Port=2522,[int]$TimeoutSeconds=300)
$ErrorActionPreference='Stop'
$test=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-vehicle-review-'+[guid]::NewGuid().ToString('N')+'.sqf')
$names=@{BeforeReturn='stepReturnFire';BeforeVehicleShot='getVehicleShot'}
$header=''
foreach ($entry in $names.GetEnumerator()) {
    $body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ('vehicle-review-baseline/'+$entry.Value+'.sqf')))
    $header += 'IVCS_Review_'+$entry.Key+' = {'+$body+'};'+"`r`n"
}
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'vehicle-review.sqf'))
[IO.File]::WriteAllText($test,$header+$source,[Text.UTF8Encoding]::new($false))
try { & (Join-Path $PSScriptRoot '../tasks/run.ps1') -TestScript $test -Port $Port -TimeoutSeconds $TimeoutSeconds }
finally { Remove-Item -LiteralPath $test -ErrorAction SilentlyContinue }
