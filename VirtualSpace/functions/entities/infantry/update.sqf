params ["_entity", "_deltaTime"];

private _currentTask = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
if (!isnil "_currentTask") then {
    [_entity, _currentTask] call IVCS_EntityTasks_processTask;
};

// if we've moved onto a new waypoint
// generate path to destination
// do this outside of normal simulation
// so we can detect entities with no valid path

private _waypoints = _entity get "waypoints";
if !(_waypoints isequalto []) then {
    private _currentWaypointPathGenerated = _entity get "currentWaypointPathGenerated";
    private _pathGenerationInProgress = _entity get "pathGenInProgress";
    if (!_currentWaypointPathGenerated && !_pathGenerationInProgress) then {
        private _currentWaypoint = _waypoints select 0;
        private _waypointPos = _currentWaypoint get "position";

        private _strategy = _entity get "pathfindingStrategy";
        private _entityPos = _entity get "position";
        private _entityID = _entity get "id";
        systemchat format ["Starting Path Gen - %1", diag_tickTime];
        [_strategy, "SAFE", _entityPos, _waypointPos, [_entityID], {
            params ["_entityID","_path"];
            systemchat format ["Path Gen Complete: %1", count _path];
            private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
            private _movePoints = _entity get "movePoints";
            if (_movePoints isequalto []) then {
                {
                    private _marker = createmarker [str _x, _x];
                    _marker setmarkertype "mil_dot";
                    _marker setMarkerSize [0.5, 0.5];
                } foreach _path;

                _entity set ["movePoints", _path];
                _entity set ["pathGenInProgress", false];
                _entity set ["currentWaypointPathGenerated", true];
            };
        }] call IVCS_Paths_generatePath;

        _entity set ["pathGenInProgress", true];

        // this is the first time we've seen this waypoint
        // run any waypoint init code
        private _entityActive = _entity get "active";
        if (!_entityActive) then {
            private _waypointType = _currentWaypoint get "type";
            if (_waypointType != "LAND") then {
                private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
                {
                    private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
                    _vehicleEntity set ["engineOn", true];

                    private _vehicleEntityType = _vehicleEntity get "vehicleType";
                    if (_vehicleEntityType in ["helicopter","plane"]) then {
                        private _vehicleEntityPosition = _vehicleEntity get "position";
                        if (_vehicleEntityPosition select 2 < 5) then {
                            _vehicleEntityPosition set [2, 50];
                        };
                    };
                } foreach _vehiclesInCommandOf;
            };
        };
    };
};

private _active = _entity get "active";
if (_active) then {
    private _group = _entity get "group";
    private _newEntityPos = getpos (leader _group);

    private _movePoints = _entity get "movePoints";
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

    private _entityPos = _entity get "position";
    private _waypoints = _entity get "waypoints";
    private _waypointCount = count _waypoints;

    if (_waypointCount > 0) then {
        private _currentWaypoint = _entity get "currentWaypoint";

        if (_currentWaypoint < _waypointCount) then {
            private _waypoint = _waypoints select _currentWaypoint;

            private _currentWaypointPathGenerated = _entity get "currentWaypointPathGenerated";
            if (_currentWaypointPathGenerated ) then {
                // path has been generated
                // lets start moving

                private _movePoints = _entity get "movePoints";
                if !(_movePoints isequalto []) then {
                    private _waypointMoveSpeed = _waypoint get "speed";
                    private _isCycleWp = false;

                    private _entityMoveSpeed = _entity get "moveSpeedPerSecond";
                    switch (_waypointMoveSpeed) do {
                        case "LIMITED": { _entityMoveSpeed = _entityMoveSpeed * 0.5 };
                        case "FAST":    { _entityMoveSpeed = _entityMoveSpeed * 1.3 };
                    };

                    // perform movement

                    private _waypointType = _waypoint get "type";
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

                    private _waypointPos = _waypoint get "position";
                    private _distRemaining = _entityPos distance2D _waypointPos;
                    private _waypointCompletionRadius = _waypoint get "completionRadius";
                    if (_movePoints isequalto [] || { _distRemaining <= (_waypointCompletionRadius min 7) }) then {
                        [_entity get "id", _waypoint get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
                    };
                };
            };
        };
    };

    // check for nearby enemies

    // private _sightRange = _entity get "sightRange";
    // private _entitySide = _entity get "side";
    // private _allegiances = [_entitySide] call IVCS_Common_getSideAllegiances;
    // private _enemySides = _allegiances select 1;

    // private _nearEnemies = [_entityPos vectoradd [0,0,2], _sightRange, ["group",_enemySides], true] call IVCS_VirtualSpace_getNearEntities;
    // if !(_nearEnemies isequalto []) then {
    //     private _entitySideKnownTargets = [_entitySide] call IVCS_VirtualSpace_getSideKnownTargets;

    //     // register nearby targets with side target registry

    //     {
    //         private _enemy = _x;
    //         private _enemyID = _enemy get "id";
    //         private _knownTargetInfo = _entitySideKnownTargets get _enemyID;
    //         if (isnil "_knownTargetInfo") then {
    //             private _enemyType = [_enemy] call IVCS_VirtualSpace_Infantry_getFunctionalEntityType;

    //             _entitySideKnownTargets set [_enemyID, [_enemyType, 1]];
    //         } else {
    //             _knownTargetInfo set [1, 1];
    //         };
    //     } foreach _nearEnemies;

    //     // engage nearest target

    //     private _reactToContact = _entity get "reactToContact";
    //     [_entity, _nearEnemies] call _reactToContact;
    // };
};

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _entityPos = _entity get "position";
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerPos _entityPos;
};