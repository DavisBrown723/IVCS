params [
    "_name",
    "_initStateName",
    ["_args", []],
    ["_nodes", []],
    ["_callback", {}],
    ["_callbackArgs", []]
];

private _fsmVars = createHashMapFromArray _args;
private _nodeMap = createHashMapFromArray (_nodes apply {
    private _name = _x select 0;
    [_name, _x]
});

private _fsm = createHashMapFromArray [
    ["name", _name],
    ["variables", _fsmVars],
    ["currentState", _nodeMap get _initStateName],
    ["nodes", _nodeMap],
    ["callback", _callback],
    ["callbackArgs", _callbackArgs]
];

_fsm