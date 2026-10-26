params ["_entity"];

private _waypoints = _entity get "waypoints";
private _currentIndex = _entity get "currentWaypointIndex";
_entity set ["minWaypointIndex", -1];
_entity set ["maxWaypointIndex", -1];
if (_waypoints findIf { (_x get "type") == "CYCLE" } == -1) exitWith {};

private _loops = [_entity] call IVCS_VirtualSpace_findEntityWaypointLoops;
private _index = _loops findIf {
    _x params ["_lower", "_upper"];
    _currentIndex >= _lower && { _currentIndex <= _upper }
};
if (_index != -1) then {
    (_loops select _index) params ["_lower", "_upper"];
    _entity set ["minWaypointIndex", _lower];
    _entity set ["maxWaypointIndex", _upper];
};
