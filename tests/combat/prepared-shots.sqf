// Differential checks against the resolver immediately before prepared firing.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap; IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap; IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _passed = 0; private _failed = 0;
private _assert = {
    params ["_ok","_label"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label];
};
private _beforeShot = {
// Read-only selection. Returned magazine is the individual unit's mutable record.
params ["_unit"];
private _result = [];
{
    _x params ["_weapon", "_magazines"];
    private _weaponProfile = IVCS_Combat_WeaponProfiles get _weapon;
    if (isNil "_weaponProfile") then { _weaponProfile = [_weapon] call IVCS_Combat_getWeaponProfile; };
    if (_weaponProfile get "supported") then {
        private _ammoProfile = nil;
        private _index = _magazines findIf {
            (_x select 1) > 0 && {
                _ammoProfile = IVCS_Combat_AmmoProfiles get (_x select 0);
                if (isNil "_ammoProfile") then { _ammoProfile = [_x select 0] call IVCS_Combat_getAmmoProfile; };
                _ammoProfile get "supported"
            }
        };
        if (_index != -1) then { _result = [_magazines select _index, _weaponProfile, _ammoProfile]; };
    };
    if (_result isNotEqualTo []) exitWith {};
} forEach (_unit get "weapons");
_result
};
private _beforeStep = {
params ["_engagement", "_groups", "_dt"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _range = ((_groups select 0) get "position") distance2D ((_groups select 1) get "position");
private _hits = [];
private _factorState = _engagement getOrDefault ["shotFactors",[]];
private _accuracyScale = _combat get "accuracyScale";
if (_factorState isEqualTo [] || { (_factorState select 0) != _range } || { (_factorState select 1) != _accuracyScale }) then {
    _factorState = [_range,_accuracyScale,createHashMap];
    _engagement set ["shotFactors",_factorState];
};
private _factorCache = _factorState select 2;
private _cadenceScale = _combat get "cadenceScale";
private _reloadDelay = _combat get "reloadDelay";
private _shots = _engagement get "shots";
// Keep the same integer generator and draw order, with one state write per exchange.
private _seed = _engagement get "seed";
private _random = { _seed = (_seed * 75 + 74) mod 65537; _seed / 65537 };
// Rebuild cumulative region weights only when settings change.
private _weights = _combat get "bodyWeights";
private _selection = _combat getOrDefault ["bodySelection",[]];
if (_selection isEqualTo [] || { !((_selection select 0) isEqualTo _weights) }) then {
    private _total = 0;
    private _cumulative = _weights apply { _total = _total + (_x select 1); [_x select 0,_total] };
    _selection = [_weights apply { +_x },_total,_cumulative];
    _combat set ["bodySelection",_selection];
};
private _cumulative = _selection select 2;
private _weightTotal = _selection select 1;
private _lastRegion = (_cumulative select (count _cumulative - 1)) select 0;
// Take both firing rosters before applying hits: no first-side casualty advantage.
{
    private _shooters = _x get "units";
    private _targets = (_groups select (1 - _forEachIndex)) get "units";
    private _targetCount = count _targets;
    {
        private _unit = _x;
        private _delay = (_unit get "fireDelay") - _dt;
        _unit set ["fireDelay", _delay max 0];
        if (_delay <= 0) then {
            private _shot = [_unit] call IVCS_Combat_getShot;
            if (_shot isNotEqualTo []) then {
                _shot params ["_magazine", "_weapon", "_ammo"];
                private _weaponClass = _weapon get "class";
                private _weaponFactors = _factorCache get _weaponClass;
                if (isNil "_weaponFactors") then {
                    _weaponFactors = createHashMap;
                    _factorCache set [_weaponClass,_weaponFactors];
                };
                private _ammoClass = _ammo get "class";
                private _factors = _weaponFactors get _ammoClass;
                if (isNil "_factors") then {
                    _factors = [_weapon,_ammo,_range] call IVCS_Combat_getShotFactors;
                    _weaponFactors set [_ammoClass,_factors];
                };
                _magazine set [1, (_magazine select 1) - 1];
                _shots = _shots + 1;
                private _reload = if ((_magazine select 1) == 0) then { _reloadDelay } else { 0 };
                _unit set ["fireDelay", _delay + ((_weapon get "interval") * _cadenceScale max _dt) + _reload];
                private _target = _targets select floor ((call _random) * _targetCount);
                if (call _random < ([_unit, _weapon, _ammo, _range, _factors] call IVCS_Combat_accuracy)) then {
                    private _roll = (call _random) * _weightTotal;
                    private _region = _lastRegion;
                    { if (_roll < (_x select 1)) exitWith { _region = _x select 0; }; } forEach _cumulative;
                    _hits pushBack [_target,_weapon,_ammo,_range,_region,call _random,_factors];
                };
            };
        };
    } forEach _shooters;
} forEach _groups;
_engagement set ["shots",_shots];
_engagement set ["seed",_seed];
_engagement set ["hits", (_engagement get "hits") + count _hits];
{ _x call IVCS_Combat_damageUnit; } forEach _hits;
{
    private _group = _x;
    {
        _engagement set ["casualties", (_engagement get "casualties") + 1];
        [_group, _x] call IVCS_VirtualSpace_Group_RemoveUnit;
    } forEach ((_group get "units") select { (_x get "damage") >= 1 });
} forEach _groups;
_engagement set ["elapsed", (_engagement get "elapsed") + _dt];
};
private _afterShot = IVCS_Combat_getShot;
private _afterStep = IVCS_Combat_step;
private _make = {
    params ["_side","_position"];
    private _cfg = if (_side == "WEST") then { configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad" } else { configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad" };
    ([_cfg,_side,if (_side == "WEST") then {"BLU_F"} else {"OPF_F"},_position] call IVCS_VirtualSpace_createEntity) get "group"
};
private _blue = ["WEST",[14500,16400,0]] call _make;
private _red = ["EAST",[14700,16400,0]] call _make;
private _units = (_blue get "units") + (_red get "units");
{
    private _u = _x;
    private _reference = [_u] call _beforeShot;
    private _actual = [_u] call _afterShot;
    [_actual isEqualTo _reference && { (_actual select 0) isEqualRef (_reference select 0) },"stock shot and mutable record identity match"] call _assert;
    // Warm calls must read changed rounds and replaced weapon/magazine arrays.
    private _saved = _u get "weapons";
    _u set ["weapons",_saved apply { [_x select 0,(_x select 1) apply { [_x select 0,0] }] }];
    [([_u] call _afterShot) isEqualTo [],"empty current inventory has no shot"] call _assert;
    _u set ["weapons",[["launch_NLAW_F",[["NLAW_F",1]]],["arifle_MX_F",[["30Rnd_65x39_caseless_mag",0],["30Rnd_65x39_caseless_mag",7]]]]];
    _actual = [_u] call _afterShot;
    [_actual isEqualTo ([_u] call _beforeShot) && { (_actual select 0 select 1) == 7 },"replaced inventory skips unsupported weapon and empty magazine"] call _assert;
    _u set ["weapons",[["arifle_MX_GL_F",[["1Rnd_HE_Grenade_shell",1],["30Rnd_65x39_caseless_mag",9]]]]];
    IVCS_Combat_WeaponProfiles deleteAt "arifle_MX_GL_F";
    IVCS_Combat_AmmoProfiles deleteAt "1Rnd_HE_Grenade_shell";
    IVCS_Combat_AmmoProfiles deleteAt "30Rnd_65x39_caseless_mag";
    _actual = [_u] call _afterShot;
    [_actual isEqualTo ([_u] call _beforeShot) && { (_actual select 0 select 1) == 9 },"cold profiles skip explosive ammo and resolve bullet fallback"] call _assert;
    _u set ["weapons",_saved];
} forEach _units;
// Warm preparation must still resolve edited inventory, including unsupported classes.
{
    private _unit = _x;
    private _saved = _unit get "weapons";
    private _cache = createHashMap;
    private _compare = {
        private _expected = [_unit] call _beforeShot;
        private _shot = [_unit,_cache,200,1,0.5] call IVCS_Combat_getPreparedShot;
        [(_shot select [0,3]) isEqualTo _expected && { _expected isEqualTo [] || { (_shot select 0) isEqualRef (_expected select 0) } },"prepared shot reads current inventory and retains magazine identity"] call _assert;
    };
    call _compare;
    _unit set ["weapons",[["launch_NLAW_F",[["NLAW_F",1]]],["arifle_MX_GL_F",[["1Rnd_HE_Grenade_shell",1],["30Rnd_65x39_caseless_mag",7]]]]];
    call _compare;
    (((_unit get "weapons") select 1) select 1 select 1) set [1,0];
    call _compare;
    (((_unit get "weapons") select 1) select 1) pushBack ["30Rnd_65x39_caseless_mag",4];
    call _compare;
    (((_unit get "weapons") select 1) select 1) insert [0,[["30Rnd_65x39_caseless_mag",9]]];
    call _compare;
    ((_unit get "weapons") select 1) set [0,"arifle_MX_F"];
    call _compare;
    _unit set ["weapons",_saved];
} forEach _units;
// Seeded per-bullet equality is intentionally replaced by aggregation.sqf:
// hit-count sampling changes the draw sequence while preserving its probability model.
// Direct warm getShot cost for every stock inventory shape.
for "_trial" from 1 to 4 do {
    {
        private _u = _x;
        private _versions = [["before",_beforeShot],["after",_afterShot]];
        if (_trial mod 2 == 0) then { reverse _versions; };
        {
            _x params ["_version","_function"];
            private _elapsed = 0;
            isNil {
                private _start = diag_tickTime;
                for "_i" from 1 to 500 do { [_u] call _function; };
                _elapsed = 1000 * (diag_tickTime - _start) / 500;
            };
            diag_log format ["[IVCS SHOT MICRO] %1",[_trial,_u get "class",_version,_elapsed]];
        } forEach _versions;
    } forEach _units;
};
// Full warm exchange with all 16 shooters ready: misses isolate preparation from damage.
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _scale = _combat get "accuracyScale"; _combat set ["accuracyScale",0];
{ { { _x set [1,100000]; } forEach (_x select 1); } forEach (_x get "weapons"); } forEach _units;
private _engagement = [_blue,_red,0,123] call IVCS_Combat_start;
for "_trial" from 1 to 8 do {
    private _versions = [["before",_beforeShot,_beforeStep],["after",_afterShot,_afterStep]];
    if (_trial mod 2 == 0) then { reverse _versions; };
    {
        _x params ["_version","_shot","_step"];
        IVCS_Combat_getShot = _shot; _engagement deleteAt "shotFactors";
        { _x set ["fireDelay",0]; } forEach _units;
        [_engagement,[_blue,_red],0.5] call _step;
        private _elapsed = 0;
        isNil {
            private _start = diag_tickTime;
            for "_i" from 1 to 100 do {
                { _x set ["fireDelay",0]; } forEach _units;
                [_engagement,[_blue,_red],0.5] call _step;
            };
            _elapsed = 1000 * (diag_tickTime - _start) / 100;
        };
        diag_log format ["[IVCS EXCHANGE MICRO] %1",[_trial,_version,_elapsed]];
    } forEach _versions;
};
_combat set ["accuracyScale",_scale]; IVCS_Combat_getShot = _afterShot;
[_blue] call IVCS_VirtualSpace_unregisterEntity; [_red] call IVCS_VirtualSpace_unregisterEntity;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
