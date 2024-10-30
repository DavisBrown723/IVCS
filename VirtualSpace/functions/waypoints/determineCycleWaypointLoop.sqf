/*
    Cycle waypoints work by forming a loop between existing waypoints.
    The last waypoint in this loop is the waypoint directly before the cycle waypoint with regards to waypoint index.
    The first waypoint in this loop is the waypoint that is closest in 2d space to the cycle waypoint.
    If there are two cycle waypoints in a groups waypoint list, they can form separate loops, the group will only follow the current loop (determined by currentWaypoint)
    Edge Cases:
        - All waypoints added after the first cycle waypoint are completely ignored while the cycle exists.
        - If a cycle waypoint is the first waypoint, all waypoints are ignored
*/

params ["_entity"];

private _waypoints = _entity get "waypoints";
private _currentWaypointIndex = _entity get "currentWaypointIndex";
private _cycleWaypoints = (_waypoints select { (_x get "type") == "CYCLE" }) apply { [_waypoints find _x, _x] };
if (_cycleWaypoints isequalto []) then {
    _entity set ["minWaypointIndex", -1];
    _entity set ["maxWaypointIndex", -1];
} else {
    private _waypointLoops = [_entity] call IVCS_VirtualSpace_findEntityWaypointLoops;

    private _currentLoopIndex = _waypointLoops findIf {
        _x params ["_lowerBoundIndex","_upperBoundIndex"];

        _currentWaypointIndex >= _lowerBoundIndex && _currentWaypointIndex <= _upperBoundIndex
    };

    if (_currentLoopIndex != -1) then {
        private _currentLoop = _waypointLoops select _currentLoopIndex;
        _currentLoop params ["_lowerBoundIndex","_upperBoundIndex"];

        _entity set ["minWaypointIndex", _lowerBoundIndex];
        _entity set ["maxWaypointIndex", _upperBoundIndex];
    };
};