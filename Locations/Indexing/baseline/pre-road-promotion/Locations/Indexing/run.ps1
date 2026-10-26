param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'output\altis'),
    [string]$InventoryPath = "",
    [int]$TimeoutSeconds = 900,
    [int]$Port = 2504
)
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot '..\..\tests\tasks\run.ps1'
$testScript = Join-Path $PSScriptRoot 'export.sqf'
$temporaryScript = $null
if ($InventoryPath) {
    $inventory = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $InventoryPath).Path)
    $temporaryScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-index-rebuild-' + [guid]::NewGuid().ToString('N') + '.sqf')
    $script = 'IVCS_IndexKeepInventory = true; IVCS_IndexRecords = call {' + "`r`n" + $inventory + "`r`n};`r`n" + [IO.File]::ReadAllText($testScript)
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
        $match = [regex]::Match($line, ('IVCS_INDEX_' + $kind + '_PART (.*)$'))
        if ($match.Success) { [void]$buffer.Append($match.Groups[1].Value) }
        if ($line -match ('IVCS_INDEX_' + $kind + '_END$')) {
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
if ($InventoryPath) {
    $inputPath = (Resolve-Path -LiteralPath $InventoryPath).Path
    $outputPath = [IO.Path]::GetFullPath((Join-Path $OutputDirectory 'objects.sqf'))
    if ($inputPath -ne $outputPath) { Copy-Item -LiteralPath $inputPath -Destination $outputPath }
}
Write-Output ('Generated candidate index: ' + (Resolve-Path -LiteralPath $OutputDirectory).Path)
