params ["_entity","_vehicle"];

private _vehicleID = _vehicle get "id";
private _units = _entity get "units";
private _unitsAssignedToVehicle = {
    private _assignment = _x get "vehicleAssignment";
    private _assignedVehicle = _assignment select 0;

    _assignedVehicle == _vehicleID
} count _units;

_unitsAssignedToVehicle