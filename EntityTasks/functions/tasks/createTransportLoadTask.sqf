params [
    "_entity",
    "_entityToTransport"
];

// states

private _initState = [{}] call IVCS_EntityTasks_createTaskState;

// conditions


private _vehicleIsNear = [{
    private _vehicleID = _this get "vehicleID";
    private _vehicleEntity = [_vehicleID] call IVCS_VirtualSpace_getEntity;

    private _vehiclePosition = _vehicleEntity get "position";
    private _rendezvousPoint = _this get "rendezvousPoint";

    _vehiclePosition distance _rendezvousPoint < 200
}, {}, _signalVehicle] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

// [_initState, [_hasRendezvousCondition, _noRendezvousCondition]] call IVCS_EntityTasks_addTransitions;

[
    "TransportLoad",
    _initState,
    [
        ["entityID", _entity get "id"],
        ["entityToTransportID", _entityToTransport get "id"]
    ]
] call IVCS_EntityTasks_createTask;