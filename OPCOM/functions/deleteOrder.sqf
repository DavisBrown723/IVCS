params ["_opcom","_order"];

private _assignedEntities = _order getvariable "assignedEntities";
[_opcom, _assignedEntities, false, ""] call IVCS_OPCOM_changeEntitiesUsageState;

private _orderObjectiveID = _order getvariable "objectiveID";
if (!isnil "_orderObjectiveID") then {
    private _objective = [_opcom,_orderObjectiveID] call IVCS_OPCOM_getObjective;
    private _objectiveOrders = _objective getvariable "orders";
    _objectiveOrders deleteat (_objectiveOrders find _order);
};

private _orderID = _order getvariable "id";
private _orders = _opcom getvariable "orders";
_orders setvariable [_orderID, nil];

_order call CBA_fnc_deleteNamespace;