private _requestQueue = IVCS_Paths_Generator getvariable "requestQueue";
private _currentRequest = IVCS_Paths_Generator getvariable "currentRequest";

if (_currentRequest isequalto [] && {!(_requestQueue isequalto [])}) then {
    private _request = _requestQueue deleteat 0;
    private _props = IVCS_Paths_Generator getvariable "props";

    _request params ["_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

    if (_pathType != "helicopter" || _pathType != "plane") then {
        private _manProp = _props getvariable "man";

        private "_vehicleProp";
        if (_pathType != "man") then {
            _vehicleProp = _props getvariable _pathType;
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

    };

    IVCS_Paths_Generator setvariable ["currentRequest", _request];
};