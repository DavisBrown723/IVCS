param(
    [Parameter(Mandatory=$true)][string]$BaselineUpdateRequests,
    [ValidateRange(10,60)][int]$Seconds = 20,
    [int]$StartupDelaySeconds = 40,
    [int]$PostDelaySeconds = 20,
    [int]$Port = 2517,
    [switch]$Unprofiled,
    [string[]]$ExtraArguments = @()
)
$ErrorActionPreference = 'Stop'
# Before/after/after/before with the same budget, scopes and adjacent-trial seeds.
$baseline = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $BaselineUpdateRequests).Path)
# compile operates on preprocessed SQF; remove standalone source comments.
$baseline = $baseline -replace '(?m)^\s*//[^\r\n]*',''
$header = 'IVCS_Perf_ArrivalBaselineSource = "' + $baseline.Replace('"','""') + '";' + "`r`n"
$scopesFlag = if ($Unprofiled) { 'false' } else { 'true' }
$header += "IVCS_Perf_CombatOnly = true; IVCS_Perf_AmmoPressure = true; IVCS_Perf_IncludeAmmoPressure = false; IVCS_Perf_BudgetMs = -1; IVCS_Perf_Profiler = $scopesFlag; IVCS_Perf_ContextMode = $scopesFlag; IVCS_Perf_Seconds = $Seconds; IVCS_Perf_Trials = 4; IVCS_Perf_Sizes = [20,80]; IVCS_Perf_Warmup = 2; IVCS_Perf_StartupDelay = $StartupDelaySeconds; IVCS_Perf_PostDelay = $PostDelaySeconds;`r`n"
if (!$Unprofiled) {
$header += [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'context-scopes.sqf')) + "`r`n"
$instrumentation = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'operation-scopes.sqf'))
$instrumentation += @'
IVCS_Perf_ArrivalAfter = IVCS_Perf_OperationOriginal_IVCS_Ammo_updateRequests;
private _source = IVCS_Perf_ArrivalBaselineSource;
_source = [_source,"private _request = _x;",'private _requestScope = createProfileScope "IVCS_OP_PendingRequest"; private _request = _x;'] call _replaceOnce;
_source = ["IVCS_Ammo_updateRequests",_source] call IVCS_Perf_ContextSource;
IVCS_Perf_ArrivalBefore = compile _source;
'@
$header += "IVCS_Perf_InstallOperationScopes = {`r`n$instrumentation`r`n};`r`n"
}
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'performance.sqf'))
$anchor = 'for "_trial" from 1 to _trials do {'
if (($source.Split(@($anchor),[StringSplitOptions]::None)).Count -ne 2) { throw 'Trial anchor changed.' }
$target = 'IVCS_Perf_OperationOriginal_IVCS_Ammo_updateRequests'
if ($Unprofiled) {
    $target = 'IVCS_Ammo_updateRequests'
    # Unknown mod commands are parsed even inside a disabled code block.
    # Remove the complete profiler branch for a truly mod-free measurement.
    $scopeStart = $source.IndexOf("`nif (_profiling) then {")
    $scopeEnd = $source.IndexOf('IVCS_VirtualSpace_Controller =', $scopeStart)
    if ($scopeStart -lt 0 -or $scopeEnd -lt 0) { throw 'Profiler block anchors changed.' }
    $source = $source.Remove($scopeStart,$scopeEnd - $scopeStart)
    $initAnchor = 'call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";'
    $source = $source.Replace($initAnchor,$initAnchor + "`r`nIVCS_Perf_ArrivalAfter = IVCS_Ammo_updateRequests; IVCS_Perf_ArrivalBefore = compile IVCS_Perf_ArrivalBaselineSource;")
}
$trialSource = @'
    private _before = _trial in [1,4];
    IVCS_Perf_OperationOriginal_IVCS_Ammo_updateRequests = if (_before) then { IVCS_Perf_ArrivalBefore } else { IVCS_Perf_ArrivalAfter };
    diag_log format ["[IVCS ARRIVAL] IMPLEMENTATION trial=%1 version=%2",_trial,if (_before) then { "before" } else { "after" }];
'@
$trialSource = $trialSource.Replace('IVCS_Perf_OperationOriginal_IVCS_Ammo_updateRequests',$target)
$source = $source.Replace($anchor,$anchor + $trialSource)
$source = $source.Replace('1000 * _trial + _i + 1','1000 * ceil (_trial / 2) + _i + 1')
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-arrival-comparison-' + [guid]::NewGuid().ToString('N') + '.sqf')
[IO.File]::WriteAllText($taskScript,($header + $source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
Write-Output ('Comparison script: ' + $taskScript)
Write-Output ('Baseline SHA256: ' + (Get-FileHash -LiteralPath $BaselineUpdateRequests -Algorithm SHA256).Hash)
# Retain the generated script with the capture evidence for exact reproduction.
& (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds 600 -ExtraArguments $ExtraArguments
