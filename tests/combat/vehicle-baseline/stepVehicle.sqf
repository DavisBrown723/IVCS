// The vehicle is passive. Only the dismounted infantry roster fires.
params ["_engagement","_groups","_dt"];
_groups params ["_infantry","_vehicle"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _range = (_infantry get "position") distance2D (_vehicle get "position");
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _settings = [_range,_combat get "accuracyScale",_combat get "cadenceScale",_combat get "minimumFireInterval",_vehicle get "class"];
private _state = _engagement getOrDefault ["vehicleFactors",[]];
if (_state isEqualTo [] || { (_state select 0) isNotEqualTo _settings }) then {
    _state = [_settings,createHashMap]; _engagement set ["vehicleFactors",_state];
};
private _cache = _state select 1;
private _seed = _engagement get "seed";
private _random = { _seed = (_seed * 75 + 74) mod 65537; _seed / 65537 };
private _shots = _engagement get "shots";
private _hits = [];
{
    private _unit = _x;
    private _delay = (_unit get "fireDelay") - _dt;
    private _shot = if (_delay <= 0) then { [_unit,_cache,_profile,_range] call IVCS_Combat_getVehicleShot } else { [] };
    private _armDamage = 0;
    if (_shot isNotEqualTo []) then {
        { _armDamage = _armDamage max ((_unit get "hitpoints") select _x select 1); } forEach (([_unit] call IVCS_Combat_getHitpointLayout) select 2);
    };
    while { _delay <= 0 && { _shot isNotEqualTo [] } } do {
        _shot params ["_magazine","_weapon","_ammo","_factors","_interval","_magazines","_index"];
        private _attempts = (floor (-_delay / _interval) + 1) min (_magazine select 1);
        _magazine set [1,(_magazine select 1) - _attempts];
        _shots = _shots + _attempts;
        _delay = _delay + _attempts * _interval;
        if ((_magazine select 1) == 0) then { _magazines deleteAt _index; _delay = _delay + (_combat get "reloadDelay"); };
        private _accuracy = (((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8;
        private _count = [_attempts,_accuracy,_random] call IVCS_Combat_sampleHits;
        for "_hit" from 1 to _count do { _hits pushBack [_vehicle,_ammo,_factors select 1,call _random]; };
        if (_delay <= 0) then { _shot = [_unit,_cache,_profile,_range] call IVCS_Combat_getVehicleShot; };
    };
    _unit set ["fireDelay",_delay max 0];
} forEach (_infantry get "units");
_engagement set ["seed",_seed];
_engagement set ["shots",_shots];
_engagement set ["hits",(_engagement get "hits") + count _hits];
{
    if ((_engagement get "mode") == "finished") exitWith {};
    _x call IVCS_Combat_damageVehicle;
} forEach _hits;
_engagement set ["elapsed",(_engagement get "elapsed") + _dt];
