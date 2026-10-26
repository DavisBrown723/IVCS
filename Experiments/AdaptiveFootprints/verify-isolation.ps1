$ErrorActionPreference = 'Stop'
$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'baseline-manifest.json') -Raw | ConvertFrom-Json
$protected = @($manifest.PSObject.Properties | Where-Object {
    $_.Name -match '^IVCS/(Locations/|demos/|tests/locations/|initFunctions\.sqf$|startup\.sqf$)' -or $_.Name -in @('init.sqf','mission.sqm')
})
$changed = @()
foreach ($entry in $protected) {
    $path = Join-Path $workspaceRoot $entry.Name
    if (!(Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value) {
        $changed += $entry.Name
    }
}
if ($changed.Count) { throw ('Production indexing files differ from the frozen baseline: ' + ($changed -join ', ')) }
Write-Output ('Verified unchanged production indexing, demos, tests and entry points: ' + $protected.Count + ' files.')
