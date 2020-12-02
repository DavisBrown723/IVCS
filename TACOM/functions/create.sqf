params ["_opcom"];

private _tacom = [] call CBA_fnc_createNamespace;
_tacom setvariable ["opcom", _opcom];
_tacom setvariable ["messageQueue", []];
_tacom setvariable ["orders", [] call CBA_fnc_createNamespace];

private _tacomFSM = [_tacom] call IVCS_TACOM_createFSM;
_tacom setvariable ["fsm", _tacomFSM];

_tacom