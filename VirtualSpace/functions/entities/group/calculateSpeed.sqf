params ["_entity"];

private _vehicles = (_entity get "vehiclesInCommandOf") + (_entity get "vehiclesInCargoOf");
private _speed = 4.3;
if (_vehicles isNotEqualTo [] && {
    (_entity get "units") findIf { (_x get "vehicleAssignment") isEqualTo [] } == -1
}) then {
    _speed = selectMin (_vehicles apply {
        ([_x] call IVCS_VirtualSpace_getEntity) get "speedPerSecond"
    });
};
_entity set ["moveSpeedPerSecond", _speed];

_speed
