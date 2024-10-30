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

private _waypointIDNum = IVCS_VirtualSpace_Controller get "nextWaypointId";
IVCS_VirtualSpace_Controller set ["nextWaypointId", _waypointIDNum + 1];

private _waypoint = createHashMapFromArray [
    ["position", _position],
    ["type", toupper _type],
    ["speed", toupper _speed],
    ["completionRadius", _completionRadius],
    ["behaviour", toupper _behaviour],
    ["formation", toupper _formation],
    ["combatMode", toupper _combatMode],
    ["statements", _statements],
    ["attachedVehicle", _attachVehicle],
    ["timeout", _timeout],
    ["name", format ["wp_%1", _waypointIDNum]],
    ["description", _description],

    ["initialized", false],

    ["movePoints", []],
    ["pathGenerationRequestID", ""]
];

_waypoint