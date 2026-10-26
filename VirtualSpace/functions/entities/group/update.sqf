params ["_entity", "_deltaTime"];
// Scheduled creation/capture can span frames; don't simulate incomplete state.
if (_entity get "simulationTransition") exitWith {};

[_entity] call IVCS_Combat_findTarget;
if (_entity get "active" || { (_entity get "combatID") == "" }) then { [_entity] call IVCS_Ammo_updateGroup; };
private _defendingFromAir=(_entity get "airDefense") isNotEqualTo [];
[_entity,_deltaTime] call IVCS_Combat_updateAirDefense;
private _inCombat = (_entity get "combatID") != "";
private _helicopter = nil;
{private _v=[_x] call IVCS_VirtualSpace_getEntity; if ((_v get "vehicleType")=="helicopter") exitWith {_helicopter=_v}} forEach (_entity get "vehiclesInCommandOf");
private _airCrew = !isNil "_helicopter";
private _airOverride = _airCrew && {[_entity,_helicopter,_deltaTime] call IVCS_Combat_updateHelicopter};
[_entity] call IVCS_EntityTasks_syncActiveTask;
private _currentTask = [_entity] call IVCS_VirtualSpace_getCurrentEntityTask;
if ((!_inCombat || {_airCrew}) && {!_airOverride} && {!_defendingFromAir} && { !isnil "_currentTask" }) then {
    [_entity, _currentTask] call IVCS_EntityTasks_processTask;
};

private _active = _entity get "active";
if (_active) then {
    private _group = _entity get "group";

    private _newEntityPos = getpos (leader _group);
    [_entity, _newEntityPos] call IVCS_VirtualSpace_setEntityPosition;
} else {
    // Carried groups move with their transport, not their own virtual waypoints.
    if ((!_inCombat || {_airCrew}) && {!_airOverride} && {!_defendingFromAir} && { (_entity get "vehiclesInCargoOf") isEqualTo [] }) then {
        // simulate waypoints

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

                    private _requestID = [_strategy, "SAFE", _entityPos, _waypointPos, [_entityID,_waypointID, _currentWaypoint get "pathGeneration"], IVCS_VirtualSpace_Group_onWaypointPathGenerated] call IVCS_Paths_createPathRequest;
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
                            case "FULL";
                            case "FAST":    { _entityMoveSpeed = _entityMoveSpeed * 1.3 };
                        };

                        // perform movement

                        private _entityPos = _entity get "position";
                        private _waypointType = _currentWaypoint get "type";
                        private _nextMovePoint = _movePoints select 0;

                        switch (_waypointType) do {
                            case "LAND";
                            case "MOVE": {
                                private _distRemaining = _entityPos distance2D _nextMovePoint;
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

                        _entityPos = _entity get "position";
                        private _distToMovepoint = _entityPos distance2D _nextMovePoint;
                        if (_distToMovepoint < 5) then {
                            _movePoints deleteat 0;
                        };

                        private _waypointPos = _currentWaypoint get "position";
                        private _distRemaining = _entityPos distance2D _waypointPos;
                        private _waypointCompletionRadius = _currentWaypoint get "completionRadius";
                        if (_movePoints isequalto [] || { _distRemaining <= (_waypointCompletionRadius max 7) }) then {
                            [_entity get "id", _currentWaypoint get "name"] call IVCS_VirtualSpace_onWaypointCompleted;
                        };
                    };
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
