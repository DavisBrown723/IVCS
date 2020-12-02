params ["_fsm","_name","_default"];

private _data = _fsm getvariable "data";
_data getvariable [_name, _default];