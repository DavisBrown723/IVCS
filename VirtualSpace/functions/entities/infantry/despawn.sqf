params ["_entity"];

private _units = _entity getvariable "units";
private _group = _entity getvariable "group";

// store waypoints

private _waypoints = waypoints _group;
private _waypointCount = count _waypoints - 1;
private _IVCSWaypointCount = {
    private _name = waypointName _x;
    _name find "wp_" != -1
} count _waypoints;

// delete units

{
    private _object = _x getvariable "object";

    _x setvariable ["object", objnull];
    _x setvariable ["damage", damage _object];

    deletevehicle _object;
} foreach _units;

deleteGroup _group;
_entity setvariable ["group", groupNull];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity setvariable ["active", false];