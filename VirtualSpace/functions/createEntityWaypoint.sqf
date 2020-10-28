params [
    "_position",
    ["_type", "MOVE"],
    ["_speed", "UNCHANGED"],
    ["_completionRadius", -1],
    ["_behaviour", "UNCHANGED"],
    ["_formation", "NO CHANGE"],
    ["_combatMode", "NO CHANGE"],
    ["_statements", []],
    ["_attachVehicle", ""],
    ["_timeout", []],
    ["_description", ""]
];

private _waypointIDNum = IVCS_VirtualSpace_Controller getvariable "nextWaypointId";
IVCS_VirtualSpace_Controller setvariable ["nextWaypointId", _waypointIDNum + 1];

private _waypoint = [] call CBA_fnc_createNamespace;
_waypoint setvariable ["position", _position];
_waypoint setvariable ["type", toupper _type];
_waypoint setvariable ["speed", toupper _speed];
_waypoint setvariable ["completionRadius", _completionRadius];
_waypoint setvariable ["behaviour", toupper _behaviour];
_waypoint setvariable ["formation", toupper _formation];
_waypoint setvariable ["combatMode", toupper _combatMode];
_waypoint setvariable ["statements", _statements];
_waypoint setvariable ["attachedVehicle", _attachVehicle];
_waypoint setvariable ["timeout", _timeout];
_waypoint setvariable ["name", format ["wp_%1", _waypointIDNum]];
_waypoint setvariable ["description", _description];

_waypoint