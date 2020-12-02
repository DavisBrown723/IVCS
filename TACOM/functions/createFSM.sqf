params ["_tacom"];

// states

private _states = [
    ["Init",{
        _this setvariable ["ordersToProcess", []];
    }, ["Initialized"]] call IVCS_FSM_createState,

    ["DecisionCore",{}, ["MessageRecieved","OrdersToProcess"]] call IVCS_FSM_createState,

    ["ProcessMessage",{
        private _tacom = _this getvariable "tacom";
        private _messageQueue = _tacom getvariable "messageQueue";

        private _messageToProcess = _messageQueue deleteat 0;
        [_tacom, _messageToProcess] call IVCS_TACOM_processMessage;
    }, ["MessageProcessed"]] call IVCS_FSM_createState,

    ["ProcessOrder",{
        private _tacom = _this getvariable "tacom";
        private _orders = _tacom getvariable "orders";
        private _ordersToProcess = _this getvariable "ordersToProcess";

        private _orderToProcessID = _ordersToProcess deleteat 0;
        private _orderToProcess = _orders getvariable _orderToProcessID;
        [_tacom, _orderToProcess] call IVCS_TACOM_processOrder;
    }, ["OrderProcessed"]] call IVCS_FSM_createState
];


// conditions

private _conditions = [
    ["Initialized", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition,
    ["MessageRecieved", { !((_this getvariable "messageQueue") isequalto []) }, {}, "ProcessMessage"] call IVCS_FSM_createCondition,
    ["MessageProcessed", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition,

    ["OrdersToProcess", {
        private _tacom = _this getvariable "tacom";
        private _orders = _tacom getvariable "orders";

        !((allvariables _orders) isequalto [])
    }, {
        private _ordersToProcess = _this getvariable "ordersToProcess";
        if (_ordersToProcess isequalto []) then {
            private _tacom = _this getvariable "tacom";
            private _orders = _tacom getvariable "orders";
            private _validOrders = (allvariables _orders) select { !isnil {_orders getvariable _x}};
            _this setvariable ["ordersToProcess", _validOrders];
        };
    }, "ProcessOrder"] call IVCS_FSM_createCondition,
    ["OrderProcessed", { true }, {}, "DecisionCore"] call IVCS_FSM_createCondition
];


// build fsm

[
    "TACOM",
    "Init",
    [
        ["tacom", _tacom],
        ["opcom", _tacom getvariable "opcom"],
        ["messageQueue", _tacom getvariable "messageQueue"]
    ],
    _states + _conditions
] call IVCS_FSM_create;