params ["_groupEntity","_vehicleEntity"];

private _groupEntityID = _groupEntity get "id";
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

private _vehiclesInCargoOf = _groupEntity get "vehiclesInCargoOf";
_vehiclesInCargoOf deleteat (_vehiclesInCargoOf find _vehicleEntityID);

private _entitiesInCargo = _vehicleEntity get "entitiesInCargo";
_entitiesInCargo deleteat (_entitiesInCargo find _groupEntityID);

private _vehicleEntityPosition = _vehicleEntity get "position";
[_groupEntity, _vehicleEntityPosition] call IVCS_VirtualSpace_setEntityPosition;

[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;