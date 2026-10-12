params ["_entity","_task",["_append", true]];

// Teardown callbacks may attempt to requeue work after the owner was removed.
if (isNil { [_entity get "id"] call IVCS_VirtualSpace_getEntity }) exitWith {
    diag_log format ["IVCS: Cannot queue a task on removed entity %1", _entity get "id"];
    nil
};

// Task instances are single-use, including instances cancelled before start.
if ((_task get "status") != "pending" || { !isNil { _task get "id" } }) exitWith {
    diag_log "IVCS EntityTasks: Cannot enqueue an already used task instance";
    nil
};
private _entityTasks = _entity get "tasks";

if (_append) then {
    _entityTasks pushback _task;
} else {
    _entityTasks = [_task] + _entityTasks;
    _entity set ["tasks", _entityTasks];
};

private _nextTaskID = _entity getOrDefault ["nextTaskID", 0];
_entity set ["nextTaskID", _nextTaskID + 1];
private _taskID = format ["%1_task_%2", _entity get "id", _nextTaskID];
_task set ["id", _taskID];
private _context = _task get "context";
_context set ["entityID", _entity get "id"];
_context set ["taskID", _taskID];

_taskID