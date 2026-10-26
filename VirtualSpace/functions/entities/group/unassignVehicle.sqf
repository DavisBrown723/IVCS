params ["_groupEntity", "_vehicleEntity"];

private _groupID = _groupEntity get "id";
if ((_vehicleEntity get "commandingEntity") != _groupID) exitWith {};

private _vehicleID = _vehicleEntity get "id";
private _vehicleObject = _vehicleEntity get "object";
private _vehicles = _groupEntity get "vehiclesInCommandOf";
_vehicles deleteAt (_vehicles find _vehicleID);
_vehicleEntity set ["commandingEntity", ""];

// Clear every reservation before native commands can deliver GetOut events.
private _objects = [_groupEntity, _vehicleID] call IVCS_VirtualSpace_Group_releaseVehicleAssignments;
_groupEntity set ["vehicleType", if (_vehicles isEqualTo []) then { "group" } else {
    ([_vehicles select -1] call IVCS_VirtualSpace_getEntity) get "vehicleType"
}];
[_groupEntity, +(_vehicleEntity get "position")] call IVCS_VirtualSpace_setEntityPosition;
[_groupEntity] call IVCS_VirtualSpace_Group_calculateSpeed;
[_groupEntity] call IVCS_VirtualSpace_Group_determinePathfindingStrategy;
[_vehicleEntity] call IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor;
{
    unassignVehicle _x;
    [_x] orderGetIn false;
    _x leaveVehicle _vehicleObject;
} forEach _objects;
