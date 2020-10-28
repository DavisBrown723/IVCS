params ["_entity","_group","_entityWaypoint"];

private _name = _entityWaypoint getvariable "name";
private _description = _entityWaypoint getvariable "description";
private _position = _entityWaypoint getvariable "position";
private _type = _entityWaypoint getvariable "type";
private _speed = _entityWaypoint getvariable "speed";
private _completionRadius = _entityWaypoint getvariable "completionRadius";
private _timeout = _entityWaypoint getvariable "timeout";
private _formation = _entityWaypoint getvariable "formation";
private _combatMode = _entityWaypoint getvariable "combatMode";
private _behavior = _entityWaypoint getvariable "behavior";
private _statements = _entityWaypoint getvariable "statements";
private _attachedVehicle = _entityWaypoint getvariable "attachedVehicle";

_position set [2, 0];


private _waypoint = _group addWaypoint [_position, 0];
_waypoint setWaypointName _name;
_waypoint setWaypointDescription _description;
_waypoint setWaypointType _type;
_waypoint setWaypointSpeed _speed;
_waypoint setWaypointCompletionRadius _completionRadius;
if (count _timeout > 0) then {
    _waypoint setWaypointTimeout _timeout;
};
_waypoint setWaypointFormation _formation;
_waypoint setWaypointCombatMode _combatMode;
_waypoint setWaypointBehaviour _behavior;

private _entityID = _entity getvariable "id";
_waypoint setWaypointStatements ["true", format ["['%1', '%2'] call IVCS_VirtualSpace_onWaypointCompleted", _entityID, _name]];

if (_attachedVehicle != "") then {

};

_waypoint