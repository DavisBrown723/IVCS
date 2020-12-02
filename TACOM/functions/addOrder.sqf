params ["_tacom","_order"];

private _orderID = _order getvariable "id";

private _orders = _tacom getvariable "orders";
_orders setvariable [_orderID, _order];

private _orderType = _order getvariable "type";
private _fsm = switch (_orderType) do {
    case "garrison": {
        [_tacom,_order] call IVCS_TACOM_createGarrisonFSM;
    };
};

_order setvariable ["fsm", _fsm];
_order setvariable ["complete", false];
_order setvariable ["success", true];
_order setvariable ["feedback", ""];