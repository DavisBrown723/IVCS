params ["_waypoint"];

_waypoint set ["initialized", false];
_waypoint set ["pathGeneration", (_waypoint getOrDefault ["pathGeneration", 0]) + 1];
_waypoint deleteAt "pathFailed";

private _pathGenerationRequestID = _waypoint get "pathGenerationRequestID";
if (_pathGenerationRequestID != "" && { _pathGenerationRequestID != "COMPLETE" }) then {
	[_pathGenerationRequestID] call IVCS_Paths_removePathRequest;
};

_waypoint set ["movePoints", []];
_waypoint set ["pathGenerationRequestID", ""];