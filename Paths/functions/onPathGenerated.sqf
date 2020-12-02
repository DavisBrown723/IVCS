params ["_agent","_path"];

if (!isnull _agent) then {
    _agent setpos [0,0,0];
    dostop _agent;
};

_path = _path apply { [_x select 0, _x select 1, 0]};

private _currentRequest = IVCS_Paths_Generator getvariable "currentRequest";
_currentRequest params ["_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

(_callbackArgs + [_path]) call _callback;

IVCS_Paths_Generator setvariable ["currentRequest", []];