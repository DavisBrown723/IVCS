params ["_tacom"];

private _fsm = _tacom getvariable "fsm";
[_fsm] call IVCS_FSM_execute;