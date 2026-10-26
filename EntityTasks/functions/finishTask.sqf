params ["_entity", "_task", ["_result", "completed"]];
if ((_task get "status") in ["completed", "failed", "cancelled"]) exitWith {};
_task set ["status", _result];
private _context = _task get "context";
_context set ["result", _result];
private _transition = _entity getOrDefault ["taskTransition", false];
_entity set ["taskTransition", true];
if (_task get "stateEntered") then {
    private _state = (_task get "template" get "states") get (_task get "currentState");
    _task set ["stateEntered", false];
    _context call (_state get "onLeaving");
};
private _active = _entity get "activeTask";
if (!isNil "_active" && { _task isEqualRef _active }) then {
    [_entity, _task] call IVCS_EntityTasks_deactivateTask;
};
private _owned = _task get "waypoints";
{ [_entity, _x] call IVCS_VirtualSpace_entityRemoveWaypoint; } forEach (_owned select [0]);
_owned resize 0;
private _tasks = _entity get "tasks";
private _index = _tasks findIf { (_x get "id") == (_task get "id") };
if (_index != -1) then { _tasks deleteAt _index; };
_context call ((_task get "template") get "onFinish");
_entity set ["taskTransition", _transition];
[_entity] call IVCS_EntityTasks_syncActiveTask;
// Finished, dequeued and reconciled before user callbacks run.
([_task] + (_task get "callbackArgs")) call (_task get "callback");
