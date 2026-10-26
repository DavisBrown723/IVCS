param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'output\altis'),
    [string]$InventoryPath = '',
    [switch]$RescanRoads,
    [int]$TimeoutSeconds = 900,
    [int]$Port = 2504
)
$ErrorActionPreference = 'Stop'
$pythonCandidates = @('C:\Python39\python.exe', (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'))
$python = $pythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$python) { $python = (Get-Command python -ErrorAction Stop).Source }
# Publishing moves directories only inside this explicit output root, never a computed external path.
$outputRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'output'))
$target = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar)
if ([IO.Path]::GetDirectoryName($target) -ne $outputRoot -or [IO.Path]::GetFileName($target).StartsWith('.')) {
    throw 'OutputDirectory must be a direct named child of Locations/Indexing/output.'
}
if ($InventoryPath) { $InventoryPath = (Resolve-Path -LiteralPath $InventoryPath).Path }
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$buildId = [guid]::NewGuid().ToString('N')
$stage = Join-Path $outputRoot ('.building-' + $buildId)
$backup = Join-Path $outputRoot ('.previous-' + [IO.Path]::GetFileName($target) + '-' + $buildId)
New-Item -ItemType Directory -Path $stage | Out-Null
$roads = Join-Path $PSScriptRoot 'Roads'
$capture = Join-Path $target 'roads\capture.json'
if (!(Test-Path -LiteralPath $capture)) { $capture = Join-Path $roads 'cache\altis-capture.json' }
try {
    & (Join-Path $PSScriptRoot 'build-locations.ps1') -OutputDirectory $stage -InventoryPath $InventoryPath -Port $Port -TimeoutSeconds $TimeoutSeconds
    $roadArgs = @((Join-Path $roads 'index.py'), '--locations', (Join-Path $stage 'locations.sqf'), '--output', (Join-Path $stage 'roads'), '--viewer-directory', (Join-Path $stage 'viewer'))
    if ($RescanRoads -or !(Test-Path -LiteralPath $capture)) {
        $captureOutput = @()
        & (Join-Path $PSScriptRoot '..\..\tests\tasks\run.ps1') -TestScript (Join-Path $roads 'extract.sqf') -Port ($Port + 2) -TimeoutSeconds $TimeoutSeconds | ForEach-Object { $captureOutput += $_; Write-Output $_ }
        $artifactLine = $captureOutput | Where-Object { $_ -like 'Test artifacts: *' } | Select-Object -First 1
        if (!$artifactLine) { throw 'Missing native road extraction output.' }
        $runPath = $artifactLine.Substring('Test artifacts: '.Length)
        $rpt = Get-ChildItem -LiteralPath (Join-Path $runPath 'profile') -Filter '*.rpt' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $roadArgs += @('--rpt', $rpt.FullName)
    } else { $roadArgs += @('--capture', $capture) }
    & $python @roadArgs
    if ($LASTEXITCODE -ne 0) { throw 'Road index build failed.' }
    & $python (Join-Path $PSScriptRoot 'pipeline.py') --directory $stage
    if ($LASTEXITCODE -ne 0) { throw 'Combined index validation failed.' }
    # A failed build leaves the published dataset intact and retains its stage for diagnosis.
    # All three absolute paths have the same checked output parent.
    foreach ($publishPath in @($target, $stage, $backup)) {
        if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($publishPath)) -ne $outputRoot) { throw 'Unsafe publish path.' }
    }
    $hadPrevious = Test-Path -LiteralPath $target
    if ($hadPrevious) { Move-Item -LiteralPath $target -Destination $backup }
    try { Move-Item -LiteralPath $stage -Destination $target }
    catch {
        if ($hadPrevious -and !(Test-Path -LiteralPath $target)) { Move-Item -LiteralPath $backup -Destination $target }
        throw
    }
    Write-Output ('Generated complete map index: ' + $target)
    if ($hadPrevious) { Write-Output ('Previous output retained: ' + $backup) }
    Write-Output 'Locations, road network, access points, routing package and viewer data are from the same build.'
} catch {
    Write-Output ('Build failed; unpublished stage retained: ' + $stage)
    throw
}
