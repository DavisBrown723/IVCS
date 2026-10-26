param([int]$Port = 8767, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$expectedViewer = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'viewer'))
$url = 'http://127.0.0.1:' + $Port
function Get-MapHealth {
    try { Invoke-RestMethod -Uri ($url + '/__health') -TimeoutSec 2 } catch { $null }
}
$health = Get-MapHealth
if ($health -and ($health.app -ne 'IVCS RoadNetwork' -or $health.viewer -ne $expectedViewer)) {
    throw 'This port is used by another application. Choose a different -Port.'
}
if (!$health) {
    $pythonCandidates = @('C:\Python39\python.exe', (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'))
    $python = $pythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (!$python) { $python = (Get-Command python -ErrorAction Stop).Source }
    $serveScript = Join-Path $PSScriptRoot 'serve.py'
    $logs = Join-Path $PSScriptRoot 'output'
    $process = Start-Process -FilePath $python -ArgumentList @(('"' + $serveScript + '"'), '--port', [string]$Port) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'viewer-stdout.log') -RedirectStandardError (Join-Path $logs 'viewer-stderr.log')
    for ($i = 0; $i -lt 15 -and !$health; $i++) {
        if ($process.HasExited) { throw 'Map server could not start; inspect output/viewer-stderr.log.' }
        Start-Sleep -Milliseconds 200
        $health = Get-MapHealth
    }
    if (!$health -or $health.app -ne 'IVCS RoadNetwork' -or $health.viewer -ne $expectedViewer) { throw 'Map server did not become ready.' }
}
Write-Output ('Road map: ' + $url)
if (!$NoBrowser) { Start-Process -FilePath $url }
