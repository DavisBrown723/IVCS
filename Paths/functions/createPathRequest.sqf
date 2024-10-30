params ["_pathType","_behavior","_startPos","_endPos","_callbackArgs","_callback"];

private _strategies = IVCS_Paths_Generator get "props";
if (_pathType in _strategies) then {
	private _requestID = call IVCS_Paths_getNextRequestID;
	private _timeStarted = -1;
	private _request = [_requestID, _pathType, _behavior, _startPos, _endPos, _callbackArgs, _callback, _timeStarted];

	private _requestQueue = IVCS_Paths_Generator get "requestQueue";
	_requestQueue pushback _request;

	_requestID
};