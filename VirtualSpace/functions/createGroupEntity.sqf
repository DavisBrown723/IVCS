params ["_side","_faction","_position","_units"];

private _groupEntity = createHashMapFromArray [
    ["timeLastUpdate", diag_tickTime],
    ["delayedInitComplete", false],
    ["entityType", "group"],
    ["vehicleType", "group"],
    ["entity", "group"],
    ["active", false],
    ["position", _position],
    ["side", _side],
    ["faction", _faction],
    ["units", _units],
    ["group", grpNull],
    ["vehiclesInCommandOf", []],
    ["vehiclesInCargoOf", []],
    ["moveSpeedPerSecond", 4.3],
    ["sightRange", 400],

    ["waypoints", []],
    ["currentWaypointIndex", -1],
    ["minWaypointIndex", -1],
    ["maxWaypointIndex", -1],
    ["ignoreWpCallback", ""],
    ["tasks", []],

    ["currentEngagementTask", ""],

    ["pathfindingStrategy", "man"],

    ["reactToContact", "IVCS_VirtualSpace_Group_onContactSimple"],

    ["update", "IVCS_VirtualSpace_Group_update"],
    ["spawn", "IVCS_VirtualSpace_Group_spawn"],
    ["despawn", "IVCS_VirtualSpace_Group_despawn"],
    ["unregister", "IVCS_VirtualSpace_Group_unregister"],

    ["nextUnitIDNum", count _units]
];

private _groupEntityID = [_groupEntity] call IVCS_VirtualSpace_registerEntity;

private _debug = IVCS_VirtualSpace_Controller get "debug";
private _debugMarker = if (_debug) then {
    [_groupEntity] call IVCS_VirtualSpace_createEntityDebugMarker;
} else {
    ""
};
_groupEntity set ["debugMarker", _debugMarker];

_groupEntity