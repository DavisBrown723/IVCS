params ["_entity", "_deltaTime"];

[_entity] call IVCS_EntityTasks_processTask;

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

            private _movePoints = _entity getvariable "movePoints";
            if (_movePoints isequalto []) then {
                // this is the first time we're simulating this waypoint
                // calculate path from entity position to waypoint destination

                //params ["_pathType","_behavior","_startPos","_endPos","_callback"];
                private _strategy = _entity getvariable "pathfindingStrategy";
                private _waypointPos = _waypoint getvariable "position";
                private _entityID = _entity getvariable "id";

                [_strategy, "SAFE", _entityPos, _waypointPos, [_entityID], {
                    params ["_entityID","_path"];

                    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
                    private _movePoints = _entity getvariable "movePoints";
                    if (_movePoints isequalto []) then {
                        {
                            private _marker = createmarker [str random 100000, _x];
                            _marker setmarkertype "mil_dot";
                            _marker setMarkerSize [0.5, 0.5];
                        } foreach _path;

                        _entity setvariable ["movePoints", _path];
                    };
                }] call IVCS_Paths_generatePath;
            } else {
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
                    case "MOVE": {
                        private _distRemaining = _entityPos distance _nextMovePoint;
                        private _moveDir = _entityPos getdir _nextMovePoint;
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

                private _distToMovepoint = _entityPos distance _nextMovePoint;
                if (_distToMovepoint < 5) then {
                    _movePoints deleteat 0;
                };

                private _waypointPos = _waypoint getvariable "position";
                private _distRemaining = _entityPos distance _waypointPos;
                private _waypointCompletionRadius = _waypoint getvariable "completionRadius";
                if (_movePoints isequalto [] || { _distRemaining <= (_waypointCompletionRadius min 7) }) then {
                    [_entity getvariable "id", _waypoint getvariable "name"] call IVCS_VirtualSpace_onWaypointCompleted;
                };
            };
        };
    };

    private _entitySide = _entity getvariable "side";
    private _sidesEnemy = ([_entitySide] call IVCS_Common_getSideAllegiances) select 1;
    private _nearEntities = [_entityPos, 500, ["group"]] call IVCS_VirtualSpace_getNearEntities;
};

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _entityPos = _entity getvariable "position";
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerPos _entityPos;
};