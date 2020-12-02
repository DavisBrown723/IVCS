params ["_groupEntity","_vehicleEntity"];

private _commandingEntity = _vehicleEntity getvariable "commandingEntity";
private _groupEntityID = _groupEntity getvariable "id";
if (_commandingEntity != _groupEntityID) exitwith {};

private _vehicleEntityID = _vehicleEntity getvariable "id";

private _active = _groupEntity getvariable "active";
private _vehicleObject = _vehicleEntity getvariable "object";

private _units = _groupEntity getvariable "units";
{
    private _vehicleAssignment = _x getvariable "vehicleAssignment";
    if !(_vehicleAssignment isequalto []) then {
        _vehicleAssignment params ["_assignedVehicleID","_seat"];

        if (_assignedVehicleID == _vehicleEntityID) then {
            if (_active) then {
                private _unitObject = _x getvariable "object";
                _unitObject leaveVehicle _vehicleObject;
            };

            _seat set [1, ""];
            _x setvariable ["vehicleAssignment", []];
        };
    };
} foreach _units;

private _vehiclesInCommandOf = _groupEntity getvariable "vehiclesInCommandOf";
_vehiclesInCommandOf deleteat (_vehiclesInCommandOf find _vehicleEntityID);

if (_vehiclesInCommandOf isequalto []) then {
    _groupEntity setvariable ["vehicleType", "group"];
} else {
    private _lastAddedVehicle = _vehiclesInCommandOf select ((count _vehiclesInCommandOf) - 1);
    private _lastAddedVehicleEntity = [_lastAddedVehicle] call IVCS_VirtualSpace_getEntity;
    private _lastAddedVehicleType = _lastAddedVehicleEntity getvariable "vehicleType";

    _groupEntity setvariable ["vehicleType", _lastAddedVehicleType];
};

_vehicleEntity setvariable ["commandingEntity", ""];

[_groupEntity] call IVCS_VirtualSpace_Infantry_calculateSpeed;
[_groupEntity] call IVCS_VirtualSpace_Infantry_determinePathfindingStrategy;

[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;