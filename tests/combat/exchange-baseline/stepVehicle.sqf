// Resolve both sides before removing casualties. Only land vehicles return fire.
params ["_engagement","_groups","_dt",["_supportOnly",false]];
_groups params ["_infantry","_vehicle"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _range = (_infantry get "position") distance (_vehicle get "position");
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _settings = [_range,_combat get "accuracyScale",_combat get "cadenceScale",_combat get "minimumFireInterval",_combat get "placementDelay",_vehicle get "class"];
private _state = _engagement getOrDefault [if (_supportOnly) then {"supportFactors_"+(_infantry get "id")} else {"vehicleFactors"},[]];
if (_state isEqualTo [] || { (_state select 0) isNotEqualTo _settings }) then {
    _state = [_settings,createHashMap]; _engagement set [if (_supportOnly) then {"supportFactors_"+(_infantry get "id")} else {"vehicleFactors"},_state];
};
private _cache = _state select 1;
private _seed = _engagement get "seed";
private _random = { _seed = (_seed * 75 + 74) mod 65537; _seed / 65537 };
private _shots = _engagement get "shots";
private _shotsBefore = _shots;
private _hits = [];
{
    private _unit = _x;
    private _delay = (_unit get "fireDelay") - _dt;
    private _planting = _unit get "planting";
    // An in-progress placement must still own its magazine and remain in reach every tick.
    private _shot = if (_delay <= 0 || {_planting isNotEqualTo []}) then { [_unit,_cache,_profile,_range,_supportOnly] call IVCS_Combat_getVehicleShot } else { [] };
    if (_planting isNotEqualTo [] && {_shot isEqualTo [] || {(_shot select 9)!=4} || {!((_planting select 0) isEqualRef (_shot select 0))}}) then {
        _unit set ["planting",[]];
        _delay = 0;
    };
    if (_shot isNotEqualTo [] && { _shot select 8 }) then {
        // Release the land-capable squad together: its coarse position must no longer follow cargo.
        {
            if (([_x] call IVCS_Combat_mountState) in [2,3]) then {
                [_infantry,_x] call IVCS_VirtualSpace_Group_onUnitLeaveVehicle;
            };
        } forEach (_infantry get "units");
    };
    // Close placement is a timed action. Inventory is consumed only on completion.
    if (_shot isNotEqualTo [] && { (_shot select 9) == 4 }) then {
        private _planting = _unit get "planting";
        if (_planting isEqualTo [] || { !((_planting select 0) isEqualRef (_shot select 0)) } || { (_planting select 1) != (_engagement get "id") }) then {
            _unit set ["planting",[_shot select 0,_engagement get "id"]];
            _delay = _combat get "placementDelay";
            _shot = [];
        };
    };
    private _armDamage = 0;
    if (_shot isNotEqualTo []) then {
        { _armDamage = _armDamage max ((_unit get "hitpoints") select _x select 1); } forEach (([_unit] call IVCS_Combat_getHitpointLayout) select 2);
    };
    while { _delay <= 0 && { _shot isNotEqualTo [] } } do {
        _shot params ["_magazine","_weapon","_ammo","_factors","_interval","_magazines","_index"];
        private _placing = (_shot select 9) == 4;
        private _attempts = if (_placing) then {1} else {(floor (-_delay / _interval) + 1) min (_magazine select 1)};
        _magazine set [1,(_magazine select 1) - _attempts];
        _shots = _shots + _attempts;
        _delay = _delay + (if (_placing) then { (_combat get "reloadDelay") max 0.1 } else { _attempts * _interval });
        if ((_magazine select 1) == 0) then {
            _magazines deleteAt _index;
            if (!_placing) then { _delay = _delay + (_combat get "reloadDelay"); };
        };
        private _accuracy = if ((_shot select 9) == 4) then {1} else {(((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8};
        private _count = [_attempts,_accuracy,_random] call IVCS_Combat_sampleHits;
        for "_hit" from 1 to _count do { _hits pushBack [_vehicle,_ammo,_factors select 1,call _random,call _random]; };
        _unit set ["planting",[]];
        if (_placing) then { _shot = []; } else {
            if (_delay <= 0) then { _shot = [_unit,_cache,_profile,_range,_supportOnly] call IVCS_Combat_getVehicleShot; };
        };
    };
    _unit set ["fireDelay",_delay max 0];
} forEach (_infantry get "units");
_engagement set ["seed",_seed];
_engagement set ["shots",_shots];
_engagement set ["hits",(_engagement get "hits") + count _hits];
if (_shots>_shotsBefore) then {[_vehicle,_infantry] call IVCS_Combat_markAirThreat};
if (_supportOnly) exitWith {_hits};
if ((_vehicle get "vehicleType")!="helicopter") then {
    [_engagement,_infantry,_vehicle,_range,_dt] call IVCS_Combat_stepReturnFire;
} else {
    private _allowed=[_infantry,_vehicle] call IVCS_Combat_canHelicopterFire;
    private _passes=(([_vehicle] call IVCS_Combat_getHelicopterPolicy) select 2) && {[_vehicle,_infantry] call IVCS_Combat_inHelicopterAttackArea};
    private _segments=if (_passes) then {([_engagement,_dt,_engagement get "stepTime"] call IVCS_Combat_getHelicopterPass) select 3} else {[[true,_dt]]};
    {
        _x params ["_active","_duration"];
        if (_active && {_allowed}) then {[_engagement,_infantry,_vehicle,_range,_duration] call IVCS_Combat_stepReturnFire} else {
            private _delays=_vehicle get "turretFireDelays";{_delays set [_x,(_y-_duration) max 0]} forEach _delays;
        };
    } forEach _segments;
};
{
    if ((_engagement get "mode") == "finished") exitWith {};
    _x call IVCS_Combat_damageVehicle;
} forEach _hits;
{
    _engagement set ["casualties",(_engagement get "casualties")+1];
    [_infantry,_x] call IVCS_VirtualSpace_Group_RemoveUnit;
} forEach ((_infantry get "units") select {(_x get "damage")>=1});
_engagement set ["elapsed",(_engagement get "elapsed") + _dt];
