params ["_side","_faction","_position","_units"];

private _groupEntity = [] call CBA_fnc_createNamespace;
_groupEntity setvariable ["timeLastUpdate", diag_tickTime];
_groupEntity setvariable ["delayedInitComplete", false];
_groupEntity setvariable ["entityType", "group"];
_groupENtity setvariable ["entity", "group"];
_groupEntity setvariable ["active", false];
_groupEntity setvariable ["position", _position];
_groupEntity setvariable ["side", _side];
_groupEntity setvariable ["faction", _faction];
_groupEntity setvariable ["units", _units];
_groupEntity setvariable ["group", grpNull];
_groupEntity setvariable ["vehiclesInCommandOf", []];
_groupEntity setvariable ["vehiclesInCargoOf", []];
_groupEntity setvariable ["moveSpeedPerSecond", 4.3];

_groupEntity setvariable ["movePoints", []];
_groupEntity setvariable ["pathGenInProgress", false];
_groupEntity setvariable ["waypoints", []];
_groupEntity setvariable ["currentWaypoint", -1];
_groupEntity setvariable ["minWaypoint", 0];
_groupEntity setvariable ["maxWaypoint", 0];
_groupEntity setvariable ["ignoreWpCallback", ""];
_groupEntity setvariable ["tasks", []];

_groupEntity setvariable ["pathfindingStrategy", "man"];

_groupEntity setvariable ["update", "IVCS_VirtualSpace_Infantry_update"];
_groupEntity setvariable ["spawn", "IVCS_VirtualSpace_Infantry_spawn"];
_groupEntity setvariable ["despawn", "IVCS_VirtualSpace_Infantry_despawn"];
_groupEntity setvariable ["unregister", "IVCS_VirtualSpace_Infantry_unregister"];

_groupEntity setvariable ["nextUnitIDNum", count _units];

private _groupEntityID = [_groupEntity] call IVCS_VirtualSpace_registerEntity;

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
private _debugMarker = if (_debug) then {
    [_groupEntity] call IVCS_VirtualSpace_createEntityDebugMarker;
} else {
    ""
};
_groupEntity setvariable ["debugMarker", _debugMarker];

_groupEntity