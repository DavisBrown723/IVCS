params ["_groupEntity","_vehicleEntity"];

private _commandingEntity = _vehicleEntity get "commandingEntity";
private _groupEntityID = _groupEntity get "id";
if (_commandingEntity != _groupEntityID) exitwith {};

private _vehicleEntityID = _vehicleEntity get "id";

private _active = _groupEntity get "active";
private _vehicleObject = _vehicleEntity get "object";

private _units = _groupEntity get "units";
{
    private _vehicleAssignment = _x get "vehicleAssignment";
    if !(_vehicleAssignment isequalto []) then {
        _vehicleAssignment params ["_assignedVehicleID","_seat"];

        if (_assignedVehicleID == _vehicleEntityID) then {
            if (_active) then {
                private _unitObject = _x get "object";
                _unitObject leaveVehicle _vehicleObject;
            };

            _seat set [1, ""];
            _x set ["vehicleAssignment", []];
        };
    };
} foreach _units;

private _vehiclesInCommandOf = _groupEntity get "vehiclesInCommandOf";
_vehiclesInCommandOf deleteat (_vehiclesInCommandOf find _vehicleEntityID);

if (_vehiclesInCommandOf isequalto []) then {
    _groupEntity set ["vehicleType", "group"];
} else {
    private _lastAddedVehicle = _vehiclesInCommandOf select ((count _vehiclesInCommandOf) - 1);
    private _lastAddedVehicleEntity = [_lastAddedVehicle] call IVCS_VirtualSpace_getEntity;
    private _lastAddedVehicleType = _lastAddedVehicleEntity get "vehicleType";

    _groupEntity set ["vehicleType", _lastAddedVehicleType];
};

_vehicleEntity set ["commandingEntity", ""];

[_groupEntity] call IVCS_VirtualSpace_Group_calculateSpeed;
[_groupEntity] call IVCS_VirtualSpace_Group_determinePathfindingStrategy;

[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;