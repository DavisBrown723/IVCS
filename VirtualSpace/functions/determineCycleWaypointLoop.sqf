params ["_entity"];

private _waypoints = _entity getvariable "waypoints";
private _firstCycleIndex = _waypoints findIf {(_x getvariable "type") == "CYCLE"};
if (_firstCycleIndex == -1) then {
    _entity setvariable ["minWaypoint", 0];
    _entity setvariable ["maxWaypoint", 0];
} else {
    private _firstCycle = _waypoints select _firstCycleIndex;
    private _firstCyclePos = _firstCycle getvariable "position";

    // determine min waypoint
    // closest to cycle
    private _closestWaypointIndex = 0;
    private _closestWaypointPos = (_waypoints select 0) getvariable "position";
    private _closestWaypointDist = _closestWaypointPos distance _firstCyclePos;
    {
        if (_foreachindex > 0) then {
            private _wpType = _x getvariable "type";
            if (_wpType != "CYCLE") then {
                private _wpPos = _x getvariable "position";
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

    _entity setvariable ["minWaypoint", _closestWaypointIndex];
    _entity setvariable ["maxWaypoint", _waypointCount - 2]; // ignore last waypoint (cycle), substract one more to zero-index
};