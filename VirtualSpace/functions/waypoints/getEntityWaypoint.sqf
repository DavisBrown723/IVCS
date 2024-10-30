params ["_entity","_waypointID"];

private _waypoints = _entity get "waypoints";
private _waypointIndex = _waypoints findIf { (_x get "name") == _waypointID };

if (_waypointIndex != -1) then {
    _waypoints select _waypointIndex
};