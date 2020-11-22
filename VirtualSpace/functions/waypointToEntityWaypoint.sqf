params ["_entity","_waypoint"];

private _entityWaypoint = [] call CBA_fnc_createNamespace;
_entityWaypoint setvariable ["position", waypointPosition _waypoint];
_entityWaypoint setvariable ["type", waypointType _waypoint];
_entityWaypoint setvariable ["speed", waypointSpeed _waypoint];
_entityWaypoint setvariable ["completionRadius", waypointCompletionRadius _waypoint];
_entityWaypoint setvariable ["formation", waypointFormation _waypoint];
_entityWaypoint setvariable ["combatMode", waypointCombatMode _waypoint];
_entityWaypoint setvariable ["behavior", waypointBehaviour _waypoint];
_entityWaypoint setvariable ["statements", ((waypointStatements _waypoint) select 1) splitString ";"];
_entityWaypoint setvariable ["timeout", waypointTimeout _waypoint];
_entityWaypoint setvariable ["attachedVehicle", ""];
_entityWaypoint setvariable ["name", waypointName _waypoint];
_entityWaypoint setvariable ["description", waypointDescription _waypoint];

private _attachedVehicle = waypointAttachedVehicle _waypoint;
if (!isNull _attachedVehicle) then {
    private _attachedVehicleEntityID = _attachedVehicle getvariable ["entityID", ""];
    if (_attachedVehicleEntityID != "") then {
        _entityWaypoint setvariable ["attachedVehicle", _attachedVehicleEntityID];
    };
};

_entityWaypoint