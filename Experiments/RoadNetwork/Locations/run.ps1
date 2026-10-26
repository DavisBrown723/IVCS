param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'output\altis'),
    [string]$InventoryPath = (Join-Path $PSScriptRoot '..\..\..\Locations\Indexing\output\altis\objects.sqf'),
    [int]$TimeoutSeconds = 900,
    [int]$Port = 2512
)
$ErrorActionPreference = 'Stop'
# Every writable output must remain in this experiment's output subtree.
$experimentOutputRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'output')) + [IO.Path]::DirectorySeparatorChar
$requestedOutput = [IO.Path]::GetFullPath($OutputDirectory)
if (!$requestedOutput.StartsWith($experimentOutputRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be inside RoadNetwork/Locations/output; production output is protected.'
}
$runner = Join-Path $PSScriptRoot '..\..\..\tests\tasks\run.ps1'
$testScript = Join-Path $PSScriptRoot 'export.sqf'
$temporaryScript = $null
if ($InventoryPath) {
    $inventory = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $InventoryPath).Path)
    $temporaryScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-rn-locations-' + [guid]::NewGuid().ToString('N') + '.sqf')
    $script = 'IVCS_AF_IndexKeepInventory = true; IVCS_AF_IndexRecords = call {' + "`r`n" + $inventory + "`r`n};`r`n" + [IO.File]::ReadAllText($testScript)
    [IO.File]::WriteAllText($temporaryScript, ($script -replace '\r?\n', "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    $testScript = $temporaryScript
}
$output = @()
try {
    & $runner -TestScript $testScript -TimeoutSeconds $TimeoutSeconds -Port $Port | ForEach-Object { $output += $_; Write-Output $_ }
} finally {
    if ($temporaryScript) { Remove-Item -LiteralPath $temporaryScript }
}
$artifactLine = $output | Where-Object { $_ -like 'Test artifacts: *' } | Select-Object -First 1
if (!$artifactLine) { throw 'Missing test artifact directory.' }
$runPath = $artifactLine.Substring('Test artifacts: '.Length)
$log = Get-ChildItem -LiteralPath (Join-Path $runPath 'profile') -Filter '*.rpt' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$lines = Get-Content -LiteralPath $log.FullName
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$encoding = New-Object System.Text.UTF8Encoding($false)
$kinds = if ($InventoryPath) { @('LOCATION', 'CATALOG') } else { @('LOCATION', 'CATALOG', 'OBJECT') }
foreach ($kind in $kinds) {
    $data = New-Object 'System.Collections.Generic.List[string]'
    $buffer = New-Object System.Text.StringBuilder
    foreach ($line in $lines) {
        $match = [regex]::Match($line, ('IVCS_AF_INDEX_' + $kind + '_PART (.*)$'))
        if ($match.Success) { [void]$buffer.Append($match.Groups[1].Value) }
        if ($line -match ('IVCS_AF_INDEX_' + $kind + '_END$')) {
            $data.Add($buffer.ToString())
            [void]$buffer.Clear()
        }
    }
    if ($buffer.Length -ne 0) { throw "Incomplete $kind export." }
    if ($data.Count -eq 0) { throw "No $kind output; inspect $($log.FullName)." }
    if ($kind -eq 'LOCATION') {
        $name = 'locations.sqf'
        $source = $data -join "`r`n"
    } else {
        $name = if ($kind -eq 'CATALOG') { 'catalog.sqf' } else { 'objects.sqf' }
        $source = '[' + "`r`n" + ($data -join ",`r`n") + "`r`n" + ']'
    }
    if ($kind -eq 'OBJECT') {
        $source = 'private _records = [];' + "`r`n" + '{ _x params ["_class","_model","_positions"]; { _records pushBack [_class,_model,_x]; } forEach _positions; } forEach ' + $source + ";`r`n_records"
    }
    [IO.File]::WriteAllText((Join-Path $OutputDirectory $name), $source + "`r`n", $encoding)
}
Write-Output ('Generated experimental index: ' + (Resolve-Path -LiteralPath $OutputDirectory).Path)

$pythonCandidates = @('C:\Python39\python.exe', (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'))
$python = $pythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$python) { $python = (Get-Command python -ErrorAction Stop).Source }
& $python (Join-Path $PSScriptRoot 'promote.py') --input (Join-Path $OutputDirectory 'locations.sqf') --rpt $log.FullName
if ($LASTEXITCODE -ne 0) { throw 'Location promotion/validation failed.' }
