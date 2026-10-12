params ["_fsm","_name","_value"];

private _data = _fsm get "variables";
_data set [_name, _value];