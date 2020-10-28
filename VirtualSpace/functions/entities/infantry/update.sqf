params ["_entity", "_deltaTime"];

[_entity] call IVCS_EntityTasks_processTask;

private _active = _entity getvariable "active";
if (_active) then {
    private _group = _entity getvariable "group";

    private _newEntityPos = getpos (leader _group);
    _entity setvariable ["position", _newEntityPos];
} else {

    // simulate waypoints

    private _entityPos = _entity getvariable "position";
    private _waypoints = _entity getvariable "waypoints";
    private _waypointCount = count _waypoints;
    
    if (_waypointCount > 0) then {
        private _currentWaypoint = _entity getvariable "currentWaypoint";
        
        if (_currentWaypoint <= _waypointCount) then {
            private _waypoint = _waypoints select _currentWaypoint;
            private _waypointMoveSpeed = _waypoint getvariable "speed";
            private _isCycleWp = false;

            private _entityMoveSpeed = _entity getvariable "moveSpeedPerSecond";
            switch (_waypointMoveSpeed) do {
                case "LIMITED": { _entityMoveSpeed = _entityMoveSpeed * 0.5 };
                case "FAST":    { _entityMoveSpeed = _entityMoveSpeed * 1.3 };
            };

            // perform movement

            private _waypointType = _waypoint getvariable "type";
            private _waypointPos = _waypoint getvariable "position";

            switch (_waypointType) do {
                case "MOVE": {
                    private _distRemaining = _entityPos distance _waypointPos;
                    private _moveDir = _entityPos getdir _waypointPos;
                    private _moveDist = (_entityMoveSpeed * _deltaTime) min _distRemaining;
                    private _endPos = _entityPos getPos [_moveDist, _moveDir];

                    _entity setvariable ["position", _endPos];
                };
                case "CYCLE": {
                    _isCycleWp = true;
                };
                default {
                    diag_log format ["IVCS - Unspported virtual waypoint type: %1", _waypointType];
                };
            };

            // check wp completion

            private _distRemaining = _entityPos distance _waypointPos;
            private _waypointCompletionRadius = _waypoint getvariable "completionRadius";
            if (_distRemaining <= _waypointCompletionRadius + 5) then {
                [_entity getvariable "id", _waypoint getvariable "name"] call IVCS_VirtualSpace_onWaypointCompleted;
            };
        };
    };
};

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _entityPos = _entity getvariable "position";
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerPos _entityPos;
};