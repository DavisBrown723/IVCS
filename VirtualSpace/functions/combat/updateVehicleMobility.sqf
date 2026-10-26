// Called only when a component crosses full damage, or after native capture/repair.
params ["_vehicle"];
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _hp = _vehicle get "hitpoints";
(_profile get "mobility") params ["_engine","_tracks","_wheels"];
private _disabled = _engine findIf {(_hp select _x select 1)>=1} != -1 || {
    _tracks findIf {(_hp select _x select 1)>=1} != -1 || {{(_hp select _x select 1)>=1} count _wheels >= 2}
};
private _speed = if (_disabled) then {0} else {_vehicle get "baseSpeedPerSecond"};
if ((_vehicle get "speedPerSecond") != _speed) then {
    _vehicle set ["speedPerSecond",_speed];
    {
        private _group = [_x] call IVCS_VirtualSpace_getEntity;
        if (!isNil "_group") then {[_group] call IVCS_VirtualSpace_Group_calculateSpeed};
    } forEach ([_vehicle get "commandingEntity"] + (_vehicle get "entitiesInCargo"));
};
