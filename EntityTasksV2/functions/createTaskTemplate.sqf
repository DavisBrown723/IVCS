params [
    "_name",
    "_priority",
    "_stateMap",
    "_initStateName",
    ["_variables", []]
];


private _states = (createHashMapFromArray _statemap) apply {
    private _stateName = _x;
    private _stateData = createHashMapFromArray _y;

    private _onEnter = _stateData getOrDefault ["onEnter", {}];
    private _onLeaving = _stateData getOrDefault ["onLeaving", {}];
    private _onUpdate = _stateData getOrDefault ["onUpdate", {}];

    private _transitions = _stateData getOrDefault ["transitions", {}];

    [_stateName, [
        ["onEnter", _onEnter],
        ["onLeaving", _onLeaving],
        ["onUpdate", _onUpdate],
        ["transitions", _transitions]
    ]]
};

private _taskVars = createHashMapFromArray _variables;

private _task = createHashMapFromArray [
    ["name", _name],
    ["priority", _priority],
    ["data", _taskVars],
    ["states", createHashMapFromArray _states],
    ["initState", _stateMap get _initStateName],
    ["waypoints", []]
];

IVCS_EntityTasks_TaskTemplates set [_name, _task];

_task