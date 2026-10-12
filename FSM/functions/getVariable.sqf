params ["_fsm","_name","_default"];

private _data = _fsm get "variables";
_data getOrDefault [_name, _default];