params ["_entity","_task",["_append", true]];

private _entityTasks = _entity getvariable "tasks";

if (_append) then {
    _entityTasks pushback _task;
} else {
    _entityTasks = [_task] + _entityTasks;
    _entity setvariable ["tasks", _entityTasks];
};