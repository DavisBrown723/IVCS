params ["_entity", "_deltaTime"];

private _currentTask = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
if (!isnil "_currentTask") then {
    [_entity, _currentTask] call IVCS_EntityTasks_processTask;
};

private _active = _entity get "active";
if (_active) then {
    private _group = _entity get "group";

    // private _currentWaypoint = [_entity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
    // if (!isnil "_currentWaypoint") then {
    //     private _movePoints = _currentWaypoint get "movePoints";

    //     if !(_movePoints isequalto []) then {
    //         private _nextMovePoint = _movePoints select 0;
    //         private _distToMovepoint = _newEntityPos distance _nextMovePoint;

    //         if (_distToMovepoint < 5) then {
    //             _movePoints deleteat 0;
    //         };
    //     };
    // };

    private _newEntityPos = getpos (leader _group);
    [_entity, _newEntityPos] call IVCS_VirtualSpace_setEntityPosition;
} else {
    // simulate waypoints

    private _currentWaypointIndex = _entity get "currentWaypointIndex";
    private _minWaypointIndex = _entity get "minWaypointIndex";
    private _maxWaypointIndex = _entity get "maxWaypointIndex";

    private _currentWaypoint = [_entity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
    if (!isnil "_currentWaypoint") then {
        private _initialized = _currentWaypoint get "initialized";
        if (!_initialized) then {
            [_entity,_currentWaypoint] call IVCS_VirtualSpace_onWaypointStarted;
        } else {
            private _pathGenerationRequestID = _currentWaypoint get "pathGenerationRequestID";
            if (_pathGenerationRequestID == "") then {
                private _waypointID = _currentWaypoint get "name";
                private _waypointPos = _currentWaypoint get "position";

                private _strategy = _entity get "pathfindingStrategy";
                private _entityPos = _entity get "position";
                private _entityID = _entity get "id";

                private _requestID = [_strategy, "SAFE", _entityPos, _waypointPos, [_entityID,_waypointID], IVCS_VirtualSpace_Group_onWaypointPathGenerated] call IVCS_Paths_createPathRequest;
                _currentWaypoint set ["pathGenerationRequestID", _requestID];
            } else {
                // waypoint is initialized and has a path
                // we can start simulating it

                private _movePoints = _currentWaypoint get "movePoints";
                if (_movePoints isnotequalto []) then {
                    private _waypointMoveSpeed = _currentWaypoint get "speed";

                    private _entityMoveSpeed = _entity get "moveSpeedPerSecond";
                    switch (_waypointMoveSpeed) do {
                        case "LIMITED": { _entityMoveSpeed = _entityMoveSpeed * 0.5 };
                        case "FAST":    { _entityMoveSpeed = _entityMoveSpeed * 1.3 };
                    };

                    // perform movement

                    private _entityPos = _entity get "position";
                    private _waypointType = _currentWaypoint get "type";
                    private _nextMovePoint = _movePoints select 0;

                    switch (_waypointType) do {
                        case "LAND";
                        case "MOVE": {
                            private _distRemaining = _entityPos distance _nextMovePoint;
                            private _moveDir = _entityPos getdir _nextMovePoint;
                            private _moveDist = (_entityMoveSpeed * _deltaTime) min _distRemaining;
                            private _endPos = _entityPos getPos [_moveDist, _moveDir];

                            _endPos set [2, _entityPos select 2];

                            [_entity, _endPos] call IVCS_VirtualSpace_setEntityPosition;
                        };
                        default {
                            diag_log format ["IVCS - Unsupported virtual waypoint type: %1", _waypointType];
                        };
                    };

                    // check wp completion

                    private _distToMovepoint = _entityPos distance2D _nextMovePoint;
                    if (_distToMovepoint < 5) then {
                        _movePoints deleteat 0;
                    };

                    private _waypointPos = _currentWaypoint get "position";
                    private _distRemaining = _entityPos distance2D _waypointPos;
                    private _waypointCompletionRadius = _currentWaypoint get "completionRadius";
                    if (_movePoints isequalto [] || { _distRemaining <= (_waypointCompletionRadius max 7) }) then {
                        systemchat format ["Finishing waypoint: %1 %2", _currentWaypoint get "name", [_movePoints isequalto [], _distRemaining <= (_waypointCompletionRadius max 7)]];
                        [_entity get "id", _currentWaypoint get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
                    };
                } else {
                    private _type = _currentWaypoint get "type";
                    private _pathGenID = _currentWaypoint get "pathGenerationRequestID";
                    systemchat format ["no move points %1: %2 - %3 - %4", diag_ticktime, _currentWaypointIndex, _type, _pathGenID];
                };
            };
        };
    };
};

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _entityPos = _entity get "position";
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerPos _entityPos;
};