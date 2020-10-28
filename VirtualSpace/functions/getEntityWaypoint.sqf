params ["_entity","_waypointID"];

private _waypoints = _entity getvariable "waypoints";
private _waypointIndex = _waypoints findIf {(_x getvariable "name") == _waypointID};

if (_waypointIndex != -1) then {
    _waypoints select _waypointIndex;
};