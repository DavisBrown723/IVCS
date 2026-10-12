params ["_entity"];

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

deleteMarker (_entity get "debugMarker");
