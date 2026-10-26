params ["_entity"];
[_entity] call IVCS_Ammo_cancelGroup;

(_entity get "combatWaypointCompletions") resize 0;
[_entity] call IVCS_Combat_onRemoved;

// Snapshot the queue without copying instances, then detach it before callbacks.
// The registry entry is already gone; callbacks cannot enqueue new owner work.
private _tasks = (_entity get "tasks") select [0];
(_entity get "tasks") resize 0;
{
    [_entity, _x, "failed"] call IVCS_EntityTasks_finishTask;
} forEach _tasks;

// Cancel remaining owner waypoints, including those created outside tasks.
private _waypoints = _entity get "waypoints";
while { _waypoints isNotEqualTo [] } do {
    [_entity, _waypoints select 0] call IVCS_VirtualSpace_entityRemoveWaypoint;
};

// Release transport links while the vehicle profiles are still available.
{
    private _vehicle = [_x] call IVCS_VirtualSpace_getEntity;
    [_entity, _vehicle] call IVCS_VirtualSpace_Group_unassignVehicle;
} forEach +(_entity get "vehiclesInCommandOf");
{
    private _vehicle = [_x] call IVCS_VirtualSpace_getEntity;
    [_entity, _vehicle] call IVCS_VirtualSpace_Group_unassignAsVehicleCargo;
} forEach +(_entity get "vehiclesInCargoOf");

deleteMarker (_entity get "debugMarker");
