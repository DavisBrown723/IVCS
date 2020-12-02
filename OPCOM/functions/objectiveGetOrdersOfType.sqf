params ["_opcom","_objective","_orderType"];

private _objectiveOrders = _objective getvariable "orders";
private _ordersOfType = _objectiveOrders select {
    private _type = _x getvariable "type";

    _type == _orderType
};

_ordersOfType