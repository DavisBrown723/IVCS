params [
    "_entity",
    "_destinationPos",
    ["_completionRadius", 50],
    ["_moveSpeed","UNCHANGED"]
];

// states

private _initState = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    if (!isnil "_entity") then {
        private _destinationPos = _this get "destinationPos";
        private _completionRadius = _this get "completionRadius";
        private _moveSpeed = _this get "moveSpeed";

        private _moveWaypoint = [_destinationPos, "MOVE", _moveSpeed] call IVCS_VirtualSpace_createEntityWaypoint;
        [_entity, _moveWaypoint] call IVCS_VirtualSpace_entityAddWaypoint;

        private _moveWaypointID = _moveWaypoint get "name";
        _this set ["moveWaypointID", _moveWaypointID];
    };
}] call IVCS_EntityTasks_createTaskState;


private _destinationReachedState = [{}, true] call IVCS_EntityTasks_CreateTaskState;
private _entityKilledState = [{}, true] call IVCS_EntityTasks_CreateTaskState;

// conditions

private _destinationReachedCondition = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    if (isnil "_entity") exitwith {
        false
    };

    private _moveWaypointID = _this get "moveWaypointID";
    private _moveWaypoint = [_entity,_moveWaypointID] call IVCS_VirtualSpace_getEntityWaypoint;

    isnil "_moveWaypoint"
}, {}, _destinationReachedState] call IVCS_EntityTasks_createTaskStateCondition;


private _entityKilledCondition = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    isnil "_entity"
}, {}, _entityKilledState] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

[_initState, [_destinationReachedCondition, _entityKilledCondition]] call IVCS_EntityTasks_addTransitions;


[
    "Move",
    _initState,
    [
        ["entityID", _entity get "id"],
        ["destinationPos", _destinationPos],
        ["completionRadius", _completionRadius],
        ["moveSpeed", _moveSpeed]
    ]
] call IVCS_EntityTasks_createTask;