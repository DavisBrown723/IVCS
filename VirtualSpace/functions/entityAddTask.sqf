params ["_entity","_task",["_append", true]];

private _entityTasks = _entity getvariable "tasks";

if (_append) then {
    _entityTasks pushback _task;
} else {
    _entityTasks = [_task] + _entityTasks;
    _entity setvariable ["tasks", _entityTasks];
};

private _taskID = format ["%1_%2", diag_tickTime, count _entityTasks];
_task setvariable ["id", _taskID];

_taskID