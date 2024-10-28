params ["_entity"];

private _units = _entity get "units";

private _allMounted = true;
{
    private _vehicleAssignment = _x get "vehicleAssignment";

    if (_vehicleAssignment isequalto []) exitwith {
        _allMounted = false;
    };
} foreach _units;

private _speed = if (!_allMounted) then {
    4.3
} else {
    private _vehicesInCommandOf = _entity get "vehiclesInCommandOf";
    private _slowestVehicle = 99999;
    
    {
        private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
        private _vehicleSpeed = _vehicleEntity get "speedPerSecond";

        if (_vehicleSpeed < _slowestVehicle) then {
            _slowestVehicle = _vehicleSpeed;
        };
    } foreach _vehicesInCommandOf;

    _slowestVehicle
};

_entity set ["moveSpeedPerSecond", _speed];

_speed