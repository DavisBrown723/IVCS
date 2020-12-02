params ["_opcom"];

private _fsm = _opcom getvariable "fsm";
[_fsm] call IVCS_FSM_execute;

private _tacom = _opcom getvariable "tacom";
[_tacom] call IVCS_TACOM_update;