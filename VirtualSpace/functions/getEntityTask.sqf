params ["_entity","_taskID"];

private _tasks = _entity get "tasks";
private _taskIndex = _tasks findif { (_x get "id") == _taskID };
if (_taskIndex != -1) then {
    _tasks select _taskIndex
};