params ["_opcom","_pendingOrder"];

// add to orders

private _orders = _opcom getvariable "orders";
private _pendingOrderID = _pendingOrder getvariable "id";
_orders setvariable [_pendingOrderID, _pendingOrder];

// mark entities as busy

private _assignedEntities = _pendingOrder getvariable "assignedEntities";
[_opcom, _assignedEntities, true, _pendingOrderID] call IVCS_OPCOM_changeEntitiesUsageState;

// send message to opcom

private _tacom = _opcom getvariable "tacom";

private _message = ["OPCOM","newOrder", _pendingOrder] call IVCS_OPCOM_createMessage;
[_tacom,_message] call IVCS_TACOM_addMessage;

systemchat format ["Starting Garrison - %1", diag_tickTime];