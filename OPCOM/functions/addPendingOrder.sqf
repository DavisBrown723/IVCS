params ["_opcom","_order"];

private _id = [_opcom] call IVCS_OPCOM_getNextOrderID;

_order setvariable ["id", _id];

private _pendingOrders = _opcom getvariable "pendingOrders";
_pendingOrders pushback _order;

private _orderObjectiveID = _order getvariable "objectiveID";
if (!isnil "_orderObjectiveID") then {
    private _objective = [_opcom,_orderObjectiveID] call IVCS_OPCOM_getObjective;
    private _objectiveOrders = _objective getvariable "orders";
    _objectiveOrders pushback _order;
};

_id