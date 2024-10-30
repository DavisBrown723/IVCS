params ["_waypoint"];

_waypoint set ["initialized", false];

private _pathGenerationRequestID = _waypoint get "pathGenerationRequestID";
if (_pathGenerationRequestID != "" && { _pathGenerationRequestID != "COMPLETE" }) then {
	[_pathGenerationRequestID] call IVCS_Paths_removePathRequest;
};

_waypoint set ["movePoints", []];
_waypoint set ["pathGenerationRequestID", ""];