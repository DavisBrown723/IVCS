params ["_agent","_path"];

_agent setpos [0,0,0];

private _currentRequest = IVCS_Paths_Generator getvariable "currentRequest";
_currentRequest params ["_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

dostop _agent;

_path = _path apply { [_x select 0, _x select 1, 0]};

(_callbackArgs + [_path]) call _callback;

IVCS_Paths_Generator setvariable ["currentRequest", []];