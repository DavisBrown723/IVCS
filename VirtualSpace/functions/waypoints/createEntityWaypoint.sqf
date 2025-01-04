params [
    "_position",
    ["_type", "MOVE"],
    ["_waypointParams", []]
];

// if (isnil "IVCS_createEntityWaypoint_defaultParams") then {
//     IVCS_createEntityWaypoint_defaultParams = createhashmapfromarray [
//         ["speed", "UNCHANGED"],
//         ["completionRadius", -1],
//         ["behaviour", "UNCHANGED"],
//         ["formation", "NO CHANGE"],
//         ["combatMode", "NO CHANGE"],
//         ["statements", []],
//         ["attachVehicle", ""],
//         ["timeout", []],
//         ["description", ""]
//     ];
// };

private _waypointIDNum = IVCS_VirtualSpace_Controller get "nextWaypointId";
IVCS_VirtualSpace_Controller set ["nextWaypointId", _waypointIDNum + 1];

// private _waypoint = createHashMapFromArray [
//     ["position", _position],
//     ["type", toupper _type],
//     ["speed", toupper _speed],
//     ["completionRadius", _completionRadius],
//     ["behaviour", toupper _behaviour],
//     ["formation", toupper _formation],
//     ["combatMode", toupper _combatMode],
//     ["statements", _statements],
//     ["attachedVehicle", _attachVehicle],
//     ["timeout", _timeout],
//     ["name", format ["wp_%1", _waypointIDNum]],
//     ["description", _description],

//     ["initialized", false],

//     ["movePoints", []],
//     ["pathGenerationRequestID", ""]
// ];

private _waypointVars = [
    ["position", _position],
    ["type", toupper _type]
];

_waypointVars append _waypointParams;

private _waypoint = createHashMapFromArray _waypointVars;

_waypoint