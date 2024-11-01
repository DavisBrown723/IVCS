params [
    "_entity",
    "_vehicleToBoard",
    ["_rendezvousPoint", [-1,-1,-1]]
];

// states

private _initState = [{}] call IVCS_EntityTasks_createTaskState;
private _emptyState = [{}] call IVCS_EntityTasks_createTaskState;

private _moveToVehicle = [{
    private _entityID = _this get "entityID";
    private _vehicleID = _this get "vehicleID";

    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;

    private _vehiclePosition = _vehicleEntity get "position";

    private _moveWp = [_vehiclePosition] call IVCS_VirtualSpace_createEntityWaypoint;
    [_entity, _moveWp] call IVCS_VirtualSpace_entityAddWaypoint;
}] call IVCS_EntityTasks_createTaskState;

private _getInVehicle = [{
    private _entityID = _this get "entityID";
    private _vehicleID = _this get "vehicleID";

    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;

    [_entity,_vehicleEntity] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
}, true] call IVCS_EntityTasks_createTaskState;

private _moveToRendezvousPoint = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    private _entityPosition = _entity get "position";
    private _rendezvousPoint = _this get "rendezvousPoint";

    private _waypointOffsetDir = _rendezvousPoint getdir _entityPosition;
    private _waypointPos = _rendezvousPoint getpos [30, _waypointOffsetDir];

    private _moveWp = [_waypointPos] call IVCS_VirtualSpace_createEntityWaypoint;
    [_entity, _moveWp] call IVCS_VirtualSpace_entityAddWaypoint;

    _this set ["moveToRendezvousWaypoint", _moveWp get "name"];
}] call IVCS_EntityTasks_createTaskState;

private _waitForVehicle = [{}] call IVCS_EntityTasks_createTaskState;

private _signalVehicle = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    private _active = _entity get "active";

    if (_active) then {
        private _rendezvousPoint = _this get "rendezvousPoint";
        private _randomNearSpots = [_rendezvousPoint, 15, 1] call IVCS_Common_generateRandomPositionsInRadius;
        "G_40mm_SmokeGreen" createvehicle (_randomNearSpots select 0);
    };
}] call IVCS_EntityTasks_createTaskState;

// conditions

private _hasRendezvousCondition = [{
    private _rendezvousPoint = _this get "rendezvousPoint";
    !(isnil "_rendezvousPoint")
}, {}, _moveToRendezvousPoint] call IVCS_EntityTasks_createTaskStateCondition;

private _noRendezvousCondition = [{
    private _rendezvousPoint = _this get "rendezvousPoint";
    isnil "_rendezvousPoint"
}, {}, _emptyState] call IVCS_EntityTasks_createTaskStateCondition;

private _noRendVehicleInRange = [{
    private _entityID = _this get "entityID";
    private _vehicleID = _this get "vehicleID";
    private _fnc_vehicleInRange = _this get "fnc_vehicleInRange";

    [_entityID, _vehicleID] call _fnc_vehicleInRange
}, {}, _getInVehicle] call IVCS_EntityTasks_createTaskStateCondition;

private _noRendVehicleNotInRange = [{
    private _entityID = _this get "entityID";
    private _vehicleID = _this get "vehicleID";
    private _fnc_vehicleInRange = _this get "fnc_vehicleInRange";

    !([_entityID, _vehicleID] call _fnc_vehicleInRange)
}, {}, _moveToVehicle] call IVCS_EntityTasks_createTaskStateCondition;

private _atRendezvousPoint = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    private _moveToRendezvousWp = _this get "moveToRendezvousWaypoint";
    private _entityWp = [_entity,_moveToRendezvousWp] call IVCS_VirtualSpace_getEntityWaypoint;

    isnil "_entityWp"
}, {}, _waitForVehicle] call IVCS_EntityTasks_createTaskStateCondition;

private _vehicleIsNear = [{
    private _vehicleID = _this get "vehicleID";
    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;

    private _vehiclePosition = _vehicleEntity get "position";
    private _rendezvousPoint = _this get "rendezvousPoint";

    _vehiclePosition distance _rendezvousPoint < 200
}, {}, _signalVehicle] call IVCS_EntityTasks_createTaskStateCondition;

private _vehicleAtRendezvous = [{
    private _vehicleID = _this get "vehicleID";
    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;

    private _vehiclePosition = _vehicleEntity get "position";
    private _rendezvousPoint = _this get "rendezvousPoint";

    (_vehiclePosition select 2) < 2 && {_vehiclePosition distance _rendezvousPoint < 30}
}, {}, _emptyState] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

[_initState, [_hasRendezvousCondition, _noRendezvousCondition]] call IVCS_EntityTasks_addTransitions;
[_emptyState, [_noRendVehicleInRange, _noRendVehicleNotInRange]] call IVCS_EntityTasks_addTransitions;
[_moveToVehicle, [_noRendVehicleInRange]] call IVCS_EntityTasks_addTransitions;

[_moveToRendezvousPoint, [_atRendezvousPoint]] call IVCS_EntityTasks_addTransitions;
[_waitForVehicle, [_vehicleIsNear]] call IVCS_EntityTasks_addTransitions;
[_signalVehicle, [_vehicleAtRendezvous]] call IVCS_EntityTasks_addTransitions;


private _vehicleInRange = {
    params ["_groupEntityID","_vehicleEntityID"];

    private _groupEntity = [_groupEntityID] call IVCS_VirtualSpace_getEntity;
    private _vehicleEntity = [_vehicleEntityID] call IVCS_VirtualSpace_getEntity;

    private _groupPosition = _groupEntity get "position";
    private _vehiclePosition = _vehicleEntity get "position";
    
    private _active = _groupEntity get "active";
    if (_active) then {
        (_groupPosition distance _vehiclePosition) < 20
    } else {
        (_groupPosition distance _vehiclePosition) < 5
    };
};

[
    "GetIn",
    _initState,
    [
        ["entityID", _entity get "id"],
        ["vehicleID", _vehicleToBoard get "id"],
        ["rendezvousPoint", if (_rendezvousPoint isequalto [-1,-1,-1]) then {nil} else {_rendezvousPoint}],
        ["moveToRendezvousWaypoint", ""],
        ["fnc_vehicleInRange", _vehicleInRange]
    ]
] call IVCS_EntityTasks_createTask;