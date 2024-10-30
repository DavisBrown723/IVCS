params ["_requestID"];

private _currentRequest = IVCS_Paths_Generator get "currentRequest";
if (_currentRequest isnotequalto [] && { (_currentRequest select 0) == _requestID }) then {
	_currentRequest set [0, "DELETED"];
} else {
	private _requestQueue = IVCS_Paths_Generator get "requestQueue";
	_requestQueue deleteat (_requestQueue findIf { (_x select 0) == _requestID});
};