param(
    [ValidateRange(5,300)][int]$Seconds = 20,
    [ValidateRange(1,10)][int]$Trials = 2,
    [int[]]$GroupCounts = @(20,40,80),
    [ValidateRange(0,60)][int]$WarmupSeconds = 2,
    [int]$PostDelaySeconds = 0,
    [int]$StartupDelaySeconds = 0,
    [switch]$ProfilerMarkers,
    [switch]$AmmoPressure,
    [switch]$IncludeAmmoPressure,
    [switch]$OperationScopes,
    [switch]$ContextScopes,
    [switch]$CombatOnly,
    [ValidateRange(-1,100)][double]$CombatBudgetMs = -1,
    [int]$Port = 2502,
    [int]$TimeoutSeconds = 900,
    [string[]]$ExtraArguments = @()
)
$ErrorActionPreference = 'Stop'
foreach ($count in $GroupCounts) {
    if ($count -lt 2 -or $count % 2 -ne 0) { throw 'Group counts must be positive even numbers (two groups per engagement).' }
}
if ($AmmoPressure -and $IncludeAmmoPressure) { throw 'Choose AmmoPressure or IncludeAmmoPressure.' }
if ($ContextScopes) { $OperationScopes = $true }
if ($OperationScopes) { $ProfilerMarkers = $true }
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-combat-performance-' + [guid]::NewGuid().ToString('N') + '.sqf')
$markerFlag = if ($ProfilerMarkers) { 'true' } else { 'false' }
$includePressureFlag = if ($IncludeAmmoPressure) { 'true' } else { 'false' }
$pressureFlag = if ($AmmoPressure) { 'true' } else { 'false' }
$combatOnlyFlag = if ($CombatOnly) { 'true' } else { 'false' }
$budgetFlag = $CombatBudgetMs.ToString([Globalization.CultureInfo]::InvariantCulture)
$header = "IVCS_Perf_CombatOnly = $combatOnlyFlag;`r`nIVCS_Perf_BudgetMs = $budgetFlag;`r`nIVCS_Perf_IncludeAmmoPressure = $includePressureFlag;`r`nIVCS_Perf_AmmoPressure = $pressureFlag;`r`nIVCS_Perf_Profiler = $markerFlag;`r`nIVCS_Perf_Seconds = $Seconds;`r`nIVCS_Perf_Trials = $Trials;`r`nIVCS_Perf_Sizes = [$($GroupCounts -join ',')];`r`nIVCS_Perf_Warmup = $WarmupSeconds;`r`nIVCS_Perf_PostDelay = $PostDelaySeconds;`r`nIVCS_Perf_StartupDelay = $StartupDelaySeconds;`r`n"
if ($ContextScopes) {
    $contextInstrumentation = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'context-scopes.sqf'))
    $header += "IVCS_Perf_ContextMode = true;`r`n$contextInstrumentation`r`n"
}
if ($OperationScopes) {
    $instrumentation = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'operation-scopes.sqf'))
    $header += "IVCS_Perf_InstallOperationScopes = {`r`n$instrumentation`r`n};`r`n"
}
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'performance.sqf'))
if (!$ProfilerMarkers) {
    # Arma parses command names in inactive code blocks too. Remove the literal
    # profiler-only block so the vanilla server does not require profiler commands.
    $scopeStart = $source.IndexOf("`nif (_profiling) then {")
    $scopeEnd = $source.IndexOf('IVCS_VirtualSpace_Controller =', $scopeStart)
    if ($scopeStart -lt 0 -or $scopeEnd -lt 0) { throw 'Profiler block anchors changed.' }
    $scopeStart++ # Preserve the preceding CRLF.
    $source = $source.Remove($scopeStart,$scopeEnd - $scopeStart)
}

[IO.File]::WriteAllText($taskScript,$header + ($source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
try {
    & (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds $TimeoutSeconds -ExtraArguments $ExtraArguments
} finally {
    Remove-Item -LiteralPath $taskScript -ErrorAction SilentlyContinue
}
