params ["_entity","_group","_entityWaypoint"];

private _name = _entityWaypoint get "name";
private _description = _entityWaypoint get "description";
private _position = _entityWaypoint get "position";
private _type = _entityWaypoint get "type";
private _speed = _entityWaypoint get "speed";
private _completionRadius = _entityWaypoint get "completionRadius";
private _timeout = _entityWaypoint get "timeout";
private _formation = _entityWaypoint get "formation";
private _combatMode = _entityWaypoint get "combatMode";
private _behavior = _entityWaypoint get "behavior";
private _statements = _entityWaypoint get "statements";
private _attachedVehicle = _entityWaypoint get "attachedVehicle";

_position set [2, 0];

private _waypoint = _group addWaypoint [_position, 0];
_waypoint setWaypointName _name;
_waypoint setWaypointDescription _description;

if (_type == "LAND") then {
    _waypoint setWaypointType "SCRIPTED";
    _waypoint setWaypointScript "A3\functions_f\waypoints\fn_wpLand.sqf";
} else {
    _waypoint setWaypointType _type;
};

_waypoint setWaypointSpeed _speed;
_waypoint setWaypointCompletionRadius _completionRadius;
if (count _timeout > 0) then {
    _waypoint setWaypointTimeout _timeout;
};
_waypoint setWaypointFormation _formation;
_waypoint setWaypointCombatMode _combatMode;
_waypoint setWaypointBehaviour _behavior;

private _entityID = _entity get "id";
_waypoint setWaypointStatements ["true", format ["['%1', '%2'] call IVCS_VirtualSpace_onWaypointCompleted", _entityID, _name]];

if (_attachedVehicle != "") then {

};

_waypoint