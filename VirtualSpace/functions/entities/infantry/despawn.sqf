params ["_entity"];

private _active = _entity getvariable "active";
if (!_active) exitwith {};

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

    private _unitWeapons = [_object] call IVCS_Common_getUnitObjectLoadoutInfo;

    _x setvariable ["object", objnull];
    _x setvariable ["weapons", _unitWeapons];
    _x setvariable ["damage", damage _object];

    deletevehicle _object;
} foreach _units;

deleteGroup _group;
_entity setvariable ["group", grpNull];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity setvariable ["currentWaypointPathGenerated", false];
_entity setvariable ["pathGenInProgress", false];
_entity setvariable ["movePoints", []];

_entity setvariable ["active", false];

// despawn any connected vehicles

private _vehiclesInCommandOf = _entity getvariable "vehiclesInCommandOf";
private _vehiclesInCargoOf = _entity getvariable "vehiclesInCargoOf";
{
    private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
    private _vehicleEntityActive = _vehicleEntity getvariable "active";
    if (_vehicleEntityActive) then {
        private _despawnFunc = missionnamespace getvariable (_vehicleEntity getvariable "despawn");
        [_vehicleEntity] call _despawnFunc;
    };
} foreach (_vehiclesInCommandOf + _vehiclesInCargoOf);