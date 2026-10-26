param(
    [switch]$NativeStockAmmo,
    [ValidateRange(1, 1000)][int]$Trials = 20,
    [int]$Port = 2495,
    [int]$TimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-ammo-endurance-' + [guid]::NewGuid().ToString('N') + '.sqf')
$taskNative = if ($NativeStockAmmo) { 'true' } else { 'false' }
$taskHeader = "IVCS_Ammo_UseNativeStock = $taskNative;`r`nIVCS_Ammo_TrialCount = $Trials;`r`n"
$taskSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ammo-endurance.sqf'))
[IO.File]::WriteAllText($taskScript, $taskHeader + ($taskSource -replace '\r?\n', "`r`n"), [Text.UTF8Encoding]::new($false))
try {
    & (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds $TimeoutSeconds
} finally {
    Remove-Item -LiteralPath $taskScript -ErrorAction SilentlyContinue
}
