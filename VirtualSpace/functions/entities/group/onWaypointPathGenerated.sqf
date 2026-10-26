params ["_entityID", "_waypointID", "_generationOrPath", ["_path", []]];
private _generation = if (_generationOrPath isEqualType []) then { -1 } else { _generationOrPath };
if (_generation == -1) then { _path = _generationOrPath; };

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
if (isNil "_entity" || { _entity get "active" }) exitWith {};
private _waypoint = [_entity, _waypointID] call IVCS_VirtualSpace_getEntityWaypoint;
if (isNil "_waypoint" || { _generation >= 0 && { _generation != (_waypoint get "pathGeneration") } }) exitWith {};

_waypoint set ["movePoints", _path];
_waypoint set ["pathGenerationRequestID", "COMPLETE"];
_waypoint set ["pathFailed", _path isEqualTo []];
