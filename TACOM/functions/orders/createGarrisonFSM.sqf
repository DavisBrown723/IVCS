params ["_tacom","_order"];

// states

private _states = [
    ["Init",{
        private _opcom = _this getvariable "opcom";
        private _order = _this getvariable "order";
        private _objectiveID = _order getvariable "objectiveID";
        private _objective = [_opcom,_objectiveID] call IVCS_OPCOM_getObjective;
        private _moveTasks = [];

        if (!isnil "_objective") then {
            private _objectivePosition = _objective getvariable "position";
            private _objectiveSize = _objective getvariable "size";
            private _entities = _order getvariable "assignedEntities";

            {
                private _entity = [_x] call IVCS_VirtualSpace_getEntity;
                if (!isnil "_entity") then {
                    private _entityPosition = _entity getvariable "position";

                    if (_entityPosition distance _objectivePosition > _objectiveSize) then {
                        private _movePos = [_objectivePosition, _objectiveSize * 0.5, 1] call IVCS_Common_generateRandomPositionsInRadius;
                        private _moveTask = [_entity, _movePos select 0] call IVCS_EntityTasks_createMoveTask;
                        private _taskID = [_entity, _moveTask] call IVCS_VirtualSpace_entityAddTask;

                        _moveTasks pushback [_x, _taskID];
                    };
                };
            } foreach _entities;
        };

        _this setvariable ["MoveTasks", _moveTasks];
    }, ["HaveDeadEntities"]] call IVCS_FSM_createState,

    ["End",{
        private _taskSuccessful = _this getvariable "allAlive";
        private _order = _this getvariable "order";

        _order setvariable ["success", _taskSuccessful];
        _order setvariable ["complete", true];
    }, [], true] call IVCS_FSM_createState
];


// conditions

private _conditions = [
    ["HaveDeadEntities", {
        private _order = _this getvariable "order";
        private _assignedEntities = _order getvariable "assignedEntities";
        private _allAlive = true;
        {
            private _entity = [_x] call IVCS_VirtualSpace_getEntity;
            if (isnil "_entity") exitwith {
                _allAlive = false;
            };
        } foreach _assignedEntities;

        !_allAlive
    }, { _this setvariable ["allAlive", false] }, "End"] call IVCS_FSM_createCondition

    // ["AllEntitiesArrived", {
    //     private _moveTasks = _this getvariable "MoveTasks";
    //     private _completedTasks = _moveTasks select {
    //         _x params ["_entityID","_taskID"];

    //         private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    //         private _task = [_entity, _taskID] call IVCS_VirtualSpace_getEntityTask;

    //         isnil "_task"
    //     };

    //     _moveTasks = _moveTasks - _completedTasks;
    //     _this setvariable ["MoveTasks", _moveTasks];

    //     _moveTasks isequalto []
    // }, {}, "End"] call IVCS_FSM_createCondition
];

// build fsm

[
    "Garrison",
    "Init",
    [
        ["opcom", _tacom getvariable "opcom"],
        ["tacom", _tacom],
        ["order", _order],
        ["allAlive", true]
    ],
    _states + _conditions
] call IVCS_FSM_create;