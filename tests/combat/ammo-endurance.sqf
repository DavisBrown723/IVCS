// Run: powershell -File tests/tasks/run.ps1 -TestScript tests/combat/ammo-endurance.sqf -Port 2495 -TimeoutSeconds 600
// Standard NATO/CSAT squads at 200 m. BLU_F is immune to virtual damage;
// OPF_F fires normally and is replaced immediately after elimination.
// Advance the production resolver's simulation-time argument synthetically.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Ammo_TestPassed = 0;
IVCS_Ammo_TestFailed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_Ammo_TestPassed = IVCS_Ammo_TestPassed + 1; } else { IVCS_Ammo_TestFailed = IVCS_Ammo_TestFailed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then { "PASS" } else { "FAIL" },_label];
};
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
west setFriend [east,0]; east setFriend [west,0];
private _blueConfig = configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad";
private _redConfig = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";
[isClass _blueConfig && { isClass _redConfig },"standard BLU_F and OPF_F squad configs exist"] call _assert;
if (!isClass _blueConfig || { !isClass _redConfig }) exitWith {
    diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",IVCS_Ammo_TestPassed,IVCS_Ammo_TestFailed];
};

private _useNativeStock = missionNamespace getVariable ["IVCS_Ammo_UseNativeStock",false];
private _trialCount = missionNamespace getVariable ["IVCS_Ammo_TrialCount",20];
private _nativeLoadouts = createHashMap;
if (_useNativeStock) then {
    private _classes = [];
    { { _classes pushBackUnique _x; } forEach ([_x] call IVCS_Common_getUnitClassesFromGroupConfig); } forEach [_blueConfig,_redConfig];
    private _nativeGroup = createGroup [west,true];
    {
        private _unit = _nativeGroup createUnit [_x,[14000,16000,0],[],0,"NONE"];
        _unit disableAI "ALL";
        sleep 0.05;
        _nativeLoadouts set [_x,[_unit] call IVCS_Common_getUnitObjectLoadoutInfo];
        deleteVehicle _unit;
    } forEach _classes;
    deleteGroup _nativeGroup;
};
private _applyStock = {
    params ["_entity"];
    if (_useNativeStock) then {
        {
            private _weapons = (_nativeLoadouts get (_x get "class")) apply {
                [_x select 0,(_x select 1) apply { [_x select 0,_x select 1,+(_x select 2)] }]
            };
            _x set ["weapons",_weapons];
        } forEach (_entity get "units");
    };
    _entity
};
private _makeBlue = { [([_blueConfig,"WEST","BLU_F",[14500,16400,0]] call IVCS_VirtualSpace_createEntity) get "group"] call _applyStock };
private _makeRed = { [([_redConfig,"EAST","OPF_F",[14700,16400,0]] call IVCS_VirtualSpace_createEntity) get "group"] call _applyStock };
diag_log format ["[IVCS TASK TEST] AMMO_MODE %1 trials=%2",if (_useNativeStock) then { "nativeStockAmmo" } else { "currentVirtualFactory" },_trialCount];
private _count = { params ["_mags"]; private _sum=0; { _sum = _sum + (_x select 1); } forEach _mags; _sum };
// Test-only protection: retain production firing, enemy ammo, target selection,
// hit probability, and OPF_F damage. No production code or loadout is changed.
IVCS_Ammo_OriginalDamageUnit = IVCS_Combat_damageUnit;
IVCS_Combat_damageUnit = {
    if (!((_this select 0) getOrDefault ["ammoTestProtected",false])) then {
        _this call IVCS_Ammo_OriginalDamageUnit;
    };
};
private _allResults = [];
private _unitResults = createHashMap;
private _baselineTotal = -1;
private _testStarted = diag_tickTime;
for "_trial" from 1 to _trialCount do {
    private _blue = call _makeBlue;
    private _red = call _makeRed;
    private _blueUnits = _blue get "units";
    private _blueCount = count _blueUnits;
    private _redCount = count (_red get "units");
    private _blueMags = [];
    private _ignoredMags = [];
    {
        private _unit = _x;
        _unit set ["ammoTestProtected",true];
        private _usable = [];
        private _ignored = [];
        private _weaponDetails = [];
        {
            _x params ["_weapon","_mags"];
            private _weaponProfile = [_weapon] call IVCS_Combat_getWeaponProfile;
            private _rounds = 0;
            private _eligibleRounds = 0;
            private _magDetails = [];
            {
                private _supported = _weaponProfile get "supported" && { ([_x select 0] call IVCS_Combat_getAmmoProfile) get "supported" };
                if (_supported) then { _usable pushBack _x; _eligibleRounds = _eligibleRounds + (_x select 1); } else { _ignored pushBack _x; };
                _rounds = _rounds + (_x select 1);
                _magDetails pushBack [_x select 0,_x select 1,_supported];
            } forEach _mags;
            _weaponDetails pushBack [_weapon,_rounds,_eligibleRounds,_weaponProfile get "interval",_magDetails];
        } forEach (_unit get "weapons");
        _blueMags append _usable;
        _ignoredMags append _ignored;
        if (_trial == 1) then {
            diag_log format ["[IVCS TASK TEST] AMMO_LOADOUT %1",[_unit get "id",_unit get "class",[_usable] call _count,[_ignored] call _count,_weaponDetails]];
        };
    } forEach _blueUnits;
    private _initial = [_blueMags] call _count;
    private _ignoredInitial = [_ignoredMags] call _count;
    if (_trial == 1) then {
        _baselineTotal = _initial;
        diag_log format ["[IVCS TASK TEST] AMMO_SETUP %1",[configName _blueConfig,configName _redConfig,_blueCount,_redCount,200,_initial,_ignoredInitial,_combat get "step",_combat get "accuracyScale",_combat get "cadenceScale"]];
        diag_log format ["[IVCS TASK TEST] AMMO_RED_ROSTER %1",(_red get "units") apply { _x get "class" }];
        [[_blue,_red] call IVCS_Combat_canSee,"endurance positions have clear terrain visibility"] call _assert;
    };
    [_initial == _baselineTotal,format ["trial %1 starts with an unchanged default loadout",_trial]] call _assert;
    private _now = 0;
    private _seed = 1000 + _trial * 71;
    private _wave = 1;
    private _defeated = 0;
    private _kills = 0;
    private _exhausted = createHashMap;
    private _engagement = [_blue,_red,_now,_seed] call IVCS_Combat_start;
    private _remaining = _initial;
    while { _remaining > 0 && { _now < 7200 } } do {
        _now = _now + (_combat get "step");
        private _beforeRed = count (_red get "units");
        [_engagement,_now] call IVCS_Combat_update;
        private _afterRed = count (_red get "units");
        _kills = _kills + _beforeRed - _afterRed;
        _remaining = [_blueMags] call _count;
        {
            private _id = _x get "id";
            private _available = [];
            {
                if (([_x select 0] call IVCS_Combat_getWeaponProfile) get "supported") then {
                    _available append ((_x select 1) select { ([_x select 0] call IVCS_Combat_getAmmoProfile) get "supported" });
                };
            } forEach (_x get "weapons");
            if ([_available] call _count > 0) then { _exhausted deleteAt _id; } else {
                if !(_id in _exhausted) then { _exhausted set [_id,_now]; };
            };
        } forEach _blueUnits;
        if (_afterRed == 0) then {
            _defeated = _defeated + 1;
            if (_remaining > 0) then {
                _red = call _makeRed;
                _wave = _wave + 1;
                _engagement = [_blue,_red,_now,_seed + _wave * 137] call IVCS_Combat_start;
            };
        };
    };
    private _blueIntact = count (_blue get "units") == _blueCount && { (_blue get "units") findIf { (_x get "damage") != 0 || { (_x get "hitpoints") findIf { (_x select 1) != 0 } != -1 } } == -1 };
    [_remaining == 0 && { (_blue get "units") findIf { ([_x] call IVCS_Combat_getShot) isNotEqualTo [] } == -1 },format ["trial %1 stops only when BLU_F can no longer fire",_trial]] call _assert;
    [_blueIntact,format ["trial %1 preserves every BLU_F unit without injuries",_trial]] call _assert;
    [[_ignoredMags] call _count == _ignoredInitial && { _blueMags findIf { (_x select 1) < 0 } == -1 },format ["trial %1 preserves unsupported ammo and never goes negative",_trial]] call _assert;
    private _perUnit = [];
    {
        private _unit = _x;
        private _time = _exhausted getOrDefault [_unit get "id",-1];
        private _key = _unit get "id";
        private _times = _unitResults getOrDefault [_key,[]];
        _times pushBack _time;
        _unitResults set [_key,_times];
        _perUnit pushBack [_key,_unit get "class",_time];
    } forEach _blueUnits;
    private _result = [_trial,_seed,_now,_initial - _remaining,_defeated,_wave,_kills,count (_red get "units"),_remaining,[_ignoredMags] call _count,_perUnit];
    _allResults pushBack _result;
    diag_log format ["[IVCS TASK TEST] AMMO_TRIAL %1",_result];
    [_blue] call IVCS_VirtualSpace_unregisterEntity;
    [_red] call IVCS_VirtualSpace_unregisterEntity;
};
IVCS_Combat_damageUnit = IVCS_Ammo_OriginalDamageUnit;
private _durations = _allResults apply { _x select 2 };
_durations sort true;
private _sum = 0;
private _killsSum = 0;
private _defeatedSum = 0;
{ _sum = _sum + (_x select 2); _killsSum = _killsSum + (_x select 6); _defeatedSum = _defeatedSum + (_x select 4); } forEach _allResults;
private _mean = _sum / count _allResults;
private _variance = 0;
{ _variance = _variance + (_x - _mean)^2; } forEach _durations;
private _middle = floor (count _durations / 2);
private _median = if ((count _durations mod 2) == 0) then { ((_durations select (_middle-1)) + (_durations select _middle)) / 2 } else { _durations select _middle };
diag_log format ["[IVCS TASK TEST] AMMO_SUMMARY %1",[count _allResults,_mean,_median,_durations select 0,_durations select (count _durations - 1),sqrt (_variance / count _durations),_baselineTotal,_killsSum / count _allResults,_defeatedSum / count _allResults,diag_tickTime - _testStarted]];
{
    private _id = _x;
    private _times = _unitResults get _id;
    private _total = 0;
    { _total = _total + _x; } forEach _times;
    _times sort true;
    diag_log format ["[IVCS TASK TEST] AMMO_UNIT_SUMMARY %1",[_id,_total / count _times,_times select 0,_times select (count _times - 1)]];
} forEach (keys _unitResults);
[count (((IVCS_VirtualSpace_Controller get "entities") get "ALL")) == 0 && { count (_combat get "engagements") == 0 },"endurance teardown clears all groups and engagements"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",IVCS_Ammo_TestPassed,IVCS_Ammo_TestFailed];
