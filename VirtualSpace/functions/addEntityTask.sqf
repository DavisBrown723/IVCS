params ["_entity","_taskName","_taskContext"];

private _taskInstance = [_taskName, [_entity] + _taskContext] call IVCS_EntityTasks_createTaskInstance;
private _taskPriority = _taskInstance get "priority";

private _entityTasks = _entity get "tasks";
_entityTasks pushback [_taskPriority, _taskInstance];

_entityTasks sort false;

_taskInstance