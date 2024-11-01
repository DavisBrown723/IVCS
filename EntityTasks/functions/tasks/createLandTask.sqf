params [
    "_entity",
    "_landingPosition",
    ["_landingType", "LAND"]
];

// states

private _initState = [] call IVCS_EntityTasks_createTaskState;

private _moveToLandingPoint = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    private _landingPosition = _this get "landingPosition";

    private _landWp = [_landingPosition,"LAND"] call IVCS_VirtualSpace_createEntityWaypoint;
    [_entity, _landWp] call IVCS_VirtualSpace_entityAddWaypoint;
}] call IVCS_EntityTasks_createTaskState;

private _createHelipad = [{
    private _landingPosition = _this get "landingPosition";

    private _helipad = "Land_HelipadEmpty_F" createVehicle _landingPosition;

    _this set ["helipadObject", _helipad];
}] call IVCS_EntityTasks_createTaskState;

private _endState = [{
    private _helipad = _this get "helipadObject";
    if !(isnull _helipad) then {
        // deleteVehicle _helipad;
        // deleting this seems to make the helicopter move away to a new landing point
        // garbage clean this somehow
    };
}, true] call IVCS_EntityTasks_createTaskState;


// conditions

private _atLandingPoint = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    private _landingPosition = _this get "landingPosition";

    private _fnc_inLandRangeOfPosition = _this get "fnc_inLandRangeOfPosition";
    [_entity, _landingPosition] call _fnc_inLandRangeOfPosition
}, {}, _endState] call IVCS_EntityTasks_createTaskStateCondition;

private _notAtLandingPoint = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    private _landingPosition = _this get "landingPosition";

    private _fnc_inLandRangeOfPosition = _this get "fnc_inLandRangeOfPosition";

    !([_entity, _landingPosition] call _fnc_inLandRangeOfPosition)
}, {}, _moveToLandingPoint] call IVCS_EntityTasks_createTaskStateCondition;

private _nearLandingPoint = [{
    private _entityID = _this get "entityID";
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;

    private _entityPosition = _entity get "position";
    private _landingPosition = _this get "landingPosition";

    _entityPosition distance _landingPosition < 200
}, {}, _createHelipad] call IVCS_EntityTasks_createTaskStateCondition;

// build fsm

[_initState, [_atLandingPoint, _notAtLandingPoint]] call IVCS_EntityTasks_addTransitions;
[_moveToLandingPoint, [_nearLandingPoint]] call IVCS_EntityTasks_addTransitions;
[_createHelipad, [_atLandingPoint]] call IVCS_EntityTasks_addTransitions;

private _inLandRangeOfPosition = {
    params ["_entity","_landingPosition"];

    private _entityPosition = _entity get "position";

    (_entityPosition distance _landingPosition) < 25 && { (_entityPosition select 2) < 4 };
};

[
    "Land",
    _initState,
    [
        ["entityID", _entity get "id"],
        ["landingPosition", _landingPosition],
        ["landingType", _landingType],
        ["helipadObject", objNull],
        ["fnc_inLandRangeOfPosition", _inLandRangeOfPosition]
    ]
] call IVCS_EntityTasks_createTask;