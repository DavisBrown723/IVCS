params ["_vehicle","_ammo","_factor","_selection"];
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _increment = (_ammo get "vehicleHit") * _factor / ((_profile get "armor") * (_profile get "structural"));
_vehicle set ["damage",((_vehicle get "damage") + _increment) min 1];
private _hitpoints = _vehicle get "hitpoints";
if (_hitpoints isNotEqualTo []) then {
    private _hitpoint = _hitpoints select (floor (_selection * count _hitpoints) min (count _hitpoints - 1));
    private _resistance = (_profile get "hitpoints") getOrDefault [toLower (_hitpoint select 0),1];
    _hitpoint set [1,((_hitpoint select 1) + _increment / _resistance) min 1];
};
if ((_vehicle get "damage") >= 1) then {
    // Existing teardown releases crew/passengers and completes the engagement.
    [_vehicle] call IVCS_VirtualSpace_unregisterEntity;
};
