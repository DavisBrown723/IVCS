param(
    [ValidateRange(5,120)][int]$Seconds=35,
    [ValidateRange(1,5)][int]$Trials=2,
    [ValidateRange(0,10)][int]$WarmupSeconds=2,
    [string[]]$Modes=@('heli-idle','heli-infantry','heli-infantry-aa','heli-vehicle-aa'),
    [string]$BaselineDirectory,
    [string]$ShotBaselineDirectory,
    [string]$AdmissionBaselineDirectory,
    [switch]$ShotDiagnostics,
    [switch]$EntityDiagnostics,
    [switch]$FlightDiagnostics,
    [switch]$ResolutionDiagnostics,
    [switch]$ExchangeDiagnostics,
    [switch]$TimingCanaries,
    [switch]$ReverseComparison,
    [switch]$ProfilerMarkers,
    [int]$StartupDelaySeconds=0,
    [int]$PostDelaySeconds=0,
    [int]$Port=2502,
    [string[]]$ExtraArguments=@()
)
$ErrorActionPreference='Stop'
$timingMutex=[Threading.Mutex]::new($false,'Local\IVCS_Combat_Timing')
try {$timingOwned=$timingMutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$timingOwned=$true}
if (!$timingOwned) {$timingMutex.Dispose();throw 'Another IVCS benchmark or analysis is active.'}
try {
$allowed=@('heli-idle','heli-infantry','heli-infantry-aa','heli-vehicle-aa')
foreach ($mode in $Modes) { if ($mode -notin $allowed) { throw "Unknown scenario: $mode" } }
$profile=if ($ProfilerMarkers) {'true'} else {'false'}
$modeArray='["'+($Modes -join '","')+'"]'
$header="IVCS_Perf_Profiler=$profile; IVCS_Perf_Seconds=$Seconds; IVCS_Perf_Trials=$Trials; IVCS_Perf_Warmup=$WarmupSeconds; IVCS_HeliPerf_Modes=$modeArray; IVCS_Perf_StartupDelay=$StartupDelaySeconds; IVCS_Perf_PostDelay=$PostDelaySeconds;`r`n"
$header+='IVCS_HeliPerf_ReverseOrder=' + $(if ($ReverseComparison) {'true'} else {'false'})+';'+[Environment]::NewLine
if (@(@($BaselineDirectory,$ShotBaselineDirectory,$AdmissionBaselineDirectory) | Where-Object {$_}).Count -gt 1) {throw 'Select one comparison baseline.'}
if ($BaselineDirectory -or $ShotBaselineDirectory -or $AdmissionBaselineDirectory) {
    if ($Trials -ne 4) {throw 'Comparison requires four ABBA trials.'}
    if ($ShotDiagnostics) {throw 'Detailed diagnostic counters cannot be combined with performance comparison.'}
    if ($AdmissionBaselineDirectory) {
        $directory=$AdmissionBaselineDirectory; $file='findTarget.sqf'; $function='IVCS_Combat_findTarget'
    } elseif ($ShotBaselineDirectory) {
        $directory=$ShotBaselineDirectory; $file='getVehicleShot.sqf'; $function='IVCS_Combat_getVehicleShot'
    } else {
        $directory=$BaselineDirectory; $file='canShootHelicopter.sqf'; $function='IVCS_Combat_canShootHelicopter'
    }
    $manifest=Get-Content (Join-Path $directory 'manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.functions) {$entries=@($manifest.functions)} else {$entries=,@($file,$function)}
    $overrides=@()
    foreach ($entry in $entries) {
        $file=$entry[0];$function=$entry[1]
        $baselinePath=Join-Path $directory $file
        if ((Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash -ne $manifest.$file) {throw 'Comparison baseline hash mismatch.'}
        $baseline=[IO.File]::ReadAllText($baselinePath).Replace("'","''")
        $livePath=Join-Path $PSScriptRoot ('../../VirtualSpace/functions/combat/'+$file)
        $current=[IO.File]::ReadAllText($livePath).Replace("'","''")
        if ($manifest.identical_code_control -and (Get-FileHash -LiteralPath $livePath -Algorithm SHA256).Hash -ne $manifest.$file) {throw 'Identical-code baseline does not match current source.'}
        $overrides+="['$function',compile '$baseline',compile '$current']"
    }
    $header+='IVCS_HeliPerf_Baselines=['+($overrides -join ',')+'];'+[Environment]::NewLine
    $header+='IVCS_HeliPerf_IdenticalControl='+$(if ($manifest.identical_code_control) {'true'} else {'false'})+';'+[Environment]::NewLine
}
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'helicopter-performance.sqf'))
if (!$ProfilerMarkers) {
    $start=$source.IndexOf("`nif (_profiling) then {")
    $end=$source.IndexOf('IVCS_VirtualSpace_Controller =',$start)
    if ($start -lt 0 -or $end -lt 0) {throw 'Profiler anchors changed.'}
    $source=$source.Remove($start,$end-$start)
}
if ($ShotDiagnostics) {
    if (!$ProfilerMarkers) {throw 'Shot diagnostics require profiler markers.'}
    $diagnostics=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'shot-selection-scopes.sqf')).Replace("'","''")
    $header+="IVCS_Perf_InstallOperationScopes=compile '$diagnostics';`r`n"
    $anchor='IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;'
    $flush='IVCS_ShotDiag_Frame=IVCS_VirtualSpace_onFrame;
IVCS_VirtualSpace_onFrame={
    IVCS_ShotDiag_Rows=[];
    [] call IVCS_ShotDiag_Frame;
    if (IVCS_Perf_Recording) then {
        for "_row" from 0 to (count IVCS_ShotDiag_Rows-1) step 2 do {profilerLog format ["IVCS SHOT WORK %1",IVCS_ShotDiag_Rows select [_row,2]]};
    };
};'
    if (!$source.Contains($anchor)) {throw 'Frame diagnostic anchor changed.'}
    $source=$source.Replace($anchor,$flush+"`r`n"+$anchor)
}
if ($EntityDiagnostics) {
    if (!$ProfilerMarkers -or $ShotDiagnostics -or $BaselineDirectory -or $ShotBaselineDirectory -or $AdmissionBaselineDirectory) {throw 'Entity diagnostics require standalone profiler run.'}
    $diagnostics=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'entity-scopes.sqf')).Replace("'","''")
    $header+="IVCS_Perf_InstallOperationScopes=compile '$diagnostics';`r`n"
}
if ($FlightDiagnostics) {
    if (!$ProfilerMarkers -or $ShotDiagnostics -or $EntityDiagnostics -or $BaselineDirectory -or $ShotBaselineDirectory -or $AdmissionBaselineDirectory) {throw 'Flight diagnostics require standalone profiler run.'}
    $diagnostics=([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'entity-scopes.sqf'))+[Environment]::NewLine+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'flight-scopes.sqf'))).Replace("'","''")
    $header+="IVCS_Perf_InstallOperationScopes=compile '$diagnostics';"+[Environment]::NewLine
    $anchor='IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;'
    $flush='IVCS_FlightDiag_Frame=IVCS_VirtualSpace_onFrame;
IVCS_VirtualSpace_onFrame={
    IVCS_FlightDiag_Rows=[];
    [] call IVCS_FlightDiag_Frame;
    if (IVCS_Perf_Recording) then {
        for "_row" from 0 to (count IVCS_FlightDiag_Rows-1) step 2 do {profilerLog format ["IVCS FLIGHT WORK %1",IVCS_FlightDiag_Rows select [_row,2]]};
    };
};'
    if (!$source.Contains($anchor)) {throw 'Flight diagnostic frame anchor changed.'}
    $source=$source.Replace($anchor,$flush+[Environment]::NewLine+$anchor)
}
if ($ResolutionDiagnostics -or $ExchangeDiagnostics) {
    if (!$ProfilerMarkers -or $ShotDiagnostics -or $EntityDiagnostics -or $FlightDiagnostics -or $BaselineDirectory -or $ShotBaselineDirectory -or $AdmissionBaselineDirectory) {throw 'Resolution diagnostics require standalone profiler run.'}
    $diagnostics=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'resolution-scopes.sqf'))
    if ($ExchangeDiagnostics) {$diagnostics+=[Environment]::NewLine+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'exchange-scopes.sqf'))}
    $diagnostics=$diagnostics.Replace("'","''")
    $header+="IVCS_Perf_InstallOperationScopes=compile '$diagnostics';"+[Environment]::NewLine
    $anchor='IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;'
    $flush='IVCS_ResolutionDiag_Frame=IVCS_VirtualSpace_onFrame;
IVCS_VirtualSpace_onFrame={
    IVCS_ResolutionDiag_Rows=[];
    [] call IVCS_ResolutionDiag_Frame;
    if (IVCS_Perf_Recording) then {
        for "_row" from 0 to (count IVCS_ResolutionDiag_Rows-1) step 3 do {profilerLog format ["IVCS RES WORK %1",IVCS_ResolutionDiag_Rows select [_row,3]]};
    };
};'
    if (!$source.Contains($anchor)) {throw 'Resolution diagnostic frame anchor changed.'}
    $source=$source.Replace($anchor,$flush+[Environment]::NewLine+$anchor)
}
if ($TimingCanaries) {
    if (!$ProfilerMarkers -or $ShotDiagnostics -or $EntityDiagnostics -or $FlightDiagnostics -or $ResolutionDiagnostics -or $ExchangeDiagnostics) {throw 'Timing canaries require a standalone profiler control.'}
    $anchor='IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;'
    $canaries=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'timing-canaries.sqf'))
    if (!$source.Contains($anchor)) {throw 'Timing canary frame anchor changed.'}
    $source=$source.Replace($anchor,$canaries+[Environment]::NewLine+$anchor)
}
$script=Join-Path ([IO.Path]::GetTempPath()) ('ivcs-helicopter-performance-'+[guid]::NewGuid().ToString('N')+'.sqf')
[IO.File]::WriteAllText($script,($header+$source -replace '\r?\n',"`r`n"),[Text.UTF8Encoding]::new($false))
try {
    & (Join-Path $PSScriptRoot '..\tasks\run.ps1') -TestScript $script -Port $Port -TimeoutSeconds 900 -ExtraArguments $ExtraArguments
} finally { Remove-Item -LiteralPath $script -ErrorAction SilentlyContinue }

} finally {if ($timingOwned) {$timingMutex.ReleaseMutex()};$timingMutex.Dispose()}
