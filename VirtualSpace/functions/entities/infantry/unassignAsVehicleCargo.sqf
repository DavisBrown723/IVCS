params ["_groupEntity","_vehicleEntity"];

private _groupEntityID = _groupEntity getvariable "id";
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

private _vehiclesInCargoOf = _groupEntity getvariable "vehiclesInCargoOf";
_vehiclesInCargoOf deleteat (_vehiclesInCargoOf find _vehicleEntityID);

private _entitiesInCargo = _vehicleEntity getvariable "entitiesInCargo";
_entitiesInCargo deleteat (_entitiesInCargo find _groupEntityID);

private _vehicleEntityPosition = _vehicleEntity getvariable "position";
_groupEntity setvariable ["position", _vehicleEntityPosition];

[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;