/*
    Define shared states once. Each state is a list of named properties:
    onEnter, onUpdate, onLeaving, isEndState, and result (completed/failed).
    onUpdate returns the next state name, or nil/"" to remain in this state.
    Callbacks receive the instance's context HashMap as _this.
*/
params ["_name", "_stateDefinitions", "_initialStateName", ["_defaultContext", []], ["_onFinish", {}]];

private _states = createHashMap;
{
    _x params ["_stateName", "_properties"];
    private _state = createHashMapFromArray _properties;
    _state set ["onEnter", _state getOrDefault ["onEnter", {}]];
    _state set ["onUpdate", _state getOrDefault ["onUpdate", {}]];
    _state set ["onLeaving", _state getOrDefault ["onLeaving", {}]];
    _state set ["isEndState", _state getOrDefault ["isEndState", false]];
    _state set ["result", _state getOrDefault ["result", "completed"]];
    _states set [_stateName, _state];
} forEach _stateDefinitions;

if !(_initialStateName in _states) exitWith {
    diag_log format ["IVCS EntityTasks: Unknown initial state %1 in template %2", _initialStateName, _name];
    nil
};

private _defaults = if (_defaultContext isEqualType []) then {
    createHashMapFromArray _defaultContext
} else {
    _defaultContext
};
private _template = createHashMapFromArray [
    ["name", toUpper _name],
    ["context", +_defaults],
    ["states", _states],
    ["initialState", _initialStateName],
    ["onFinish", _onFinish]
];
IVCS_EntityTasks_TaskTemplates set [toUpper _name, _template];
_template
