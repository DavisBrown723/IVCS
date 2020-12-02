params ["_tacom","_order"];

private _opcom = _tacom getvariable "opcom";
private _message = ["TACOM","orderComplete", _order] call IVCS_OPCOM_createMessage;
[_opcom,_message] call IVCS_OPCOM_addMessage;

private _orders = _tacom getvariable "orders";
private _orderID = _order getvariable "id";
_orders setvariable [_orderID, nil];