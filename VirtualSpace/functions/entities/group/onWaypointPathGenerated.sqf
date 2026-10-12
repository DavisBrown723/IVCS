params ["_entityID", "_waypointID", "_path"];

private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
if (isNil "_entity" || { _entity get "active" }) exitWith {};
private _waypoint = [_entity, _waypointID] call IVCS_VirtualSpace_getEntityWaypoint;
if (isNil "_waypoint") exitWith {};

_waypoint set ["movePoints", _path];
_waypoint set ["pathGenerationRequestID", "COMPLETE"];
_waypoint set ["pathFailed", _path isEqualTo []];
