params ["_tacom","_order"];

private _orderComplete = _order getvariable "complete";
if (!_orderComplete) then {
    private _orderFSM = _order getvariable "fsm";
    [_orderFSM] call IVCS_FSM_execute;
} else {
    [_tacom, _order] call IVCS_TACOM_handleCompletedOrder;
};