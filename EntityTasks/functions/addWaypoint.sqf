// Owned waypoints share one completion signal across spawned/virtual simulation.
params ["_context", "_position", ["_type", "MOVE"], ["_radius", 7], ["_properties", []]];
private _entity = [_context get "entityID"] call IVCS_VirtualSpace_getEntity;
if (isNil "_entity") exitWith { nil };
private _task = [_entity, _context get "taskID"] call IVCS_VirtualSpace_getEntityTask;
if (isNil "_task" || { (_task get "status") in ["completed", "failed", "cancelled"] }) exitWith { nil };
private _options = [
    ["speed", _context getOrDefault ["speed", "UNCHANGED"]],
    ["completionRadius", _radius]
] + _properties;
private _waypoint = [_position, _type, _options] call IVCS_VirtualSpace_createEntityWaypoint;
_context set ["waypointComplete", false];
[_waypoint, [_context get "taskID"], {
    params ["_entity", "_waypoint", "_arguments"];
    private _task = [_entity, _arguments select 0] call IVCS_VirtualSpace_getEntityTask;
    if (!isNil "_task") then { (_task get "context") set ["waypointComplete", true]; };
}] call IVCS_VirtualSpace_addWaypointCallback;
_waypoint set ["taskID", _context get "taskID"];
(_context get "waypoints") pushBack _waypoint;

[_entity, _waypoint] call IVCS_VirtualSpace_entityAddWaypoint;
_waypoint
