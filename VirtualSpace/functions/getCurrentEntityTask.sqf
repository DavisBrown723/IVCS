params ["_entity"];

private _tasks = _entity getvariable "tasks";
if !(_tasks isequalto []) then {
    _tasks select 0
};