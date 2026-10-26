param(
    [ValidateRange(5,300)][int]$Seconds = 20,
    [ValidateRange(1,10)][int]$Trials = 2,
    [int[]]$GroupCounts = @(20),
    [ValidateRange(0,60)][int]$WarmupSeconds = 2,
    [int]$PostDelaySeconds = 0,
    [int]$StartupDelaySeconds = 0,
    [switch]$ProfilerMarkers,
    [switch]$ReturnFireComparison,
    [switch]$OperationScopes,
    [switch]$ContextScopes,
    [ValidateRange(-1,100)][double]$CombatBudgetMs = -1,
    [int]$Port = 2502,
    [int]$TimeoutSeconds = 900,
    [string[]]$ExtraArguments = @()
)
$ErrorActionPreference = 'Stop'
foreach ($count in $GroupCounts) {
    if ($count -lt 1) { throw 'Each count must be positive (one attacking squad and one crew group per engagement).' }
}
if ($ContextScopes) { $OperationScopes = $true }
if ($OperationScopes) { $ProfilerMarkers = $true }
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-combat-performance-' + [guid]::NewGuid().ToString('N') + '.sqf')
$markerFlag = if ($ProfilerMarkers) { 'true' } else { 'false' }
$budgetFlag = $CombatBudgetMs.ToString([Globalization.CultureInfo]::InvariantCulture)
$header = "IVCS_Perf_BudgetMs = $budgetFlag;`r`nIVCS_Perf_Profiler = $markerFlag;`r`nIVCS_Perf_Seconds = $Seconds;`r`nIVCS_Perf_Trials = $Trials;`r`nIVCS_Perf_Sizes = [$($GroupCounts -join ',')];`r`nIVCS_Perf_Warmup = $WarmupSeconds;`r`nIVCS_Perf_PostDelay = $PostDelaySeconds;`r`nIVCS_Perf_StartupDelay = $StartupDelaySeconds;`r`n"
if ($ContextScopes) {
    $contextInstrumentation = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'context-scopes.sqf'))
    $header += "IVCS_Perf_ContextMode = true;`r`n$contextInstrumentation`r`n"
}
if ($OperationScopes) {
    $instrumentation = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'operation-scopes.sqf'))
    $header += "IVCS_Perf_InstallOperationScopes = {`r`n$instrumentation`r`n};`r`n"
}
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'vehicle-performance.sqf'))
if (!$ProfilerMarkers) {
    # Arma parses command names in inactive code blocks too. Remove the literal
    # profiler-only block so the vanilla server does not require profiler commands.
    $scopeStart = $source.IndexOf("`nif (_profiling) then {")
    $scopeEnd = $source.IndexOf('IVCS_VirtualSpace_Controller =', $scopeStart)
    if ($scopeStart -lt 0 -or $scopeEnd -lt 0) { throw 'Profiler block anchors changed.' }
    $scopeStart++ # Preserve the preceding CRLF.
    $source = $source.Remove($scopeStart,$scopeEnd - $scopeStart)
}

$baselineNames = @('update','stepVehicle','getVehicleShot','damageVehicle')
$baselinePairs = foreach ($name in $baselineNames) {
    $baselinePath = if ($ReturnFireComparison) { Join-Path $PSScriptRoot ('..\..\VirtualSpace\functions\combat\' + $name + '.sqf') } else { Join-Path $PSScriptRoot ('vehicle-baseline\' + $name + '.sqf') }
    $body = [IO.File]::ReadAllText($baselinePath)
    if ($ReturnFireComparison -and $name -eq 'stepVehicle') {
        $returnCall = '[_engagement,_infantry,_vehicle,_range,_dt] call IVCS_Combat_stepReturnFire;'
        if (!$body.Contains($returnCall)) { throw 'Return-fire comparison anchor changed.' }
        $body = $body.Replace($returnCall,'')
    }
    '["IVCS_Combat_' + $name + '",{' + $body + '}]'
}
if ($ReturnFireComparison) { $header += "IVCS_Perf_ReturnFireComparison = true;`r`n" }
$header += "IVCS_Perf_VehicleBefore = createHashMapFromArray [" + ($baselinePairs -join ',') + "];`r`n"
$source = $source.Replace('private _before=createHashMap;', 'private _before=IVCS_Perf_VehicleBefore;')
$baselineLoopStart = $source.IndexOf('{_before set [')
$baselineLoopEnd = $source.IndexOf('private _oldUnregister=', $baselineLoopStart)
if ($baselineLoopStart -lt 0 -or $baselineLoopEnd -lt 0) { throw 'Baseline loader anchors changed.' }
$source = $source.Remove($baselineLoopStart,$baselineLoopEnd-$baselineLoopStart)
[IO.File]::WriteAllText($taskScript,$header + ($source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
try {
    & (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds $TimeoutSeconds -ExtraArguments $ExtraArguments
} finally {
    Remove-Item -LiteralPath $taskScript -ErrorAction SilentlyContinue
}
