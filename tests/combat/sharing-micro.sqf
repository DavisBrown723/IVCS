// Regression for preprocessing, inventory edits, and fair frame-budgeted catchup.
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

private _referenceSurplus = {
// Reserve protection is shared by virtual and native snapshots.
params ["_snapshot"];
_snapshot params ["", "", "_weapons", "_magazines"];
private _protected = [];
{
    if ((_x select 2) && { (_x select 1) > 0 }) then { _protected pushBack _forEachIndex; };
} forEach _magazines;
{
    private _compatible = ([_x] call IVCS_Ammo_getWeaponProfile) select 2;
    private _spare = -1;
    private _rounds = -1;
    {
        if ((_x select 1) > _rounds && { (_x select 1) > 0 } && { !(_x select 2) } && {
            _compatible getOrDefault [_x select 0, false]
        }) then { _spare = _forEachIndex; _rounds = _x select 1; };
    } forEach _magazines;
    // Overlapping compatibility pools may protect the same spare.
    if (_spare != -1) then { _protected pushBackUnique _spare; };
} forEach _weapons;
private _available = [];
{
    if ((_x select 1) > 0 && { !(_x select 2) } && { !(_forEachIndex in _protected) }) then { _available pushBack _x; };
} forEach _magazines;
_available

};
private _referenceNeeds = {
// Virtual inventory fast path: inspect current rounds without allocating snapshots.
params ["_unit",["_native",false]];
if (_native) exitWith {
    private _snapshot = [_unit,true] call IVCS_Ammo_snapshot;
    _snapshot params ["","_primary","_weapons","_magazines"];
    private _wanted = _weapons select {
        private _profile = [_x] call IVCS_Ammo_getWeaponProfile;
        private _compatible = _profile select 2;
        (_profile select 0) in [1,2,4] && { _magazines findIf { (_x select 1) > 0 && { _compatible getOrDefault [_x select 0,false] } } == -1 }
    };
    if (_primary in _wanted) then { _wanted = [_primary] + (_wanted - [_primary]); };
    _wanted
};
private _weapons = _unit get "weapons";
private _wanted = [];
private _primary = "";
{
    _x params ["_weapon", "_records"];
    private _profile = [_weapon] call IVCS_Ammo_getWeaponProfile;
    private _type = _profile select 0;
    if (_primary == "" && { _type == 1 }) then { _primary = _weapon; };
    if (_type in [1,2,4]) then {
        private _compatible = _profile select 2;
        private _hasAmmo = _records findIf {
            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
        } != -1;
        if (!_hasAmmo) then {
            // The same policy counts compatible ammunition in cargo or another weapon.
            _hasAmmo = (_unit get "magazineCargo") findIf {
                (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
            } != -1 || {
                _weapons findIf {
                    (_x select 1) findIf {
                        (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
                    } != -1
                } != -1
            };
        };
        if (!_hasAmmo) then { _wanted pushBack _weapon; };
    };
} forEach _weapons;
if (_primary in _wanted) then { _wanted = [_primary] + (_wanted - [_primary]); };
_wanted

};
private _referenceSnapshot = {
// Normalized snapshot: [unit profile, primary weapon, carried weapons, magazines].
// Magazine: [class, rounds, loaded, token, native container].
params ["_unit", "_native"];
private _weapons = [];
private _primary = "";
private _magazines = [];
if (_native) then {
    private _object = _unit get "object";
    _primary = primaryWeapon _object;
    _weapons = weapons _object;
    {
        _x params ["_class", "_rounds", "_loaded", "", "_location", "_id"];
        private _container = switch (_location) do {
            case "Uniform": { uniformContainer _object };
            case "Vest": { vestContainer _object };
            case "Backpack": { backpackContainer _object };
            default { objNull };
        };
        _magazines pushBack [_class, _rounds, _loaded, _id, _container];
    } forEach (magazinesAmmoFull [_object, true]);
} else {
    {
        _x params ["_weapon", "_records"];
        _weapons pushBack _weapon;
        if (_primary == "" && { (([_weapon] call IVCS_Ammo_getWeaponProfile) select 0) == 1 }) then { _primary = _weapon; };
        private _loaded = _records findIf { (_x select 1) > 0 };
        { _magazines pushBack [_x select 0, _x select 1, _forEachIndex == _loaded, [_records, _x], objNull]; } forEach _records;
    } forEach (_unit get "weapons");
    private _cargo = _unit get "magazineCargo";
    { _magazines pushBack [_x select 0, _x select 1, false, [_cargo, _x], objNull]; } forEach _cargo;
};
_weapons = _weapons select { (([_x] call IVCS_Ammo_getWeaponProfile) select 0) in [1, 2, 4] };
[_unit, _primary, _weapons, _magazines]

};
private _blue = ([configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad","WEST","BLU_F",[14500,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
private _red = ([configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad","EAST","OPF_F",[14700,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
private _units = (_blue get "units") + (_red get "units");
private _matches = true;
{
    private _snapshot = [_x,false] call IVCS_Ammo_snapshot;
    if (([_snapshot] call IVCS_Ammo_surplus) isNotEqualTo ([_snapshot] call _referenceSurplus) || {
        ([_x] call IVCS_Ammo_getNeededWeapons) isNotEqualTo ([_x] call _referenceNeeds)
    }) then { _matches = false; };
} forEach _units;
[_matches,"stock microbenchmark functions preserve previous outputs"] call _assert;
// Enough repetitions to exceed the Windows timer quantum; no profiler is loaded.
for "_trial" from 1 to 4 do {
    {
        private _u = _x;
        private _snapshot = [_u,false] call IVCS_Ammo_snapshot;
        private _versions = [["before",_referenceSurplus],["after",IVCS_Ammo_surplus]];
        if (_trial mod 2 == 0) then { reverse _versions; };
        {
            _x params ["_version","_function"];
            private _elapsed = 0;
            isNil {
                private _start = diag_tickTime;
                for "_i" from 1 to 200 do { [_snapshot] call _function; };
                _elapsed = 1000 * (diag_tickTime - _start) / 200;
            };
            diag_log format ["[IVCS MICRO] SURPLUS %1",[_trial,_u get "class",_version,_elapsed]];
        } forEach _versions;
        _versions = [["before",_referenceSnapshot],["after",IVCS_Ammo_snapshot]];
        if (_trial mod 2 == 0) then { reverse _versions; };
        {
            _x params ["_version","_function"];
            private _elapsed = 0;
            isNil {
                private _start = diag_tickTime;
                for "_i" from 1 to 200 do { [_u,false] call _function; };
                _elapsed = 1000 * (diag_tickTime - _start) / 200;
            };
            diag_log format ["[IVCS MICRO] SNAPSHOT %1",[_trial,_u get "class",_version,_elapsed]];
        } forEach _versions;
        _versions = [["before",_referenceNeeds],["after",IVCS_Ammo_getNeededWeapons]];
        if (_trial mod 2 == 0) then { reverse _versions; };
        {
            _x params ["_version","_function"];
            private _elapsed = 0;
            isNil {
                private _start = diag_tickTime;
                for "_i" from 1 to 500 do { [_u] call _function; };
                _elapsed = 1000 * (diag_tickTime - _start) / 500;
            };
            diag_log format ["[IVCS MICRO] NEEDS %1",[_trial,_u get "class",_version,_elapsed]];
        } forEach _versions;
    } forEach _units;
};
[_blue] call IVCS_VirtualSpace_unregisterEntity; [_red] call IVCS_VirtualSpace_unregisterEntity;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
