params ["_entity"];

private _tasks = _entity get "tasks";
if !(_tasks isequalto []) then {
    _tasks select 0
};