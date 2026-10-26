// Compare optimized calculations against the pre-optimization resolver.
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
private _referenceAccuracy = {
params ["_unit", "_weapon", "_ammo", "_range"];
private _speed = [_weapon, _ammo, _range] call IVCS_Combat_getImpactSpeed;
private _spread = (_weapon get "dispersion") * _range;
private _probability = ((IVCS_VirtualSpace_Controller get "combat") get "accuracyScale") / (1 + (_range / 100)^2 + (_spread / 0.35)^2);
private _armDamage = 0;
private _profile = [_unit get "class"] call IVCS_Combat_getUnitProfile;
{
    private _info = (_profile get "hitpoints") get (_x select 0);
    if (!isNil "_info" && { (_info select 2) == "arms" }) then { _armDamage = _armDamage max (_x select 1); };
} forEach (_unit get "hitpoints");
((_probability * (sqrt (_speed / 900) min 1.2) * (1 - 0.65 * _armDamage)) max 0) min 0.8

};
private _referenceDamage = {
params ["_unit", "_weapon", "_ammo", "_range", "_region", "_selection"];
private _profile = [_unit get "class"] call IVCS_Combat_getUnitProfile;
private _hitpoints = _unit get "hitpoints";
private _available = _hitpoints apply { _x select 0 };
private _names = ((_profile get "regions") get _region) arrayIntersect _available;
if (_names isEqualTo []) then { _names = (_profile get "targets") arrayIntersect _available; };
if (_names isEqualTo []) exitWith {
    // Unsupported custom hitpoint layouts still take overall damage.
    _unit set ["damage", ((_unit get "damage") + (_ammo get "hit") / (_profile get "armor")) min 1];
};
private _name = _names select (floor (_selection * count _names) min (count _names - 1));
private _hitInfo = (_profile get "hitpoints") get _name;
private _protection = ([_unit get "equipment"] call IVCS_Combat_getProtection) getOrDefault [toLower _name, [0, 1]];
private _speedRatio = (([_weapon, _ammo, _range] call IVCS_Combat_getImpactSpeed) / (_ammo get "typicalSpeed")) max 0.2;
private _armor = (_profile get "armor") * (_hitInfo select 0) + (_protection select 0);
private _increment = (_ammo get "hit") * (_speedRatio min 1.5) / _armor;
private _index = _hitpoints findIf { (_x select 0) == _name };
private _hitpoint = _hitpoints select _index;
_hitpoint set [1, ((_hitpoint select 1) + _increment) min 1];
private _passThrough = (_hitInfo select 1) min (_protection select 1);
private _damage = (_unit get "damage") + _increment * (_passThrough max 0.05) / (_profile get "structural");
if ((_hitInfo select 2) in ["head", "torso"] && { (_hitpoint select 1) >= 1 }) then { _damage = 1; };
_unit set ["damage", _damage min 1];

};
private _make = { ["B_Soldier_F","u"] call IVCS_VirtualSpace_Group_createUnit };
private _weapon = ["arifle_MX_F"] call IVCS_Combat_getWeaponProfile;
private _ammo = ["30Rnd_65x39_caseless_mag"] call IVCS_Combat_getAmmoProfile;
{
    private _range = _x;
    {
        private _unit = call _make;
        { _x set [1,0.6]; } forEach ((_unit get "hitpoints") select { (_x select 0) in ((["B_Soldier_F"] call IVCS_Combat_getUnitProfile) get "regions" get "arms") });
        private _factors = [_weapon,_ammo,_range] call IVCS_Combat_getShotFactors;
        [abs (([_unit,_weapon,_ammo,_range,_factors] call IVCS_Combat_accuracy) - ([_unit,_weapon,_ammo,_range] call _referenceAccuracy)) < 1e-7,"preprocessed accuracy matches original formula"] call _assert;
        private _region = _x;
        private _same = true;
        {
            private _optimized = call _make; private _reference = call _make;
            if (_x > 0.5) then { _optimized set ["equipment",["",""]]; _reference set ["equipment",["",""]]; };
            [_optimized,_weapon,_ammo,_range,_region,_x,_factors] call IVCS_Combat_damageUnit;
            [_reference,_weapon,_ammo,_range,_region,_x] call _referenceDamage;
            _same = _same && { (_optimized get "damage") == (_reference get "damage") } && { (_optimized get "hitpoints") isEqualTo (_reference get "hitpoints") };
        } forEach [0,0.08,0.2,0.52,0.8,0.999];
        [_same,"preprocessed hit selection and damage match original resolver"] call _assert;
    } forEach ["head","torso","arms","legs"];
} forEach [0,25,200,300];
private _unit = call _make;
private _layout = [_unit] call IVCS_Combat_getHitpointLayout;
private _base = [_unit,_weapon,_ammo,200] call IVCS_Combat_accuracy;
((_unit get "hitpoints") select ((_layout select 2) select 0)) set [1,1];
[([_unit,_weapon,_ammo,200] call IVCS_Combat_accuracy) < _base,"cached arm indices read current damage"] call _assert;
_unit set ["hitpoints",[["hitlegs",0]]];
[_unit,_weapon,_ammo,200,"head",0.2] call IVCS_Combat_damageUnit;
[(_unit get "hitpoints" select 0 select 1) > 0,"replaced partial layout invalidates cache and preserves fallback"] call _assert;
_unit set ["hitpoints",[]];
private _before = _unit get "damage";
[_unit,_weapon,_ammo,200,"torso",0] call IVCS_Combat_damageUnit;
[(_unit get "damage") > _before,"empty replaced layout retains overall damage fallback"] call _assert;
// Shared range factors must refresh for movement and settings edits.
private _a = ["WEST","BLU_F",[14500,16400,0],[call _make]] call IVCS_VirtualSpace_Group_createEntity;
private _b = ["EAST","BLU_F",[14700,16400,0],[call _make]] call IVCS_VirtualSpace_Group_createEntity;
west setFriend [east,0]; east setFriend [west,0];
private _combat = IVCS_VirtualSpace_Controller get "combat";
_combat set ["accuracyScale",0];
private _engagement = [_a,_b,0,123] call IVCS_Combat_start;
IVCS_Shot_OriginalFactors = IVCS_Combat_getShotFactors; IVCS_Shot_FactorCalls = 0;
IVCS_Combat_getShotFactors = { IVCS_Shot_FactorCalls = IVCS_Shot_FactorCalls + 1; _this call IVCS_Shot_OriginalFactors; };
[_engagement,[_a,_b],0.5] call IVCS_Combat_step;
[IVCS_Shot_FactorCalls == 1,"matching shooters compute exact range factors once"] call _assert;
{ { _x set ["fireDelay",0]; } forEach (_x get "units"); } forEach [_a,_b];
[_engagement,[_a,_b],0.5] call IVCS_Combat_step;
[IVCS_Shot_FactorCalls == 1,"unchanged range reuses factors across exchanges"] call _assert;
[_b,[14600,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
{ { _x set ["fireDelay",0]; } forEach (_x get "units"); } forEach [_a,_b];
[_engagement,[_a,_b],0.5] call IVCS_Combat_step;
[IVCS_Shot_FactorCalls == 2 && { (_engagement get "shotFactors" select 0) == 100 },"moving a group invalidates exact-range factors"] call _assert;
_combat set ["accuracyScale",0.01];
{ { _x set ["fireDelay",0]; } forEach (_x get "units"); } forEach [_a,_b];
[_engagement,[_a,_b],0.5] call IVCS_Combat_step;
[IVCS_Shot_FactorCalls == 3,"accuracy setting edits invalidate cached factors"] call _assert;
((_combat get "bodyWeights") select 0) set [1,0.25];
[_engagement,[_a,_b],0.5] call IVCS_Combat_step;
[(_combat get "bodySelection" select 2 select 0 select 1) == 0.25,"in-place weight edits rebuild cumulative selection"] call _assert;
IVCS_Combat_getShotFactors = IVCS_Shot_OriginalFactors;
[_a] call IVCS_VirtualSpace_unregisterEntity; [_b] call IVCS_VirtualSpace_unregisterEntity;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
