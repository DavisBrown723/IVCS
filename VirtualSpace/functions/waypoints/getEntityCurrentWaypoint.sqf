params ["_entity"];

private _waypoints = _entity get "waypoints";
private _currentWaypointIndex = _entity get "currentWaypointIndex";

if (_currentWaypointIndex < count _waypoints) then {
	_waypoints select _currentWaypointIndex
};