param([switch]$Rescan, [switch]$RebuildLocations, [int]$Port = 2510, [int]$TimeoutSeconds = 900, [string]$Locations = (Join-Path $PSScriptRoot 'inputs\altis-locations.sqf'))
$ErrorActionPreference = 'Stop'
$pythonCandidates = @('C:\Python39\python.exe', (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'))
$python = $pythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$python) { $python = (Get-Command python -ErrorAction Stop).Source }
if ($RebuildLocations) {
    & (Join-Path $PSScriptRoot '..\..\tests\tasks\run.ps1') -TestScript (Join-Path $PSScriptRoot 'tests\settlement-ports.sqf') -Port ($Port + 2) -TimeoutSeconds $TimeoutSeconds
    & (Join-Path $PSScriptRoot 'Locations\run.ps1') -Port ($Port + 2) -TimeoutSeconds $TimeoutSeconds
}
$capturePath = Join-Path $PSScriptRoot 'output\altis\capture.json'
$builder = Join-Path $PSScriptRoot 'index.py'
$buildArgs = @($builder,'--locations',$Locations)
if ($Rescan -or !(Test-Path -LiteralPath $capturePath)) {
    $runner = Join-Path $PSScriptRoot '..\..\tests\tasks\run.ps1'
    $output = @()
    & $runner -TestScript (Join-Path $PSScriptRoot 'extract.sqf') -Port $Port -TimeoutSeconds $TimeoutSeconds | ForEach-Object { $output += $_; Write-Output $_ }
    $artifactLine = $output | Where-Object { $_ -like 'Test artifacts: *' } | Select-Object -First 1
    if (!$artifactLine) { throw 'Missing native extraction output.' }
    $runPath = $artifactLine.Substring('Test artifacts: '.Length)
    $rpt = Get-ChildItem -LiteralPath (Join-Path $runPath 'profile') -Filter '*.rpt' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $buildArgs += @('--rpt',$rpt.FullName)
}
& $python @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'Road index build failed.' }
& $python -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p 'test_*.py' -v
if ($LASTEXITCODE -ne 0) { throw 'Road index tests failed.' }
Write-Output 'Built the isolated road index and browser data. Open Open map.cmd to explore.'
