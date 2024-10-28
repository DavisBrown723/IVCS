params ["_fsm","_name","_default"];

private _data = _fsm get "data";
_data getOrDefault [_name, _default];