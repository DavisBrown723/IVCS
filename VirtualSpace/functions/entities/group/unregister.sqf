params ["_entity"];

// give tasks a chance to exit
// process once to select next state
// process again to execute next state

[_entity] call IVCS_EntityTasks_processTask;
[_entity] call IVCS_EntityTasks_processTask;

private _debugMarker = _entity get "debugMarker";
deleteMarker _debugMarker;