params ["_entity"];

// give tasks a chance to exit
// process once to select next state
// process again to execute next state

[_entity] call IVCS_EntityTasks_processTask;
[_entity] call IVCS_EntityTasks_processTask;

// clean up namespace objects

private _tasks = _entity getvariable "tasks";
{
    [_x] call IVCS_EntityTasks_deleteTask;
} foreach _tasks;

private _waypoints = _entity getvariable "waypoints";
{
    _x call CBA_fnc_deleteNamespace;
} foreach _waypoints;

private _units = _entity getvariable "units";
{
    _x call CBA_fnc_deleteNamespace;
} foreach _units;

private _debugMarker = _entity getvariable "debugMarker";
deleteMarker _debugMarker;