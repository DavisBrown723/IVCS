params ["_vehicle","_ammo","_factor","_selection",["_crewRoll",0.5]];
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _hitpoints = _vehicle get "hitpoints";
private _calibrated = (_profile get "calibration") get (_ammo get "class");
private _increment = 0; private _impact = 0; private _mobilityChanged = false;
if (!isNil "_calibrated") then {
    _calibrated params ["_reference","_samples"];
    private _sample = _samples select floor (_selection * count _samples);
    private _scale = _factor / _reference;
    _increment = (_sample select 0) * _scale;
    _impact = (_sample select 2) * _scale;
    {
        _x params ["_index","_delta"];
        private _point = _hitpoints select _index;
        private _old = _point select 1;
        private _new = (_old + _delta * _scale) min 1;
        _point set [1,_new];
        if (_old < 1 && {_new >= 1}) then {_mobilityChanged = true};
    } forEach (_sample select 1);
} else {
    _increment = (_ammo get "vehicleHit") * _factor / ((_profile get "armor") * (_profile get "structural"));
    _impact = _increment;
    if (_hitpoints isNotEqualTo []) then {
        private _point = _hitpoints select floor (_selection * count _hitpoints);
        private _resistance = (_profile get "hitpoints") getOrDefault [toLower (_point select 0),1];
        private _old = _point select 1;
        private _new = (_old + _increment / _resistance) min 1;
        _point set [1,_new];
        _mobilityChanged = _old < 1 && {_new >= 1};
    };
};
_vehicle set ["damage",((_vehicle get "damage") + _increment) min 1];
if (_mobilityChanged) then {[_vehicle] call IVCS_Combat_updateVehicleMobility};
private _lethal = (_vehicle get "damage") >= 1;
private _id = _vehicle get "combatID";
private _casualties = [_vehicle,_ammo,_impact,_lethal,_crewRoll,_profile] call IVCS_Combat_damageCrew;
if (_id != "" && {_casualties > 0}) then {
    private _engagement = (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get _id);
    if (!isNil "_engagement") then {_engagement set ["casualties",(_engagement get "casualties") + _casualties]};
};
if (_lethal) then {[_vehicle] call IVCS_VirtualSpace_unregisterEntity};
