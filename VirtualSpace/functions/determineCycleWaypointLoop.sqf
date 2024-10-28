params ["_entity"];

private _waypoints = _entity get "waypoints";
private _firstCycleIndex = _waypoints findIf {(_x get "type") == "CYCLE"};
if (_firstCycleIndex == -1) then {
    _entity set ["minWaypoint", 0];
    _entity set ["maxWaypoint", 0];
} else {
    private _firstCycle = _waypoints select _firstCycleIndex;
    private _firstCyclePos = _firstCycle get "position";

    // determine min waypoint
    // closest to cycle
    private _closestWaypointIndex = 0;
    private _closestWaypointPos = (_waypoints select 0) get "position";
    private _closestWaypointDist = _closestWaypointPos distance _firstCyclePos;
    {
        if (_foreachindex > 0) then {
            private _wpType = _x get "type";
            if (_wpType != "CYCLE") then {
                private _wpPos = _x get "position";
                private _distToCycle = _wpPos distance _firstCyclePos;
                if (_distToCycle <= _closestWaypointDist) then {
                    _closestWaypointIndex = _foreachindex;
                    _closestWaypointPos = _wpPos;
                    _closestWaypointDist = _distToCycle;
                };
            };
        };
    } foreach _waypoints;

    private _waypointCount = count _waypoints;
    if (_closestWaypointIndex == _waypointCount - 1) then {
        _closestWaypointIndex = 0;
    };

    _entity set ["minWaypoint", _closestWaypointIndex];
    _entity set ["maxWaypoint", _waypointCount - 2]; // ignore last waypoint (cycle), substract one more to zero-index
};