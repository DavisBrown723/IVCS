params [
    "_entity",
    "_destinationPos",
    ["_completionRadius", 50],
    ["_moveSpeed","UNCHANGED"]
];

// states

private _initState = [{
    private _entityID = _this getvariable "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    if (!isnil "_entity") then {
        private _destinationPos = _this getvariable "destinationPos";
        private _completionRadius = _this getvariable "completionRadius";
        private _moveSpeed = _this getvariable "moveSpeed";

        private _moveWaypoint = [_destinationPos, "MOVE", _moveSpeed] call IVCS_VirtualSpace_createEntityWaypoint;
        [_entity, _moveWaypoint] call IVCS_VirtualSpace_entityAddWaypoint;

        private _moveWaypointID = _moveWaypoint getvariable "name";
        _this setvariable ["moveWaypointID", _moveWaypointID];
    };
}] call IVCS_EntityTasks_createTaskState;


private _destinationReachedState = [{systemchat 'dest reached'}, true] call IVCS_EntityTasks_CreateTaskState;
private _entityKilledState = [{systemchat 'entity killed?'}, true] call IVCS_EntityTasks_CreateTaskState;

// conditions

private _destinationReachedCondition = [{
    private _entityID = _this getvariable "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    if (isnil "_entity") exitwith {
        false
    };

    private _moveWaypointID = _this getvariable "moveWaypointID";
    private _moveWaypoint = [_entity,_moveWaypointID] call IVCS_VirtualSpace_getEntityWaypoint;

    isnil "_moveWaypoint"
}, {}, _destinationReachedState] call IVCS_EntityTasks_createTaskStateCondition;


private _entityKilledCondition = [{
    private _entityID = _this getvariable "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    isnil "_entity"
}, {}, _entityKilledState] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

[_initState, [_destinationReachedCondition, _entityKilledCondition]] call IVCS_EntityTasks_addOutgoingConditions;


[
    "Move",
    _initState,
    [
        ["entityID", _entity getvariable "id"],
        ["destinationPos", _destinationPos],
        ["completionRadius", _completionRadius],
        ["moveSpeed", _moveSpeed]
    ]
] call IVCS_EntityTasks_createTask;