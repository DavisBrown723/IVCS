param(
    [Parameter(Mandatory=$true)][string]$BaselineDirectory,
    [ValidateRange(10,60)][int]$Seconds = 20,
    [int]$StartupDelaySeconds = 40,
    [int]$PostDelaySeconds = 20,
    [int]$Port = 2527,
    [switch]$Unprofiled,
    [string[]]$ExtraArguments = @()
)
$ErrorActionPreference = 'Stop'
# Before/after/after/before with the same budget, scopes and adjacent-trial seeds.
$header = "IVCS_Perf_SharingSources = createHashMap;`r`n"
$functions = @('surplus','getNeededWeapons','updateGroup','advanceSearch','snapshot','updateRequests')
foreach ($name in $functions) {
    $path = Join-Path $BaselineDirectory ($name + '.sqf')
    $baseline = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path) -replace '(?m)^\s*//[^\r\n]*',''
    # Keep archived algorithm comparisons on the same current clock as production.
    $baseline = $baseline.Replace('(IVCS_VirtualSpace_Controller get "combat") get "clock"','IVCS_SimulationTime')
    $header += 'IVCS_Perf_SharingSources set ["IVCS_Ammo_' + $name + '","' + $baseline.Replace('"','""') + '"];' + "`r`n"
}
$scopesFlag = if ($Unprofiled) { 'false' } else { 'true' }
$header += "IVCS_Perf_CombatOnly = true; IVCS_Perf_AmmoPressure = true; IVCS_Perf_IncludeAmmoPressure = false; IVCS_Perf_BudgetMs = -1; IVCS_Perf_Profiler = $scopesFlag; IVCS_Perf_ContextMode = $scopesFlag; IVCS_Perf_Seconds = $Seconds; IVCS_Perf_Trials = 4; IVCS_Perf_Sizes = [20,80]; IVCS_Perf_Warmup = 2; IVCS_Perf_StartupDelay = $StartupDelaySeconds; IVCS_Perf_PostDelay = $PostDelaySeconds;`r`n"
if (!$Unprofiled) {
$header += [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'context-scopes.sqf')) + "`r`n"
$instrumentation = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'operation-scopes.sqf'))
$instrumentation += @'
IVCS_Perf_SharingBefore = createHashMap;
IVCS_Perf_SharingAfter = createHashMap;
{
    private _function = _x;
    private _source = IVCS_Perf_SharingSources get _function;
    switch (_function) do {
        case "IVCS_Ammo_updateGroup": {
            _source = [_source,"isNil {",'isNil { private _operationScope = createProfileScope "IVCS_OP_AmmoScan";'] call _replaceOnce;
            _source = [_source,'if ((_entity get "ammoSearch") isEqualTo []) then {','if ((_entity get "ammoSearch") isEqualTo []) then { private _needsScope = createProfileScope "IVCS_OP_AmmoNeedsScan";'] call _replaceOnce;
        };
        case "IVCS_Ammo_updateRequests": {
            _source = [_source,"private _request = _x;",'private _requestScope = createProfileScope "IVCS_OP_PendingRequest"; private _request = _x;'] call _replaceOnce;
        };
        case "IVCS_Ammo_advanceSearch": {
            _source = [_source,'private _native = _job get "native";','private _operationScope = createProfileScope "IVCS_OP_DonorSlice"; private _native = _job get "native";'] call _replaceOnce;
            _source = [_source,'params ["_donor","_compatible"];','params ["_donor","_compatible"]; private _donorScope = createProfileScope "IVCS_OP_DonorInventory";'] call _replaceOnce;
            _source = [_source,'private _hadCandidate = _best isNotEqualTo [];','private _hadCandidate = _best isNotEqualTo []; call { private _winnerScope = createProfileScope "IVCS_OP_WinnerRevalidation";'] call _replaceOnce;
            _source = [_source,'if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;', '}; if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;'] call _replaceOnce;
        };
    };
    _source = [_function,_source] call IVCS_Perf_ContextSource;
    IVCS_Perf_SharingBefore set [_function,compile _source];
    IVCS_Perf_SharingAfter set [_function,missionNamespace getVariable ("IVCS_Perf_OperationOriginal_" + _function)];
} forEach keys IVCS_Perf_SharingSources;
'@
$header += "IVCS_Perf_InstallOperationScopes = {`r`n$instrumentation`r`n};`r`n"
}
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'performance.sqf'))
$anchor = 'for "_trial" from 1 to _trials do {'
if (($source.Split(@($anchor),[StringSplitOptions]::None)).Count -ne 2) { throw 'Trial anchor changed.' }
if ($Unprofiled) {
    $scopeStart = $source.IndexOf("`nif (_profiling) then {")
    if ($scopeStart -lt 0) { throw 'Profiler block start changed.' }
    $scopeEnd = $source.IndexOf('IVCS_VirtualSpace_Controller =', $scopeStart)
    if ($scopeEnd -lt 0) { throw 'Profiler block end changed.' }
    $source = $source.Remove($scopeStart,$scopeEnd - $scopeStart)
    $initAnchor = 'call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";'
    $init = @'
IVCS_Perf_SharingBefore = createHashMap;
IVCS_Perf_SharingAfter = createHashMap;
{
    IVCS_Perf_SharingBefore set [_x,compile (IVCS_Perf_SharingSources get _x)];
    IVCS_Perf_SharingAfter set [_x,missionNamespace getVariable _x];
} forEach keys IVCS_Perf_SharingSources;
'@
    $source = $source.Replace($initAnchor,$initAnchor + "`r`n" + $init)
}
$trialSource = @'
    private _before = _trial in [1,4];
    {
        private _destination = if (IVCS_Perf_Profiler) then { "IVCS_Perf_OperationOriginal_" + _x } else { _x };
        missionNamespace setVariable [_destination,(if (_before) then { IVCS_Perf_SharingBefore } else { IVCS_Perf_SharingAfter }) get _x];
    } forEach keys IVCS_Perf_SharingSources;
    diag_log format ["[IVCS SHARING] IMPLEMENTATION trial=%1 version=%2",_trial,if (_before) then { "before" } else { "after" }];
'@
$source = $source.Replace($anchor,$anchor + $trialSource)
$source = $source.Replace('1000 * _trial + _i + 1','1000 * ceil (_trial / 2) + _i + 1')
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-sharing-comparison-' + [guid]::NewGuid().ToString('N') + '.sqf')
[IO.File]::WriteAllText($taskScript,($header + $source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
Write-Output ('Comparison script: ' + $taskScript)
foreach ($name in $functions) { Write-Output ($name + ' baseline SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $BaselineDirectory ($name + '.sqf')) -Algorithm SHA256).Hash) }
# Retain the generated script with the capture evidence for exact reproduction.
& (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds 600 -ExtraArguments $ExtraArguments
