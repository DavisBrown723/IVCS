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
// Independent previous implementations remain the policy oracle.
private _classes = ["30Rnd_65x39_caseless_mag","100Rnd_65x39_caseless_mag","16Rnd_9x21_Mag","NLAW_F","30Rnd_65x39_caseless_green"];
private _weaponSets = [[],["arifle_MX_F"],["arifle_MX_SW_F","arifle_MX_F"],["arifle_MX_F","hgun_P07_F","launch_NLAW_F"],["hgun_P07_F","arifle_MX_F"],["Binocular","hgun_P07_F"]];
private _unit = ["B_Soldier_F","policy"] call IVCS_VirtualSpace_Group_createUnit;
for "_case" from 0 to 63 do {
    private _weapons = [];
    {
        private _records = [];
        for "_i" from 0 to ((_case mod 12) - 1) do {
            _records pushBack [_classes select ((_i + _case + count _weapons) mod 5),[0,8,17,30] select ((_i * 3 + floor (_case / 5)) mod 4),["infantry"]];
        };
        _weapons pushBack [_x,_records];
    } forEach (_weaponSets select (_case mod count _weaponSets));
    private _cargo = [];
    for "_i" from 0 to ((_case mod 16) - 1) do {
        _cargo pushBack [_classes select ((_i + _case) mod 5),[0,8,17,30] select ((_i + floor (_case / 3)) mod 4),["infantry"]];
    };
    _unit set ["weapons",_weapons]; _unit set ["magazineCargo",_cargo];
    private _snapshot = [_unit,false] call IVCS_Ammo_snapshot;
    [_snapshot isEqualTo ([_unit,false] call _referenceSnapshot),format ["single-pass snapshot preserves every field and token for inventory %1",_case]] call _assert;
    private _old = [_snapshot] call _referenceSurplus;
    private _new = [_snapshot] call IVCS_Ammo_surplus;
    [_new isEqualTo _old,format ["simplified surplus preserves previous policy and order for inventory %1",_case]] call _assert;
    _old = [_unit] call _referenceNeeds;
    if (_weapons isNotEqualTo []) then { IVCS_Ammo_WeaponProfiles deleteAt (_weapons select 0 select 0); };
    [([_unit] call IVCS_Ammo_getNeededWeapons) isEqualTo _old,format ["needs scan observes live contents, weapon order and cache misses for inventory %1",_case]] call _assert;
};
private _mag = { params ["_rounds"]; ["30Rnd_65x39_caseless_mag",_rounds,["infantry"]] };
private _units = [];
for "_i" from 0 to 3 do {
    private _u = ["B_Soldier_F",format ["q_%1",_i]] call IVCS_VirtualSpace_Group_createUnit;
    _u set ["weapons",[["arifle_MX_F",[]]]]; _u set ["magazineCargo",[]]; _units pushBack _u;
};
private _donor = _units select 3;
_donor set ["weapons",[["arifle_MX_F",[[30] call _mag,[30] call _mag]]]];
_donor set ["magazineCargo",[[17] call _mag]];
private _e = ["WEST","BLU_F",[14500,16400,0],_units] call IVCS_VirtualSpace_Group_createEntity;
IVCS_Work_OriginalAdvance = IVCS_Ammo_advanceSearch; IVCS_Work_Advances = 0;
IVCS_Ammo_advanceSearch = { IVCS_Work_Advances = IVCS_Work_Advances + 1; _this call IVCS_Work_OriginalAdvance; };
[_e,0] call IVCS_Ammo_updateGroup;
[IVCS_Work_Advances == 1 && { (_e get "ammoSearch" get "donorIndex") == 3 } && { (_e get "ammoRequests") isEqualTo [] },"new discovery performs one bounded initial slice and defers winner revalidation"] call _assert;
IVCS_Work_OriginalSnapshot = IVCS_Ammo_snapshot; IVCS_Work_Snapshots = 0;
IVCS_Ammo_snapshot = { IVCS_Work_Snapshots = IVCS_Work_Snapshots + 1; _this call IVCS_Work_OriginalSnapshot; };
[_e,1] call IVCS_Ammo_updateGroup;
[IVCS_Work_Advances == 2 && { IVCS_Work_Snapshots == 2 } && { count (_e get "ammoRequests") == 1 },"existing inline slices include winner revalidation in their two-inspection quota"] call _assert;
IVCS_Ammo_snapshot = IVCS_Work_OriginalSnapshot;
IVCS_Ammo_advanceSearch = IVCS_Work_OriginalAdvance;
IVCS_Work_OriginalSnapshot = IVCS_Ammo_snapshot; IVCS_Work_Snapshots = 0;
IVCS_Ammo_snapshot = { IVCS_Work_Snapshots = IVCS_Work_Snapshots + 1; _this call IVCS_Work_OriginalSnapshot; };
// Start an independent reservation after releasing the previous promise.
[_e] call IVCS_Ammo_cancelGroup;
{ _x set ["ammoRetryAt",0]; } forEach (_e get "units");
_e set ["ammoNextScan",0];
[_e,1] call IVCS_Ammo_updateGroup;
IVCS_Work_Snapshots = 0;
(_e get "ammoSearch") set ["donorIndex",2];
[_e,1.1,2] call IVCS_Ammo_advanceSearch;
[IVCS_Work_Snapshots == 2 && { (_e get "ammoRequests") isEqualTo [] } && { (_e get "ammoSearch" get "donorIndex") == 4 },"full donor slice leaves winner revalidation for the next frame"] call _assert;
IVCS_Work_Snapshots = 0;
[_e,1.2,2] call IVCS_Ammo_advanceSearch;
[IVCS_Work_Snapshots <= 2 && { count (_e get "ammoRequests") == 1 },"winner revalidation is included in the snapshot quota"] call _assert;
IVCS_Ammo_snapshot = IVCS_Work_OriginalSnapshot;
[_e] call IVCS_VirtualSpace_unregisterEntity;
[(((IVCS_VirtualSpace_Controller get "combat") get "ammoSharing") get "searchQueue") isEqualTo [],"unregister clears deferred donor work"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
