param([int]$Port = 8767)
$ErrorActionPreference = 'Stop'
$url = 'http://127.0.0.1:' + $Port
try { $health = Invoke-RestMethod -Uri ($url + '/__health') -TimeoutSec 2 } catch { Write-Output 'Map server is not running.'; return }
$expectedViewer = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'viewer'))
if ($health.app -ne 'IVCS RoadNetwork' -or $health.viewer -ne $expectedViewer) { throw 'Refusing to stop an unrelated application.' }
$process = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + [int]$health.pid)
if (!$process -or $process.CommandLine -notlike ('*' + (Join-Path $PSScriptRoot 'serve.py') + '*')) { throw 'Server process identity did not match.' }
Stop-Process -Id ([int]$health.pid)
Write-Output 'Road map server stopped.'
