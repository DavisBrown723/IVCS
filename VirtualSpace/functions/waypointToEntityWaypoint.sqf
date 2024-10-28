params ["_entity","_waypoint"];

private _entityWaypoint = createHashMapFromArray [
    ["position", waypointPosition _waypoint],
    ["type", waypointType _waypoint],
    ["speed", waypointSpeed _waypoint],
    ["completionRadius", waypointCompletionRadius _waypoint],
    ["formation", waypointFormation _waypoint],
    ["combatMode", waypointCombatMode _waypoint],
    ["behavior", waypointBehaviour _waypoint],
    ["statements", ((waypointStatements _waypoint) select 1) splitString ";"],
    ["timeout", waypointTimeout _waypoint],
    ["attachedVehicle", ""],
    ["name", waypointName _waypoint],
    ["description", waypointDescription _waypoint]
];

private _attachedVehicle = waypointAttachedVehicle _waypoint;
if (!isNull _attachedVehicle) then {
    private _attachedVehicleEntityID = _attachedVehicle getvariable ["entityID", ""];
    if (_attachedVehicleEntityID != "") then {
        _entityWaypoint set ["attachedVehicle", _attachedVehicleEntityID];
    };
};

_entityWaypoint