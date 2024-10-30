params ["_entity","_entityWaypoint"];

private _waypoints = _entity get "waypoints";\
private _WpToDeleteIndex = _waypoints find _entityWaypoint;

_waypoints deleteat _WpToDeleteIndex;

private _pathGenerationRequestID = _entityWaypoint get "pathGenerationRequestID";
if (_pathGenerationRequestID != "") then {
    [_pathGenerationRequestID] call IVCS_Paths_removePathRequest;
};

private _minWaypointIndex = _entity get "minWaypointIndex";
private _maxWaypointIndex = _entity get "maxWaypointIndex";
if (_WpToDeleteIndex == _maxWaypointIndex && _maxWaypointIndex > 0) then {
    _maxWaypointIndex = _maxWaypointIndex - 1;
    _entity set ["maxWaypointIndex", _maxWaypointIndex];
};

private _currentWaypointIndex = _entity get "currentWaypointIndex";
if (_currentWaypointIndex >= _minWaypointIndex && { _currentWaypointIndex <= _maxWaypointIndex }) then {
    [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
};

private _active = _entity get "active";
if (_active) then {
    private _group = _entity get "group";
    
    deleteWaypoint [_group, _WpToDeleteIndex];
};