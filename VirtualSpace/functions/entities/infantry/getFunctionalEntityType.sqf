params ["_entity"];

private _vehiclesInCommandOf = _entity getvariable "vehiclesInCommandOf";
if (_entity isequalto []) then {
    "group"
} else {
    private _vehicle = [_vehiclesInCommandOf select 0] call IVCS_VirtualSpace_getEntity;
    _vehicle getvariable "vehicleType";
};