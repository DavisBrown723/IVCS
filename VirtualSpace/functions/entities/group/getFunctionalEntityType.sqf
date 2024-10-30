params ["_entity"];

private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
if (_entity isequalto []) then {
    "group"
} else {
    private _vehicle = [_vehiclesInCommandOf select 0] call IVCS_VirtualSpace_getEntity;
    _vehicle get "vehicleType";
};