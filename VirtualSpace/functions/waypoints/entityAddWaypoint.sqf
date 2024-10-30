 params ["_entity","_entityWaypoint"];

private _waypoints = _entity get "waypoints";
_waypoints pushback _entityWaypoint;

private _active = _entity get "active";
if (_active) then {
    private _group = _entity get "group";

    [_entity, _group, _entityWaypoint] call IVCS_VirtualSpace_entityWaypointToWaypoint;
};

// if cycle waypoint and no other cycle waypoints exist
// calculate cycle loop

private _wpType = _entityWaypoint get "type";
private _minWaypointIndex = _entity get "minWaypointIndex";
if (_wpType == "CYCLE" && _minWaypointIndex == -1) then {
    [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
};

private _currentWaypointIndex = _entity get "currentWaypointIndex";
if (_currentWaypointIndex == -1) then {
    _entity set ["currentWaypointIndex", 0];
};