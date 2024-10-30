private _requestQueue = IVCS_Paths_Generator get "requestQueue";
private _currentRequest = IVCS_Paths_Generator get "currentRequest";
private _pathGenerationInProgress = _currentRequest isnotequalto [];

if (!_pathGenerationInProgress) then {
    if (_requestQueue isnotequalto []) then {
        private _request = _requestQueue deleteat 0;
        _request set [7, diag_tickTime];

        IVCS_Paths_Generator set ["currentRequest", _request];

        _request params ["_requestID","_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

        if (_startPos distance _endPos < 7|| { _pathType in ["helicopter","plane"] }) exitwith {
            [objNull, [_endPos]] call IVCS_Paths_onPathGenerated;
        };

        private _props = IVCS_Paths_Generator get "props";
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
    };
} else {
    private _timeStarted = _currentRequest select 7;
    if (diag_tickTime - _timeStarted > 10) then {
        [objNull, []] call IVCS_Paths_onPathGenerated;
    };
};