params ["_entity","_vehicle"];

private _entityID = _entity getvariable "id";
private _vehicleAssignedEntity = _vehicle getvariable "assignedEntity";
if (_vehicleAssignedEntity == "" || _vehicleAssignedEntity != _entityID) exitwith {
    false
};

// unassign units from seats

private _units = _entity getvariable "units";
private _vehicleSeats = _vehicle getvariable "seats";
private _vehicleID = _vehicle getvariable "id";
{
    private _assignment = _x getvariable "vehicleAssignment";
    _assignment params ["_vehicleID","_seat"];

    if (_vehicleID == _vehicleID) then {
        _seat set [0, ""];
        _x setvariable ["vehicleAssignment", []];
    };
} foreach _units;

private _assignedVehicles = _entity getvariable "assignedVehicles";
_assignedVehicles deleteat (_assignedVehicles find _vehicleID);

_vehicle setvariable ["assignedEntity", ""];

private _vehicleDebugMarker = _vehicle getvariable "debugMarker";
if (_vehicleDebugMarker != "") then {
    private _entitySideColor = ["NONE"] call IVCS_Common_sideStringToColor;
    _vehicleDebugMarker setMarkerColor _entitySideColor;
};

true