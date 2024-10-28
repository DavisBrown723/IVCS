params ["_entity","_entityWaypoint"];

private _waypoints = _entity get "waypoints";
private _WpToDeleteID = _entityWaypoint get "name";
private _WpToDeleteIndex = _waypoints findIf {(_x get "name") == _WpToDeleteID};

_waypoints deleteat _WpToDeleteIndex;

private _maxWaypoint = _entity get "maxWaypoint";
if (_WpToDeleteIndex == _maxWaypoint && _maxWaypoint > 0) then {
    _entity set ["maxWaypoint", _maxWaypoint - 1];
} else {
    if (_WpToDeleteIndex < _maxWaypoint) then {
        [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
    };
};

private _active = _entity get "active";
if (_active) then {
    private _group = _entity get "group";
    
    deleteWaypoint [_group, _WpToDeleteIndex + 1];
};