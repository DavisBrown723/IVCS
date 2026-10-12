// Owned waypoints share one completion signal across spawned/virtual simulation.
params ["_context", "_position", ["_type", "MOVE"], ["_radius", 7], ["_properties", []]];
private _entity = [_context get "entityID"] call IVCS_VirtualSpace_getEntity;
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
(_context get "waypoints") pushBack _waypoint;

[_entity, _waypoint] call IVCS_VirtualSpace_entityAddWaypoint;

// A landed helicopter needs its landing order released and a fresh native
// approach command, even when the group already has the new MOVE waypoint.
if (_type == "MOVE" && { _entity get "active" }) then {
    {
        private _vehicle = [_x] call IVCS_VirtualSpace_getEntity;
        if (!isNil "_vehicle" && { _vehicle get "active" } && { (_vehicle get "vehicleType") == "helicopter" }) then {
            private _object = _vehicle get "object";
            _object land "NONE";
            _object engineOn true;
            _object doMove _position;
        };
    } forEach (_entity get "vehiclesInCommandOf");
};
_waypoint
