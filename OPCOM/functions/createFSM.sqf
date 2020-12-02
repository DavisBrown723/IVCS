params ["_opcom"];

// states

private _states = [
    ["Init",{
        _this setvariable ["timeLastEntitySort", diag_tickTime - 25];
        _this setvariable ["objectivesToPrepareForSort", []];
        _this setvariable ["objectivesToSort", []];

        _this setvariable ["timeLastObjectiveSort", diag_tickTime - 25];
        _this setvariable ["entitiesToSort", []];

        _this setvariable ["timeLastObjectiveScan", diag_tickTime - 10];
        _this setvariable ["objectivesToScan", []];
        _this setvariable ["objectiveScanResults", []];
    }, ["Initialized"]] call IVCS_FSM_createState,

    ["DecisionCore", {}, ["MessageToProcess","PendingOrdersToProcess","NeedEntitySort","NeedObjectiveSort","NeedObjectiveScan","ObjectiveScanResultsToProcess"]] call IVCS_FSM_createState,

    ["ProcessMessage", {
        private _opcom = _this getvariable "opcom";
        private _messageQueue = _opcom getvariable "messageQueue";

        private _message = _messageQueue deleteat 0;
        [_opcom,_message] call IVCS_OPCOM_processMessage;
    }, ["MessageProcessed"]] call IVCS_FSM_createState,

    ["ProcessPendingOrder", {
        private _opcom = _this getvariable "opcom";
        private _pendingOrders = _opcom getvariable "pendingOrders";

        private _pendingOrder = _pendingOrders deleteat 0;
        [_opcom,_pendingOrder] call IVCS_OPCOM_processPendingOrder;
    }, ["PendingOrderProcessed"]] call IVCS_FSM_createState,

    ["SortEntityBatch", {
        private _opcom = _this getvariable "opcom";
        private _entityInfoMap = _opcom getvariable "entityInfoMap";
        private _idleEntities = _opcom getvariable "idleEntities";
        private _activeEntities = _opcom getvariable "activeEntities";

        private _entitiesToSort = _this getvariable "entitiesToSort";
        private _entityBatch = _entitiesToSort select [0, 20];
        _entitiesToSort deleteRange [0, 20];

        {
            private _entity = [_x] call IVCS_VirtualSpace_getEntity;
            private _entityInfo = _entityInfoMap getvariable _x;
            private _previousVehicleType = _entityInfo select 1;

            private _vehicleType = _entity getvariable "vehicleType";
            if (_previousVehicleType != _vehicleType) then {
                _entityInfo set [1, _vehicleType];

                if ((_entityInfo select 0)) then {
                    private _idlePreviousTypeEntities = _idleEntities getvariable _previousVehicleType;
                    _idlePreviousTypeEntities deleteat (_idlePreviousTypeEntities find _x);

                    private _idleTypeEntities = _idleEntities getvariable _vehicleType;
                    _idleTypeEntities pushback _x;
                } else {
                    private _activePreviousTypeEntities = _activeEntities getvariable _previousVehicleType;
                    _activePreviousTypeEntities deleteat (_activePreviousTypeEntities find _x);

                    private _activeTypeEntities = _activeEntities getvariable _vehicleType;
                    _activeTypeEntities pushback _x;
                };
            };
        } foreach _entityBatch;
    }, ["AllEntitiesSorted"], false, true] call IVCS_FSM_createState,

    ["PrepareObjectiveBatch", {
        private _opcom = _this getvariable "opcom";
        private _objectives = _opcom getvariable "objectives";
        private _opcomPosition = _opcom getvariable "position";

        private _objectivesToPrepareForSort = _this getvariable "objectivesToPrepareForSort";
        private _objectiveBatch = _objectivesToPrepareForSort select [0,20];
        _objectivesToPrepareForSort deleteRange [0,20];

        private _objectivesToSort = _this getvariable "objectivesToSort";
        {
            private _objective = _objectives getvariable _x;
            private _objectivePosition = _objective getvariable "position";
            private _distToOPCOM = _objectivePosition distance _opcomPosition;

            _objectivesToSort pushback [_distToOPCOM, _x];
        } foreach _objectiveBatch;
    }, ["AllObjectiveBatchesReady"], false, true] call IVCS_FSM_createState,

    ["SortObjectives", {
        private _opcom = _this getvariable "opcom";
        private _objectives = _opcom getvariable "objectives";
        private _sortedObjectives = _opcom getvariable "sortedObjectives";
        _sortedObjectives resize 0;

        private _objectivesToSort = _this getvariable "objectivesToSort";
        _objectivesToSort sort true;
        {
            private _objective = _objectives getvariable (_x select 1);
            if (!isnil "_objective") then {
                _objective setvariable ["priority", _foreachindex];

                private _objectiveID = _objective getvariable "id";
                _sortedObjectives pushback _objectiveID;
            };
        } foreach _objectivesToSort;
    }, ["ObjectiveSortComplete"]] call IVCS_FSM_createState,

    ["FindObjectivesToScan", {
        private _opcom = _this getvariable "opcom";
        private _objectives = _opcom getvariable "objectives";
        private _sortedObjectives = _opcom getvariable "sortedObjectives";
        private _objectivesToScan = _this getvariable "objectivesToScan";
        private _currTickTime = diag_tickTime;

        {
            private _objective = _objectives getvariable _x;
            private _timeLastScan = _objective getvariable "timeLastScanned";

            if (_currTickTime - _timeLastScan > 30) then {
                _objectivesToScan pushback _objective;
            };
        } foreach _sortedObjectives;
    }, ["NoObjectivesToScan","ObjectivesToScan"]] call IVCS_FSM_createState,

    ["ScanObjective", {
        private _objectivesToScan = _this getvariable "objectivesToScan";
        private _objectiveScanResults = _this getvariable "objectiveScanResults";

        private _opcom = _this getvariable "opcom";
        private _objective = _objectivesToScan deleteat 0;

        private _scanResult = [_opcom, _objective] call IVCS_OPCOM_scanObjective;
        _objectiveScanResults pushback _scanResult;
    }, ["NoObjectivesToScan"], false, true] call IVCS_FSM_createState,

    ["ProcessObjectiveScanResult", {
        private _objectiveScanResults = _this getvariable "objectiveScanResults";

        private _opcom = _this getvariable "opcom";
        private _scanToProcess = _objectiveScanResults deleteat 0;

        [_opcom, _scanToProcess] call IVCS_OPCOM_processObjectiveScanResult;
    }, ["ObjectiveProcessActionToTake","NoObjectiveScanResultsToProcess"], false, true] call IVCS_FSM_createState,

    ["ProcessObjectiveTakeAction", {
        private _scanProcessAction = _this getvariable "ProcessedScanAction";
    }, ["ObjectivesToScan","NoObjectiveScanResultsToProcess"]] call IVCS_FSM_createState
];


// conditions

private _conditions = [
    ["Initialized", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["MessageToProcess", {
        private _opcom = _this getvariable "opcom";
        !((_opcom getvariable "messageQueue") isequalto [])
    }, {}, "ProcessMessage"] call IVCS_FSM_createCondition,
    ["MessageProcessed", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["PendingOrdersToProcess", { !((_this getvariable "pendingOrders") isequalto []) }, {}, "ProcessPendingOrder"] call IVCS_FSM_createCondition,
    ["PendingOrderProcessed", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["PendingOrdersToProcess", {
        private _opcom = _this getvariable "opcom";
        private _pendingOrders = _opcom getvariable "pendingOrders";
        !(_pendingOrders isequalto [])
    }, {}, "ProcessPendingOrder"] call IVCS_FSM_createCondition,
    ["PendingOrderProcessed", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["NeedEntitySort", {
        private _opcom = _this getvariable "opcom";
        private _entitiesToSort = _opcom getvariable "allEntities";
        private _timeLastSort = _this getvariable "timeLastEntitySort";

        diag_tickTime - _timeLastSort > 30 && { !(_entitiesToSort isequalto []) }
    }, {
        private _opcom = _this getvariable "opcom";
        private _entitiesToSort = _opcom getvariable "allEntities";
        _this setvariable ["entitiesToSort", _entitiesToSort];
    }, "SortEntityBatch"] call IVCS_FSM_createCondition,

    ["AllEntitiesSorted", { (_this getvariable "entitiesToSort") isequalto [] }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["NeedObjectiveSort", {
        private _opcom = _this getvariable "opcom";
        private _timeLastSort = _this getvariable "timeLastObjectiveSort";

        diag_tickTime - _timeLastSort > 30
    }, {
        private _opcom = _this getvariable "opcom";
        private _objectives = _opcom getvariable "objectives";
        _this setvariable ["objectivesToPrepareForSort", allvariables _objectives];
    }, "PrepareObjectiveBatch"] call IVCS_FSM_createCondition,

    ["AllObjectiveBatchesReady", { (_this getvariable "objectivesToPrepareForSort") isequalto [] }, {}, "SortObjectives"] call IVCS_FSM_createCondition,
    ["ObjectiveSortComplete", { true }, { _this setvariable ["timeLastObjectiveSort", diag_tickTime] }, "DecisionCore"] call IVCS_FSM_createCondition,

    ["NeedObjectiveScan", {
        private _timeLastScan = _this getvariable "timeLastObjectiveScan";

        diag_tickTime - _timeLastScan > 20
    }, {}, "FindObjectivesToScan"] call IVCS_FSM_createCondition,

    ["NoObjectivesToScan", {
        _this setvariable ["timeLastObjectiveScan", diag_tickTime];
        (_this getvariable "objectivesToScan") isequalto []
    }, {}, "DecisionCore"] call IVCS_FSM_createCondition,
    ["ObjectivesToScan", { !((_this getvariable "objectivesToScan") isequalto []) }, {}, "ScanObjective"] call IVCS_FSM_createCondition,

    ["ObjectiveScanResultsToProcess", { !((_this getvariable "objectiveScanResults") isequalto []) }, {}, "ProcessObjectiveScanResult"] call IVCS_FSM_createCondition,
    ["NoObjectiveScanResultsToProcess", { (_this getvariable "objectiveScanResults") isequalto [] }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["ObjectiveProcessActionToTake", { ((_this getvariable "ProcessedScanAction") select 0) != "pass" }, {}, "DecisionCore"] call IVCS_FSM_createCondition
];


// build fsm

[
    "OPCOM",
    "Init",
    [
        ["opcom", _opcom]
    ],
    _states + _conditions
] call IVCS_FSM_create;