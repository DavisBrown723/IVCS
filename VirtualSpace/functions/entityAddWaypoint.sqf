params ["_entity","_entityWaypoint"];

private _waypoints = _entity getvariable "waypoints";
_waypoints pushback _entityWaypoint;

private _active = _entity getvariable "active";
if (_active) then {
    private _group = _entity getvariable "group";

    [_entity, _group, _entityWaypoint] call IVCS_VirtualSpace_entityWaypointToWaypoint;
};

// if cycle waypoint and no other cycle waypoints exist
// calculate cycle loop

private _wpType = _entityWaypoint getvariable "type";
private _minWaypoint = _entity getvariable "minWaypoint";
if (_wpType == "CYCLE" && _minWaypoint == 0) then {
    [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
};

private _currentWaypoint = _entity getvariable "currentWaypoint";
if (_currentWaypoint == -1) then {
    _entity setvariable ["currentWaypoint", 0];
};