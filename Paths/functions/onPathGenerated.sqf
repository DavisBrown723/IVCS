params ["_agent","_path"];

if (!isnull _agent) then {
    _agent setpos [0,0,0];
    dostop _agent;
};

private _currentRequest = IVCS_Paths_Generator get "currentRequest";
_currentRequest params ["_requestID","_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

if (_requestID != "DELETED") then {
    _path = _path apply { [_x select 0, _x select 1, 0]};

    if (_path isequalto []) then {
        hint format ["empty path %1", diag_ticktime];
    };

    (_callbackArgs + [_path]) call _callback;
};

IVCS_Paths_Generator set ["currentRequest", []];