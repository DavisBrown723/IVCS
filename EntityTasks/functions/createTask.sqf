params [
    "_name",
    "_initState",
    ["_args", []],
    ["_callback", {}],
    ["_callbackArgs", []]
];

private _taskVars = createHashMapFromArray _args;

private _task = createHashMapFromArray [
    ["name", _name],
    ["data", _taskVars],
    ["currentState", _initState],
    ["callback", _callback],
    ["callbackArgs", _callbackArgs],
    ["timeLastProcess", -9999]
];

_task