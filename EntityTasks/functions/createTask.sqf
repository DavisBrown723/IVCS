params [
    "_name",
    "_initState",
    ["_args", []],
    ["_callback", {}],
    ["_callbackArgs", []]
];

private _taskVars = [] call CBA_fnc_createNamespace;
{
    _taskVars setvariable _x;
} foreach _args;

private _task = [] call CBA_fnc_createNamespace;
_task setvariable ["name", _name];
_task setvariable ["data", _taskVars];
_task setvariable ["currentState", _initState];
_task setvariable ["callback", _callback];
_task setvariable ["callbackArgs", _callbackArgs];
_task setvariable ["timeLastProcess", -9999];

_task