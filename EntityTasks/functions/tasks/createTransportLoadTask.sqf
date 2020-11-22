params [
    "_entity",
    "_entityToTransport"
];

// states

private _initState = [{}] call IVCS_EntityTasks_createTaskState;

// conditions


private _vehicleIsNear = [{
    private _vehicleID = _this getvariable "vehicleID";
    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;

    private _vehiclePosition = _vehicleEntity getvariable "position";
    private _rendezvousPoint = _this getvariable "rendezvousPoint";

    _vehiclePosition distance _rendezvousPoint < 200
}, {}, _signalVehicle] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

// [_initState, [_hasRendezvousCondition, _noRendezvousCondition]] call IVCS_EntityTasks_addOutgoingConditions;

[
    "TransportLoad",
    _initState,
    [
        ["entityID", _entity getvariable "id"],
        ["entityToTransportID", _entityToTransport getvariable "id"]
    ]
] call IVCS_EntityTasks_createTask;