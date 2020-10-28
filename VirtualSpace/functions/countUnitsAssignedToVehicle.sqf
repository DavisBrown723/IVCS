params ["_entity","_vehicle"];

private _vehicleID = _vehicle getvariable "id";
private _units = _entity getvariable "units";
private _unitsAssignedToVehicle = {
    private _assignment = _x getvariable "vehicleAssignment";
    private _assignedVehicle = _assignment select 0;

    _assignedVehicle == _vehicleID
} count _units;

_unitsAssignedToVehicle