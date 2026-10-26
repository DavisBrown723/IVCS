param(
    [Parameter(Mandatory=$true)][string]$BaselineDirectory,
    [ValidateRange(10,60)][int]$Seconds = 30,
    [int]$Port = 2540,
    [string[]]$CompareFunctions = @('step','getShot'),
    [double]$BeforeStep = -1,
    [switch]$AmmoPressure,
    [switch]$ReverseOrder,
    [switch]$ProfilerMarkers,
    [int]$StartupDelaySeconds = 0,
    [int]$PostDelaySeconds = 0,
    [string[]]$ExtraArguments = @()
)
$ErrorActionPreference = 'Stop'
$header = "IVCS_Perf_ShotBefore = createHashMap;`r`n"
foreach ($name in $CompareFunctions) {
    $path = Join-Path $BaselineDirectory ($name + '.sqf')
    $baseline = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path) -replace '(?m)^\s*//[^\r\n]*',''
    if ($ProfilerMarkers -and $name -eq 'step') {
        $anchors = @(
            @('private _unit = _x;','private _unitScope = createProfileScope "IVCS_OP_ShooterVisit"; private _unit = _x;'),
            @('private _factorState =','call { private _operationScope = createProfileScope "IVCS_OP_ShotPreparation"; private _factorState ='),
            @('_engagement set ["hits",','}; call { private _operationScope = createProfileScope "IVCS_OP_DamageApplication"; _engagement set ["hits",'),
            @('{ _x call IVCS_Combat_damageUnit; } forEach _hits;','{ _x call IVCS_Combat_damageUnit; } forEach _hits; }; call { private _operationScope = createProfileScope "IVCS_OP_CasualtyCleanup";'),
            @('_engagement set ["elapsed",','}; _engagement set ["elapsed",')
        )
        if ($baseline.Contains('private _armDamage = 0;')) {
            $anchors += @(
                @('private _armDamage = 0;','private _accuracy = call { private _accuracyScope = createProfileScope "IVCS_OP_Accuracy"; private _armDamage = 0;'),
                @('private _accuracy = (((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8;', '(((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8; };')
            )
        }
        foreach ($pair in $anchors) {
            if (($baseline.Split(@($pair[0]),[StringSplitOptions]::None)).Count -ne 2) { throw ('Baseline scope anchor changed: ' + $pair[0]) }
            $baseline = $baseline.Replace($pair[0],$pair[1])
        }
    }
    $header += 'IVCS_Perf_ShotBefore set ["IVCS_Combat_' + $name + '",compile "' + $baseline.Replace('"','""') + '"];' + "`r`n"
}
$pressure = if ($AmmoPressure) { 'true' } else { 'false' }
$markers = if ($ProfilerMarkers) { 'true' } else { 'false' }
$header += "IVCS_Perf_CombatOnly = true; IVCS_Perf_AmmoPressure = $pressure; IVCS_Perf_IncludeAmmoPressure = false; IVCS_Perf_BudgetMs = -1; IVCS_Perf_Profiler = $markers; IVCS_Perf_StartupDelay = $StartupDelaySeconds; IVCS_Perf_PostDelay = $PostDelaySeconds; IVCS_Perf_Seconds = $Seconds; IVCS_Perf_Trials = 4; IVCS_Perf_Sizes = [20]; IVCS_Perf_Warmup = 2;`r`n"
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
$entries = foreach ($name in $CompareFunctions) {
    if ($name -eq 'step') { '["IVCS_Combat_step",IVCS_Combat_step]' } else {
        '["IVCS_Combat_' + $name + '",missionNamespace getVariable ["IVCS_Perf_OperationOriginal_IVCS_Combat_' + $name + '",IVCS_Combat_' + $name + ']]'
    }
}
$source = $source.Replace($anchor,'IVCS_Perf_ShotAfter = createHashMapFromArray [' + ($entries -join ',') + ']; IVCS_Perf_CompareFunctions = ' + ('["' + (($CompareFunctions | ForEach-Object { 'IVCS_Combat_' + $_ }) -join '","') + '"]') + ';' + "`r`n" + $anchor)
$anchor = 'for "_trial" from 1 to _trials do {'
if (($source.Split(@($anchor),[StringSplitOptions]::None)).Count -ne 2) { throw 'Trial anchor changed.' }
$trialSource = @'
    if (_trial == 1) then { IVCS_Perf_AfterStep = _combat get "step"; };
    private _before = _trial in [1,4];
    private _functions = if (_before) then { IVCS_Perf_ShotBefore } else { IVCS_Perf_ShotAfter };
    IVCS_Perf_OriginalStep = _functions get "IVCS_Combat_step";
    {
        if (_x != "IVCS_Combat_step") then {
            private _saved = "IVCS_Perf_OperationOriginal_" + _x;
            private _destination = if (IVCS_Perf_Profiler && { !isNil { missionNamespace getVariable _saved } }) then { _saved } else { _x };
            missionNamespace setVariable [_destination,_functions get _x];
        };
    } forEach IVCS_Perf_CompareFunctions;
    diag_log format ["[IVCS SHOT] IMPLEMENTATION trial=%1 version=%2",_trial,if (_before) then { "before" } else { "after" }];
'@
if ($BeforeStep -ge 0) {
    $trialSource += '_combat set ["step",if (_before) then { ' + $BeforeStep.ToString([Globalization.CultureInfo]::InvariantCulture) + ' } else { IVCS_Perf_AfterStep }];' + "`r`n"
}
if ($ReverseOrder) { $trialSource = $trialSource.Replace("_trial in [1,4]","_trial in [2,3]") }
$source = $source.Replace($anchor,$anchor + $trialSource)
$source = $source.Replace('1000 * _trial + _i + 1','1000 * ceil (_trial / 2) + _i + 1')
$taskScript = Join-Path ([IO.Path]::GetTempPath()) ('ivcs-shot-comparison-' + [guid]::NewGuid().ToString('N') + '.sqf')
[IO.File]::WriteAllText($taskScript,($header + $source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
Write-Output ('Comparison script: ' + $taskScript)
& (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $taskScript -Port $Port -TimeoutSeconds 400 -ExtraArguments $ExtraArguments
