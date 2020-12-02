params ["_fsm"];

private _taskData = _fsm getvariable "data";
_taskData call CBA_fnc_deleteNamespace;

private _nodeMap = _fsm getvariable "nodes";
_nodeMap call CBA_fnc_deleteNamespace;

_fsm call CBA_fnc_deleteNamespace;