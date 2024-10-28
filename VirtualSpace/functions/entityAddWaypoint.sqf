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
private _minWaypoint = _entity get "minWaypoint";
if (_wpType == "CYCLE" && _minWaypoint == 0) then {
    [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
};

private _currentWaypoint = _entity get "currentWaypoint";
if (_currentWaypoint == -1) then {
    _entity set ["currentWaypoint", 0];
};