param([Parameter(Mandatory)][string]$BenchmarkRoot,[int]$Seconds=150,[string]$Label='exchange-diagnostic')
$ErrorActionPreference='Stop'
$deadline=(Get-Date).AddSeconds(50)
do {
    $rpt=Get-ChildItem -LiteralPath (Join-Path $BenchmarkRoot 'profile') -Filter '*.rpt' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($rpt) {
        $content=Get-Content -LiteralPath $rpt.FullName -Raw
        if ($content -match 'Error in expression|diagnostic anchor missing|TASK TEST\] FAIL') {throw 'Benchmark script error before capture'}
        if ($content -match '\[IVCS PERF\] CONFIG') {break}
    }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)
if (!$content -or $content -notmatch '\[IVCS PERF\] CONFIG') {throw 'Benchmark not ready'}
if ($content -match '\[IVCS PERF\] START') {throw 'Capture startup missed the first measured window; reject this run.'}
$listeners=@(Get-NetTCPConnection -State Listen -LocalPort 8086 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique)
if ($listeners.Count -ne 1) {throw 'Expected one local Tracy listener'}
$server=Get-CimInstance Win32_Process -Filter "ProcessId=$($listeners[0])"
if ($server.Name -ne 'arma3server_x64.exe' -or !$server.CommandLine.Contains($BenchmarkRoot)) {throw 'Listener is not the owned benchmark server'}
if (Get-NetTCPConnection -LocalPort 8086 -State Established -ErrorAction SilentlyContinue) {throw 'Tracy already connected'}
$directory='C:\Users\spyde\.codex\skills\capture-tracy\captures'
$stem='ivcs-'+$Label+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$trace=Join-Path $directory ($stem+'.tracy')
$stdout=Join-Path $directory ($stem+'.stdout.log')
$stderr=Join-Path $directory ($stem+'.stderr.log')
$recorder='C:\Program Files (x86)\Steam\steamapps\workshop\content\107410\1652506957\tracy-capture.exe'
$process=Start-Process -FilePath $recorder -ArgumentList @('-a','127.0.0.1','-p','8086','-s',"$Seconds",'-o',('"'+$trace+'"')) -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Start-Sleep -Seconds 2
$connection=Get-NetTCPConnection -State Established -OwningProcess $process.Id -ErrorAction SilentlyContinue | Where-Object RemotePort -eq 8086
$alive=Get-Process -Id $process.Id -ErrorAction SilentlyContinue
$session=[ordered]@{trace=$trace;stdout=$stdout;stderr=$stderr;recorderPid=$process.Id;serverPid=$server.ProcessId;serverCommandLine=$server.CommandLine;seconds=$Seconds;benchmarkRoot=$BenchmarkRoot;connected=[bool]($connection -and $alive);created=(Get-Date).ToString('o')}
$session | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $directory ($stem+'.session.json')) -Encoding UTF8
$session | ConvertTo-Json -Depth 5
if (!$session.connected) {throw 'Recorder did not establish connection'}
