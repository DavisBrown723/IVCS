params [
    "_name",
    "_initState",
    ["_args", []]
];

private _taskVars = [] call CBA_fnc_createNamespace;
{
    _taskVars setvariable _x;
} foreach _args;

private _task = [] call CBA_fnc_createNamespace;
_task setvariable ["name", _name];
_task setvariable ["data", _taskVars];
_task setvariable ["currentState", _initState];

_task