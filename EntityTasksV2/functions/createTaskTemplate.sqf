params [
    "_name",
    "_stateMap",
    "_initStateName",
    ["_variables", []]
];


private _states = _statemap apply {
    private _stateName = _x;
    private _stateData = _y;

    private _onEnter = _stateData get "onEnter";
    private _onLeaving = _stateData get "onLeaving";
};

private _taskVars = createHashMapFromArray _variables;

private _task = createHashMapFromArray [
    ["name", _name],
    ["data", _taskVars],
    ["states", _states],
    ["currentState", _stateMap get _initStateName],
];

_task