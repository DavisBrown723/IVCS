params ["_opcom","_order"];

private _orderID = _order getvariable "id";
private _pendingOrders = _opcom getvariable "pendingOrders";
private _pendingOrderIndex = _pendingOrders findif { (_x getvariable "id") == _orderID };

_pendingOrders deleteat _pendingOrderIndex