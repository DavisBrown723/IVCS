param([int]$Runs=2,[int]$StartRun=1,[string]$Label)
$ErrorActionPreference='Stop'
if (!$Label) {$Label='timing-validation-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)}
$operationReports=@()
$repository=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$pwsh=(Get-Process -Id $PID).Path
$controller=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-timing-controller-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $controller | Out-Null
$mod='"-mod=!Workshop\@CBA_A3;!Workshop\@Intercept Minimal Dev;!Workshop\@Arma Script Profiler"'
for ($run=$StartRun;$run -le $Runs;$run++) {
    $runLabel="$Label-$run"
    $directory=Join-Path $controller $runLabel
    New-Item -ItemType Directory -Path $directory | Out-Null
    $launcher=Join-Path $directory 'launch.ps1'
    $runner=Join-Path $PSScriptRoot 'helicopter-performance.ps1'
    $baseline=Join-Path $PSScriptRoot 'timing-control-baseline'
    $controlManifest=Get-Content (Join-Path $baseline 'manifest.json') -Raw | ConvertFrom-Json
    $liveSource=Join-Path $repository 'VirtualSpace/functions/combat/stepVehicle.sqf'
    $controlHash=(Get-FileHash -LiteralPath $liveSource -Algorithm SHA256).Hash.ToLowerInvariant()
    if (!$controlManifest.identical_code_control -or $controlHash -ne $controlManifest.'stepVehicle.sqf') {throw 'Refresh the identical-code control baseline from current production before validation.'}
    $body="Set-Location -LiteralPath '"+$repository.Replace("'","''")+"'"+[Environment]::NewLine+
        "& '"+$runner.Replace("'","''")+"' -Seconds 35 -Trials 4 -Modes @('heli-infantry-aa') -BaselineDirectory '"+$baseline.Replace("'","''")+"' -ProfilerMarkers -StartupDelaySeconds 60 -PostDelaySeconds 60 -Port 2502 -ExtraArguments @('-noPause','"+$mod+"')"
    $reverse=$run % 2 -eq 0
    if ($reverse) {$body+=' -ReverseComparison'}
    [IO.File]::WriteAllText($launcher,$body)
    $stdout=Join-Path $directory 'benchmark.stdout.log'
    $stderr=Join-Path $directory 'benchmark.stderr.log'
    $benchmark=Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile','-NonInteractive','-File',('"'+$launcher+'"')) -WorkingDirectory $repository -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $deadline=[DateTime]::UtcNow.AddSeconds(650)
    $root=$null
    while (!$benchmark.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        $log=Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue
        if ($log -match 'Test artifacts: ([^\r\n]+)') {$root=$Matches[1].Trim();break}
        Start-Sleep -Milliseconds 250
    }
    if (!$root) {throw "Benchmark launch failed: $stderr"}
    Write-Output "$runLabel benchmark: $root"
    $sessionJson=& (Join-Path $PSScriptRoot 'start-tracy-server.ps1') -BenchmarkRoot $root -Seconds 240 -Label $runLabel
    $session=$sessionJson | ConvertFrom-Json
    $session | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $directory 'capture-session.json') -Encoding UTF8
    Write-Output "$runLabel connected: $($session.trace)"
    $hostDirectory=Join-Path $directory 'host'
    $counter=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'collect-timing-host.ps1')+'"'),'-OutputDirectory',('"'+$hostDirectory+'"'),'-Seconds','245') -WorkingDirectory $repository -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $directory 'counter.stdout.log') -RedirectStandardError (Join-Path $directory 'counter.stderr.log')
    while (!$benchmark.HasExited -and [DateTime]::UtcNow -lt $deadline) {Start-Sleep -Seconds 1}
    if (!$benchmark.HasExited) {throw 'Owned benchmark exceeded its bounded deadline'}
    $benchmark.WaitForExit()
    if ($benchmark.ExitCode -ne 0) {throw "Benchmark failed: $stderr"}
    $counterExited=$counter.WaitForExit(15000)
    if (!$counterExited) {Stop-Process -Id $counter.Id}
    $counterAvailable=$counterExited -and $counter.ExitCode -eq 0 -and (Test-Path -LiteralPath (Join-Path $hostDirectory 'host.blg'))
    if (!$counterAvailable) {Write-Warning 'Host telemetry unavailable; completed timing capture is retained.'}
    $saved=Get-Content -LiteralPath $session.stdout -Raw
    if ($saved -notmatch 'Saving trace\.\.\. done!' -or !(Test-Path -LiteralPath $session.trace) -or (Get-Item -LiteralPath $session.trace).Length -eq 0) {throw 'Recorder has not saved a complete trace'}
    $session | Add-Member -NotePropertyName compilation -NotePropertyValue 'same-object'
    $session | Add-Member -NotePropertyName comparison_order -NotePropertyValue $(if ($reverse) {'BAAB'} else {'ABBA'})
    $session | Add-Member -NotePropertyName identical_code_control -NotePropertyValue $true
    $session | Add-Member -NotePropertyName control_source_sha256 -NotePropertyValue $controlHash
    $session | Add-Member -NotePropertyName counter_available -NotePropertyValue $counterAvailable
    $session | Add-Member -NotePropertyName saved -NotePropertyValue $true
    $session | Add-Member -NotePropertyName file_bytes -NotePropertyValue (Get-Item -LiteralPath $session.trace).Length
    $session | Add-Member -NotePropertyName save_log -NotePropertyValue $saved
    $session | Add-Member -NotePropertyName controller_directory -NotePropertyValue $directory
    $out=Join-Path $repository 'docs/combat-performance-results'
    $session | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out ($runLabel+'-session.json')) -Encoding UTF8
    # Analysis begins only after the benchmark exits and releases its timing mutex.
    $reader=Join-Path $env:USERPROFILE '.codex/skills/read-tracy/scripts/read_tracy.py'
    & C:\Python39\python.exe (Join-Path $PSScriptRoot 'timing_guard.py') C:\Python39\python.exe $reader $session.trace --filter IVCS_PERF_ --unwrap --top 8 | Set-Content (Join-Path $out ($runLabel+'-scopes.json')) -Encoding UTF8
    if ($LASTEXITCODE -ne 0) {throw 'Trace decode failed'}
    $rpt=(Get-ChildItem -LiteralPath (Join-Path $root 'profile') -Filter '*.rpt' | Select-Object -First 1).FullName
    & C:\Python39\python.exe (Join-Path $PSScriptRoot 'analyze-helicopter-performance.py') $rpt --output $out --label $runLabel
    if ($LASTEXITCODE -ne 0) {throw 'Benchmark validation failed'}
    & C:\Python39\python.exe (Join-Path $PSScriptRoot 'analyze-operations.py') $session.trace --output $out --label ($runLabel+'-operations') --benchmark-summary (Join-Path $out ($runLabel+'-summary.json')) --extra-prefix IVCS_HELI_
    if ($LASTEXITCODE -ne 0) {throw 'Complete-window trace attribution failed'}
    & C:\Python39\python.exe (Join-Path $PSScriptRoot 'analyze-helicopter-tracy.py') (Join-Path $out ($runLabel+'-operations-summary.json')) --output (Join-Path $out ($runLabel+'-precise-summary.json'))
    if ($LASTEXITCODE -ne 0) {throw 'Precise frame analysis failed'}
    $operationReports+=Join-Path $out ($runLabel+'-operations-summary.json')
    Write-Output "$runLabel complete and analyzed"
}
$confidence=Join-Path $out ($Label+'-confidence.json')
& C:\Python39\python.exe (Join-Path $PSScriptRoot 'analyze-timing-validation.py') @operationReports --repetitions 5000 --output $confidence
if ($LASTEXITCODE -ne 0) {throw 'Timing uncertainty analysis failed'}
$assessment=Get-Content -LiteralPath $confidence -Raw | ConvertFrom-Json
Write-Output ('Validation controller evidence: '+$controller)
Write-Output ('Confidence and quality: '+$confidence)
if (!$assessment.stationarity_gate.passed) {throw 'Completed captures retained, but timing drift failed the stationarity gate. Do not treat this as an optimization result.'}
