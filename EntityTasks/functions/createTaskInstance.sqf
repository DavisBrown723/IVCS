/*
    Context accepts named pairs or a HashMap. Mutable defaults and overrides
    are copied per instance; templates and state callback code remain shared.
    entityID, taskID, and waypoints are reserved for the task processor.
    Enqueue the returned instance with IVCS_VirtualSpace_entityAddTask.
*/
params ["_templateName", ["_instanceContext", []]];

private _template = IVCS_EntityTasks_TaskTemplates get (toUpper _templateName);
if (isNil "_template") exitWith {
    diag_log format ["IVCS EntityTasks: Unknown task template %1", _templateName];
    nil
};
private _overrides = if (_instanceContext isEqualType []) then {
    createHashMapFromArray _instanceContext
} else {
    _instanceContext
};
// Merge definitions first, then copy once to isolate the resulting context.
private _context = createHashMap;
_context merge [_template get "context", true];
_context merge [_overrides, true];
_context = +_context;

private _waypoints = [];
_context set ["waypoints", _waypoints];
createHashMapFromArray [
    ["name", _template get "name"],
    ["template", _template],
    ["context", _context],
    ["currentState", _template get "initialState"],
    ["stateEntered", false],
    ["status", "pending"],
    ["waypoints", _waypoints],
    ["callback", {}],
    ["callbackArgs", []]
]
