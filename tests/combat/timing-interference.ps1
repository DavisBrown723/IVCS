param([Parameter(Mandatory)][string]$BenchmarkRoot,[Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$deadline=[DateTime]::UtcNow.AddSeconds(320)
$rpt=$null
do {
    $rpt=Get-ChildItem -LiteralPath (Join-Path $BenchmarkRoot 'profile') -Filter '*.rpt' -ErrorAction SilentlyContinue | Select-Object -First 1
    $ready=$rpt -and (Select-String -LiteralPath $rpt.FullName -Pattern '\[IVCS PERF\] START \[2,' -Quiet)
    if (!$ready) {Start-Sleep -Milliseconds 250}
} while (!$ready -and [DateTime]::UtcNow -lt $deadline)
if (!$ready) {throw 'Interference window never started'}
$stopFile=Join-Path $OutputDirectory 'stop'
$workerScript=Join-Path $OutputDirectory 'analysis-worker.ps1'
$repository=(Get-Location).Path
@'
param([string]$Repository,[string]$Output,[string]$StopFile)
Set-Location -LiteralPath $Repository
$env:IVCS_TIMING_DIAGNOSTIC_INTERFERENCE='1'
$deadline=[DateTime]::UtcNow.AddSeconds(110)
$iteration=0
while (!(Test-Path -LiteralPath $StopFile) -and [DateTime]::UtcNow -lt $deadline) {
    $iteration++
    $started=[DateTime]::UtcNow
    & C:\Python39\python.exe tests/combat/analyze-operations.py C:\Users\spyde\.codex\skills\capture-tracy\captures\ivcs-exchange-repeat-20261026-010226-30cbf499.tracy --output $Output --events-output $Output --label interference-analysis --benchmark-summary docs/combat-performance-results/exchange-repeat-summary.json --extra-prefix IVCS_HELI_ *> $null
    [ordered]@{iteration=$iteration;startUtc=$started.ToString('o');endUtc=[DateTime]::UtcNow.ToString('o');exitCode=$LASTEXITCODE} | ConvertTo-Json -Compress | Add-Content (Join-Path $Output 'analysis-jobs.jsonl')
}
'@ | Set-Content -LiteralPath $workerScript -Encoding UTF8
$arguments=@('-NoProfile','-NonInteractive','-File',('"'+$workerScript+'"'),'-Repository',('"'+$repository+'"'),'-Output',('"'+$OutputDirectory+'"'),'-StopFile',('"'+$stopFile+'"'))
$worker=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $OutputDirectory 'worker.stdout.log') -RedirectStandardError (Join-Path $OutputDirectory 'worker.stderr.log')
[ordered]@{workerPid=$worker.Id;startUtc=[DateTime]::UtcNow.ToString('o');condition='one repeated profiler analysis job during windows 2 and 3';benchmarkRoot=$BenchmarkRoot} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'interference-session.json') -Encoding UTF8
try {
    while (!$worker.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        if (Select-String -LiteralPath $rpt.FullName -Pattern '\[IVCS PERF\] PHASE \[3,' -Quiet) {break}
        Start-Sleep -Milliseconds 250
    }
} finally {
    [IO.File]::WriteAllText($stopFile,'stop')
    if (!$worker.WaitForExit(15000)) {Stop-Process -Id $worker.Id;throw 'Bounded analysis worker exceeded graceful shutdown deadline'}
}
Write-Output ('Interference jobs stopped; evidence: '+$OutputDirectory)
