param(
    [Parameter(Mandatory=$true)][string]$BaselineDirectory,
    [ValidateRange(10,60)][int]$Seconds = 30,
    [int[]]$GroupCounts = @(20),
    [int]$Port = 2554,
    [switch]$AmmoPressure,
    [switch]$ProfilerMarkers,
    [int]$StartupDelaySeconds = 0,
    [int]$PostDelaySeconds = 0,
    [string[]]$ExtraArguments = @()
)
$ErrorActionPreference = 'Stop'
$functions = @('updateGroup','advanceSearch','getNeededWeapons')
$header = "IVCS_Perf_NeedsBefore = createHashMap;`r`n"
foreach ($name in $functions) {
    $path = Join-Path $BaselineDirectory ($name + '.sqf')
    $baseline = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path) -replace '(?m)^\s*//[^\r\n]*',''
    # Keep archived algorithm comparisons on the same current clock as production.
    $baseline = $baseline.Replace('(IVCS_VirtualSpace_Controller get "combat") get "clock"','IVCS_SimulationTime')
    if ($ProfilerMarkers) {
        $anchors = @()
        if ($name -eq 'updateGroup') {
            $anchors = @(
                @('isNil {','isNil { private _operationScope = createProfileScope "IVCS_OP_AmmoScan";'),
                @('if ((_entity get "ammoSearch") isEqualTo []) then {','if ((_entity get "ammoSearch") isEqualTo []) then { private _needsScope = createProfileScope "IVCS_OP_AmmoNeedsScan";')
            )
        } elseif ($name -eq 'advanceSearch') {
            $anchors = @(
                @('private _native = _job get "native";','private _operationScope = createProfileScope "IVCS_OP_DonorSlice"; private _native = _job get "native";'),
                @('params ["_donor","_compatible"];','params ["_donor","_compatible"]; private _donorScope = createProfileScope "IVCS_OP_DonorInventory";'),
                @('private _hadCandidate = _best isNotEqualTo [];','private _hadCandidate = _best isNotEqualTo []; call { private _winnerScope = createProfileScope "IVCS_OP_WinnerRevalidation";'),
                @('if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;', '}; if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;')
            )
        }
        foreach ($pair in $anchors) {
            if (($baseline.Split(@($pair[0]),[StringSplitOptions]::None)).Count -ne 2) { throw ('Baseline scope anchor changed: ' + $pair[0]) }
            $baseline = $baseline.Replace($pair[0],$pair[1])
        }
    }
    $header += 'IVCS_Perf_NeedsBefore set ["IVCS_Ammo_' + $name + '",compile "' + $baseline.Replace('"','""') + '"];' + "`r`n"
}
$pressure = if ($AmmoPressure) { 'true' } else { 'false' }
$markers = if ($ProfilerMarkers) { 'true' } else { 'false' }
$header += "IVCS_Perf_CombatOnly = true; IVCS_Perf_AmmoPressure = $pressure; IVCS_Perf_IncludeAmmoPressure = false; IVCS_Perf_BudgetMs = -1; IVCS_Perf_Profiler = $markers; IVCS_Perf_StartupDelay = $StartupDelaySeconds; IVCS_Perf_PostDelay = $PostDelaySeconds; IVCS_Perf_Seconds = $Seconds; IVCS_Perf_Trials = 4; IVCS_Perf_Sizes = [$($GroupCounts -join ',')]; IVCS_Perf_Warmup = 2;`r`n"
if ($ProfilerMarkers) {
    $scopes = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'operation-scopes.sqf'))
    $header += "IVCS_Perf_InstallOperationScopes = {`r`n$scopes`r`n};`r`n"
}
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'performance.sqf'))
if (!$ProfilerMarkers) {
    $scopeStart = $source.IndexOf("`nif (_profiling) then {")
    $scopeEnd = $source.IndexOf('IVCS_VirtualSpace_Controller =', $scopeStart)
    if ($scopeStart -lt 0 -or $scopeEnd -lt 0) { throw 'Profiler anchors changed.' }
    $source = $source.Remove($scopeStart,$scopeEnd - $scopeStart)
}
$anchor = 'IVCS_Perf_OriginalStep = IVCS_Combat_step;'
if (($source.Split(@($anchor),[StringSplitOptions]::None)).Count -ne 2) { throw 'Step anchor changed.' }
$source = $source.Replace($anchor,'IVCS_Perf_NeedsAfter = createHashMap; { IVCS_Perf_NeedsAfter set [_x,missionNamespace getVariable ["IVCS_Perf_OperationOriginal_" + _x,missionNamespace getVariable _x]]; } forEach keys IVCS_Perf_NeedsBefore;' + "`r`n" + $anchor)
$anchor = 'for "_trial" from 1 to _trials do {'
if (($source.Split(@($anchor),[StringSplitOptions]::None)).Count -ne 2) { throw 'Trial anchor changed.' }
$trialSource = @'
    private _before = _trial in [1,4];
    private _functions = if (_before) then { IVCS_Perf_NeedsBefore } else { IVCS_Perf_NeedsAfter };
    {
        private _destination = if (IVCS_Perf_Profiler) then { "IVCS_Perf_OperationOriginal_" + _x } else { _x };
        missionNamespace setVariable [_destination,_functions get _x];
    } forEach keys _functions;
    diag_log format ["[IVCS NEEDS] IMPLEMENTATION trial=%1 version=%2",_trial,if (_before) then { "before" } else { "after" }];
'@
$source = $source.Replace($anchor,$anchor + $trialSource)
$source = $source.Replace('1000 * _trial + _i + 1','1000 * ceil (_trial / 2) + _i + 1')
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-needs-comparison-' + [guid]::NewGuid().ToString('N') + '.sqf')
[IO.File]::WriteAllText($taskScript,($header + $source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
Write-Output ('Comparison script: ' + $taskScript)
& (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds 600 -ExtraArguments $ExtraArguments
