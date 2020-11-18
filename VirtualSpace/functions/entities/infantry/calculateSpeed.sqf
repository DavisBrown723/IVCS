params ["_entity"];

private _units = _entity getvariable "units";

private _allMounted = true;
{
    private _vehicleAssignment = _x getvariable "vehicleAssignment";

    if (_vehicleAssignment isequalto []) exitwith {
        _allMounted = false;
    };
} foreach _units;

private _speed = if (!_allMounted) then {
    4.3
} else {
    private _assignedVehicles = _entity getvariable "assignedVehicles";
    private _slowestVehicle = 99999;
    {
        private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
        private _vehicleSpeed = _vehicleEntity getvariable "speedPerSecond";

        if (_vehicleSpeed < _slowestVehicle) then {
            _slowestVehicle = _vehicleSpeed;
        };
    } foreach _assignedVehicles;

    _slowestVehicle
};

_entity setvariable ["moveSpeedPerSecond", _speed];

_speed