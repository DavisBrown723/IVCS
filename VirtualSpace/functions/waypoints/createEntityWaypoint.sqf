// Options are named pairs. IDs, ownership, and path state belong to the runtime.
params ["_position", ["_type", "MOVE"], ["_options", []]];

private _waypoint = createHashMapFromArray [
    ["speed", "UNCHANGED"], ["completionRadius", -1], ["behavior", "UNCHANGED"],
    ["formation", "NO CHANGE"], ["combatMode", "NO CHANGE"],
    ["statements", []], ["callbacks", []], ["attachedVehicle", ""],
    ["timeout", []], ["description", ""]
];
_waypoint merge [createHashMapFromArray _options, true];
{ _waypoint set [_x, toUpper (_waypoint get _x)]; } forEach ["speed", "behavior", "formation", "combatMode"];

private _waypointIDNum = IVCS_VirtualSpace_Controller get "nextWaypointId";
IVCS_VirtualSpace_Controller set ["nextWaypointId", _waypointIDNum + 1];
_waypoint set ["position", +_position];
_waypoint set ["type", toUpper _type];
_waypoint set ["name", format ["wp_%1", _waypointIDNum]];
_waypoint set ["initialized", false];
_waypoint set ["movePoints", []];
_waypoint set ["pathGenerationRequestID", ""];
_waypoint deleteAt "entity";

_waypoint
