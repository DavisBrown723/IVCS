params ["_entity", "_deltaTime"];

private _currentTask = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
if (!isnil "_currentTask") then {
    [_entity, _currentTask] call IVCS_EntityTasks_processTask;
};

// if we've moved onto a new waypoint
// generate path to destination
// do this outside of normal simulation
// so we can detect entities with no valid path

private _waypoints = _entity getvariable "waypoints";
if !(_waypoints isequalto []) then {
    private _currentWaypointPathGenerated = _entity getvariable "currentWaypointPathGenerated";
    private _pathGenerationInProgress = _entity getvariable "pathGenInProgress";
    if (!_currentWaypointPathGenerated && !_pathGenerationInProgress) then {
        private _currentWaypoint = _waypoints select 0;
        private _waypointPos = _currentWaypoint getvariable "position";

        private _strategy = _entity getvariable "pathfindingStrategy";
        private _entityPos = _entity getvariable "position";
        private _entityID = _entity getvariable "id";
        systemchat format ["Starting Path Gen - %1", diag_tickTime];
        [_strategy, "SAFE", _entityPos, _waypointPos, [_entityID], {
            params ["_entityID","_path"];
            systemchat format ["Path Gen Complete: %1", count _path];
            private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
            private _movePoints = _entity getvariable "movePoints";
            if (_movePoints isequalto []) then {
                {
                    private _marker = createmarker [str _x, _x];
                    _marker setmarkertype "mil_dot";
                    _marker setMarkerSize [0.5, 0.5];
                } foreach _path;

                _entity setvariable ["movePoints", _path];
                _entity setvariable ["pathGenInProgress", false];
                _entity setvariable ["currentWaypointPathGenerated", true];
            };
        }] call IVCS_Paths_generatePath;

        _entity setvariable ["pathGenInProgress", true];

        // this is the first time we've seen this waypoint
        // run any waypoint init code
        private _entityActive = _entity getvariable "active";
        if (!_entityActive) then {
            private _waypointType = _currentWaypoint getvariable "type";
            if (_waypointType != "LAND") then {
                private _vehiclesInCommandOf = _entity getvariable "vehiclesInCommandOf";
                {
                    private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
                    _vehicleEntity setvariable ["engineOn", true];

                    private _vehicleEntityType = _vehicleEntity getvariable "vehicleType";
                    if (_vehicleEntityType in ["helicopter","plane"]) then {
                        private _vehicleEntityPosition = _vehicleEntity getvariable "position";
                        if (_vehicleEntityPosition select 2 < 5) then {
                            _vehicleEntityPosition set [2, 50];
                        };
                    };
                } foreach _vehiclesInCommandOf;
            };
        };
    };
};

private _active = _entity getvariable "active";
if (_active) then {
    private _group = _entity getvariable "group";
    private _newEntityPos = getpos (leader _group);

    private _movePoints = _entity getvariable "movePoints";
    if !(_movePoints isequalto []) then {
        private _nextMovePoint = _movePoints select 0;
        private _distToMovepoint = _newEntityPos distance _nextMovePoint;

        if (_distToMovepoint < 5) then {
            _movePoints deleteat 0;
        };
    };

    [_entity, _newEntityPos] call IVCS_VirtualSpace_setEntityPosition;
} else {
    // simulate waypoints

    private _entityPos = _entity getvariable "position";
    private _waypoints = _entity getvariable "waypoints";
    private _waypointCount = count _waypoints;

    if (_waypointCount > 0) then {
        private _currentWaypoint = _entity getvariable "currentWaypoint";

        if (_currentWaypoint < _waypointCount) then {
            private _waypoint = _waypoints select _currentWaypoint;

            private _currentWaypointPathGenerated = _entity getvariable "currentWaypointPathGenerated";
            if (_currentWaypointPathGenerated ) then {
                // path has been generated
                // lets start moving

                private _movePoints = _entity getvariable "movePoints";
                if !(_movePoints isequalto []) then {
                    private _waypointMoveSpeed = _waypoint getvariable "speed";
                    private _isCycleWp = false;

                    private _entityMoveSpeed = _entity getvariable "moveSpeedPerSecond";
                    switch (_waypointMoveSpeed) do {
                        case "LIMITED": { _entityMoveSpeed = _entityMoveSpeed * 0.5 };
                        case "FAST":    { _entityMoveSpeed = _entityMoveSpeed * 1.3 };
                    };

                    // perform movement

                    private _waypointType = _waypoint getvariable "type";
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
                        case "CYCLE": {
                            _isCycleWp = true;
                        };
                        default {
                            diag_log format ["IVCS - Unspported virtual waypoint type: %1", _waypointType];
                        };
                    };

                    // check wp completion

                    private _distToMovepoint = _entityPos distance2D _nextMovePoint;
                    if (_distToMovepoint < 5) then {
                        _movePoints deleteat 0;
                    };

                    private _waypointPos = _waypoint getvariable "position";
                    private _distRemaining = _entityPos distance2D _waypointPos;
                    private _waypointCompletionRadius = _waypoint getvariable "completionRadius";
                    if (_movePoints isequalto [] || { _distRemaining <= (_waypointCompletionRadius min 7) }) then {
                        [_entity getvariable "id", _waypoint getvariable "name"] call IVCS_VirtualSpace_onWaypointCompleted;
                    };
                };
            };
        };
    };

    // check for nearby enemies

    // private _sightRange = _entity getvariable "sightRange";
    // private _entitySide = _entity getvariable "side";
    // private _allegiances = [_entitySide] call IVCS_Common_getSideAllegiances;
    // private _enemySides = _allegiances select 1;

    // private _nearEnemies = [_entityPos vectoradd [0,0,2], _sightRange, ["group",_enemySides], true] call IVCS_VirtualSpace_getNearEntities;
    // if !(_nearEnemies isequalto []) then {
    //     private _entitySideKnownTargets = [_entitySide] call IVCS_VirtualSpace_getSideKnownTargets;

    //     // register nearby targets with side target registry

    //     {
    //         private _enemy = _x;
    //         private _enemyID = _enemy getvariable "id";
    //         private _knownTargetInfo = _entitySideKnownTargets getvariable _enemyID;
    //         if (isnil "_knownTargetInfo") then {
    //             private _enemyType = [_enemy] call IVCS_VirtualSpace_Infantry_getFunctionalEntityType;

    //             _entitySideKnownTargets setvariable [_enemyID, [_enemyType, 1]];
    //         } else {
    //             _knownTargetInfo set [1, 1];
    //         };
    //     } foreach _nearEnemies;

    //     // engage nearest target

    //     private _reactToContact = _entity getvariable "reactToContact";
    //     [_entity, _nearEnemies] call _reactToContact;
    // };
};

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _entityPos = _entity getvariable "position";
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerPos _entityPos;
};