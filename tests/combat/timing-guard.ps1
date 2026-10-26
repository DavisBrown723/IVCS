$ErrorActionPreference='Stop'
$python='C:\Python39\python.exe'
$modulePath=$PSScriptRoot.Replace('\','\\').Replace("'","\'")
$check="import sys;sys.path.insert(0,'$modulePath');from timing_guard import assert_benchmark_idle;assert_benchmark_idle()"
$root=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-timing-guard-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$hold=Join-Path $root 'hold.py'
$source="import sys,time,os"+[Environment]::NewLine+
"from pathlib import Path"+[Environment]::NewLine+
"sys.path.insert(0,'$modulePath')"+[Environment]::NewLine+
"from timing_guard import assert_benchmark_idle"+[Environment]::NewLine+
"assert_benchmark_idle();Path(sys.argv[1]).write_text('ready');time.sleep(2)"+[Environment]::NewLine+
"if sys.argv[2]=='abandon':os._exit(0)"
[IO.File]::WriteAllText($hold,$source)
$mutex=[Threading.Mutex]::new($false,'Local\IVCS_Combat_Timing')
$owned=$false;$passed=0
try {
    $owned=$mutex.WaitOne(0)
    if (!$owned) {throw 'Run timing lease checks after active jobs finish'}
    & $python -c $check 2> (Join-Path $root 'blocked.stderr.log')
    if ($LASTEXITCODE -eq 0) {throw 'Analysis incorrectly overlapped benchmark'}
    $passed++
    $prior=$env:IVCS_TIMING_DIAGNOSTIC_INTERFERENCE
    try {
        $env:IVCS_TIMING_DIAGNOSTIC_INTERFERENCE='1'
        & $python -c $check
        if ($LASTEXITCODE -ne 0) {throw 'Explicit interference diagnostic was incorrectly blocked'}
        $passed++
    } finally {$env:IVCS_TIMING_DIAGNOSTIC_INTERFERENCE=$prior}
    $mutex.ReleaseMutex();$owned=$false
    foreach ($mode in @('normal','abandon')) {
        $signal=Join-Path $root ($mode+'.ready')
        $child=Start-Process -FilePath $python -ArgumentList @($hold,$signal,$mode) -WindowStyle Hidden -PassThru
        $deadline=[DateTime]::UtcNow.AddSeconds(10)
        while (!(Test-Path -LiteralPath $signal) -and !$child.HasExited -and [DateTime]::UtcNow -lt $deadline) {Start-Sleep -Milliseconds 20}
        if (!(Test-Path -LiteralPath $signal)) {throw 'Analysis process did not acquire lease'}
        $owned=$mutex.WaitOne(0)
        if ($owned) {throw 'Benchmark incorrectly overlapped active analysis'}
        $passed++
        if (!$child.WaitForExit(5000)) {throw 'Lease test child exceeded bounded lifetime'}
        try {$owned=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$owned=$true}
        if (!$owned) {throw 'Finished analysis did not release lease'}
        $passed++
        $mutex.ReleaseMutex();$owned=$false
    }
} finally {
    if ($owned) {$mutex.ReleaseMutex()}
    $mutex.Dispose()
}
[ordered]@{passed=$passed;failed=0;artifactDirectory=$root} | ConvertTo-Json
