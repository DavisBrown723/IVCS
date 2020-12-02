params ["_entity","_taskID"];

private _tasks = _entity getvariable "tasks";
private _taskIndex = _tasks findif { (_x getvariable "id") == _taskID };
if (_taskIndex != -1) then {
    _tasks select _taskIndex
};