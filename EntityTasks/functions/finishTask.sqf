params ["_entity", "_task", ["_result", "completed"]];

if ((_task get "status") in ["completed", "failed", "cancelled"]) exitWith {};
_task set ["status", _result];
private _context = _task get "context";
_context set ["result", _result];

if (_task get "stateEntered") then {
    private _state = (_task get "template" get "states") get (_task get "currentState");
    _task set ["stateEntered", false];
    _context call (_state get "onLeaving");
};

// Remove only this task's waypoints. Completed waypoints may already be gone.
private _ownedWaypoints = _task get "waypoints";
private _hadMovement = _ownedWaypoints isNotEqualTo [];
{
    [_entity, _x] call IVCS_VirtualSpace_entityRemoveWaypoint;
} forEach _ownedWaypoints;
_ownedWaypoints resize 0;

private _tasks = _entity get "tasks";
private _taskID = _task get "id";
private _index = _tasks findIf { (_x get "id") == _taskID };
if (_index != -1) then { _tasks deleteAt _index; };

// A native AI retains its planned destination after its waypoint is removed.
if (_result != "completed" && { _hadMovement } && { _entity get "active" } &&
    { (_entity get "waypoints") isEqualTo [] }) then {
    doStop (units (_entity get "group"));
    _entity set ["movementStopped", true];
};

// Template cleanup runs for every exit, including pending cancellation.
_context call ((_task get "template") get "onFinish");

// Mark finished and dequeue before invoking user code, so it runs once.
([_task] + (_task get "callbackArgs")) call (_task get "callback");
