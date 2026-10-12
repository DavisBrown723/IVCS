params ["_entity", "_waypoint"];

private _name = waypointName _waypoint;
private _statements = [
    (waypointStatements _waypoint) select 1
] call IVCS_VirtualSpace_filterWaypointStatements;
private _entityWaypoint = [
    waypointPosition _waypoint, waypointType _waypoint, [
        ["speed", waypointSpeed _waypoint],
        ["completionRadius", waypointCompletionRadius _waypoint],
        ["formation", waypointFormation _waypoint],
        ["combatMode", waypointCombatMode _waypoint],
        ["behavior", waypointBehaviour _waypoint],
        ["statements", _statements],
        ["timeout", waypointTimeout _waypoint],
        ["description", waypointDescription _waypoint]
    ]
] call IVCS_VirtualSpace_createEntityWaypoint;
if (_name != "") then { _entityWaypoint set ["name", _name]; };

private _attachedVehicle = waypointAttachedVehicle _waypoint;
if (!isNull _attachedVehicle) then {
    _entityWaypoint set ["attachedVehicle", _attachedVehicle getVariable ["entityID", ""]];
};

_entityWaypoint
