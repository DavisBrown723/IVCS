params ["_entity", "_task"];

if ((_task get "status") in ["completed", "failed", "cancelled"]) exitWith {};
private _context = _task get "context";
if ((_task get "status") == "pending") then {
    _task set ["status", "running"];
};

private _states = (_task get "template") get "states";
private _state = _states get (_task get "currentState");
if !(_task get "stateEntered") then {
    _task set ["stateEntered", true];
    _context call (_state get "onEnter");
};

// State callbacks may cancel or replace their own task.
if ((_task get "status") in ["completed", "failed", "cancelled"]) exitWith {};
if (_state get "isEndState") exitWith {
    [_entity, _task, _state get "result"] call IVCS_EntityTasks_finishTask;
};

private _nextState = _context call (_state get "onUpdate");
if ((_task get "status") in ["completed", "failed", "cancelled"]) exitWith {};
if (isNil "_nextState" || { _nextState isEqualTo "" }) exitWith {};
if !(_nextState in _states) exitWith {
    diag_log format ["IVCS EntityTasks: Unknown next state %1 in task %2", _nextState, _task get "name"];
    [_entity, _task, "failed"] call IVCS_EntityTasks_finishTask;
};

_task set ["stateEntered", false];
_context call (_state get "onLeaving");
if ((_task get "status") in ["completed", "failed", "cancelled"]) exitWith {};
_task set ["currentState", _nextState];
