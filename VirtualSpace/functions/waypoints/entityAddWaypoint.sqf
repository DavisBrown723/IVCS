params ["_entity", "_entityWaypoint"];
if (isNil { [_entity get "id"] call IVCS_VirtualSpace_getEntity }) exitWith {};

// Preserve the low-level waypoint interface by owning loose sequences in a task.
private _taskID = _entityWaypoint getOrDefault ["taskID", ""];
if (_taskID == "") then {
    private _tasks = _entity get "tasks";
    private _task = if (_tasks isEqualTo []) then { nil } else { _tasks select (count _tasks - 1) };
    if (isNil "_task" || { (_task get "name") != "WAYPOINTS" } || {
        ((_task get "template" get "states") get (_task get "currentState")) get "isEndState"
    }) then {
        _task = ["WAYPOINTS"] call IVCS_EntityTasks_createTaskInstance;
        [_entity, _task] call IVCS_VirtualSpace_entityAddTask;
    };
    _taskID = _task get "id";
    _entityWaypoint set ["taskID", _taskID];
    (_task get "waypoints") pushBack _entityWaypoint;
};
private _ownerTask = [_entity, _taskID] call IVCS_VirtualSpace_getEntityTask;
if (isNil "_ownerTask") exitWith {};
private _owned = _ownerTask get "waypoints";
if !(_entityWaypoint in _owned) then { _owned pushBack _entityWaypoint; };
private _activeTask = _entity get "activeTask";
if (isNil "_activeTask" || { (_activeTask get "id") != _taskID }) exitWith {};
private _waypoints = _entity get "waypoints";
if (_entityWaypoint in _waypoints) exitWith {};
_waypoints pushBack _entityWaypoint;
_entityWaypoint set ["entity", _entity];

if (_entity get "active") then {
    private _group = _entity get "group";
    if (_entity getOrDefault ["movementStopped", false]) then {
        (units _group) doFollow (leader _group);
        _entity set ["movementStopped", false];
    };
    [_entity, _group, _entityWaypoint] call IVCS_VirtualSpace_entityWaypointToWaypoint;
};
if ((_entity get "currentWaypointIndex") == -1) then { _entity set ["currentWaypointIndex", 0]; };
[_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
if !(_entity getOrDefault ["taskTransition", false]) then { [_entity] call IVCS_EntityTasks_resumeMovement; };
