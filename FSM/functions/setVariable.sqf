params ["_fsm","_name","_value"];

private _data = _fsm getvariable "data";
_data setvariable [_name, _value];