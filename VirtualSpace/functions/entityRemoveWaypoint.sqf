params ["_entity","_entityWaypoint"];

private _waypoints = _entity getvariable "waypoints";
private _WpToDeleteID = _entityWaypoint getvariable "name";
private _WpToDeleteIndex = _waypoints findIf {(_x getvariable "name") == _WpToDeleteID};

(_waypoints select _WpToDeleteIndex) call CBA_fnc_deleteNamespace;
_waypoints deleteat _WpToDeleteIndex;

private _maxWaypoint = _entity getvariable "maxWaypoint";
if (_WpToDeleteIndex == _maxWaypoint) then {
    _entity setvariable ["maxWaypoint", _maxWaypoint - 1];
} else {
    if (_WpToDeleteIndex < _maxWaypoint) then {
        [_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
    };
};

private _active = _entity getvariable "active";
if (_active) then {
    private _group = _entity getvariable "group";
    
    deleteWaypoint [_group, _WpToDeleteIndex + 1];
};