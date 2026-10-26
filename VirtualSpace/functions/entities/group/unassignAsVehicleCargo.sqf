params ["_groupEntity", "_vehicleEntity"];

private _vehicleID = _vehicleEntity get "id";
private _vehicles = _groupEntity get "vehiclesInCargoOf";
private _index = _vehicles find _vehicleID;
if (_index == -1) exitWith {};

_vehicles deleteAt _index;
private _cargo = _vehicleEntity get "entitiesInCargo";
_cargo deleteAt (_cargo find (_groupEntity get "id"));
private _objects = [_groupEntity, _vehicleID] call IVCS_VirtualSpace_Group_releaseVehicleAssignments;
[_groupEntity, +(_vehicleEntity get "position")] call IVCS_VirtualSpace_setEntityPosition;
[_groupEntity] call IVCS_VirtualSpace_Group_calculateSpeed;
[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;
{
    unassignVehicle _x;
    [_x] orderGetIn false;
    _x leaveVehicle (_vehicleEntity get "object");
} forEach _objects;
