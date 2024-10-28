private _requestQueue = IVCS_Paths_Generator get "requestQueue";
private _currentRequest = IVCS_Paths_Generator get "currentRequest";
private _pathGenerationInProgress = !(_currentRequest isequalto []);

if (!_pathGenerationInProgress && {!(_requestQueue isequalto [])}) then {
    private _request = _requestQueue deleteat 0;
    private _props = IVCS_Paths_Generator get "props";

    _request params ["_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

    if (_pathType != "helicopter" || _pathType != "plane") then {
        private _manProp = _props get "man";

        private "_vehicleProp";
        if (_pathType != "man") then {
            _vehicleProp = _props get _pathType;
            _vehicleProp setpos _startPos;
            _manProp moveInDriver _vehicleProp;
        } else {
            _manProp setpos _startPos;
        };

        _manProp setDestination [_endPos, "LEADER PLANNED", true];

        if (!isnil "_vehicleProp") then {
            _vehicleProp engineOn false;
        };
    } else {
        [objNull, [_endPos]] call IVCS_Paths_onPathGenerated;
    };

    _request set [6, diag_tickTime];
    IVCS_Paths_Generator set ["currentRequest", _request];
} else {
    if (_pathGenerationInProgress) then {
        private _timeStarted = _currentRequest select 6;
        if (diag_tickTime - _timeStarted > 10) then {
            [objNull, []] call IVCS_Paths_onPathGenerated;
        };
    };
};