params [
    "_name",
    "_initStateName",
    ["_args", []],
    ["_nodes", []],
    ["_callback", {}],
    ["_callbackArgs", []]
];

private _fsmVars = [] call CBA_fnc_createNamespace;
{
    _fsmVars setvariable _x;
} foreach _args;

private _nodeMap = [] call CBA_fnc_createNamespace;
{
    private _name = _x select 0;
    _nodeMap setvariable [_name, _x];
} foreach _nodes;

private _fsm = [] call CBA_fnc_createNamespace;
_fsm setvariable ["name", _name];
_fsm setvariable ["data", _fsmVars];
_fsm setvariable ["currentState", _nodeMap getvariable _initStateName];
_fsm setvariable ["nodes", _nodeMap];
_fsm setvariable ["callback", _callback];
_fsm setvariable ["callbackArgs", _callbackArgs];

_fsm