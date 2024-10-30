params [
    "_entity",
    "_target"
];

// states

private _initState = [{}] call IVCS_EntityTasks_createTaskState;

private _engage = [{
    private _entityID = _this get "entityID";
    private _targetID = _this get "targetID";

    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    private _target = [_targetID] call IVCS_VirtualSpace_getEntity;
}] call IVCS_EntityTasks_createTaskState;

private _victory = [{}, true] call IVCS_EntityTasks_createTaskState;
private _defeat = [{}, true] call IVCS_EntityTasks_createTaskState;

// conditions

private _canEngageEnemy = [{
    private _entityID = _this get "entityID";
    private _targetID = _this get "targetID";

    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    private _target = [_targetID] call IVCS_VirtualSpace_getEntity;

    [_entity, _target] call IVCS_VirtualSpace_Group_canEngageEntity
}, {}, _engage] call IVCS_EntityTasks_createTaskStateCondition;

private _senseDefeat = [{
    private _entityID = _this get "entityID";
    private _targetID = _this get "targetID";

    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    private _target = [_targetID] call IVCS_VirtualSpace_getEntity;

    false
}, {}, _defeat] call IVCS_EntityTasks_createTaskStateCondition;

private _enemyDefeated = [{
    private _targetID = _this get "targetID";
    private _target = [_targetID] call IVCS_VirtualSpace_getEntity;

    true
}, {}, _victory] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

[_initState, [_canEngageEnemy]] call IVCS_EntityTasks_addOutgoingConditions;
[_engage, [_enemyDefeated, _senseDefeat]] call IVCS_EntityTasks_addOutgoingConditions;

[
    "TransportLoad",
    _initState,
    [
        ["entityID", _entity get "id"],
        ["targetID", _target get "id"]
    ]
] call IVCS_EntityTasks_createTask;