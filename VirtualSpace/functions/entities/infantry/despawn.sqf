params ["_entity"];

private _active = _entity get "active";
if (!_active) exitwith {};

private _units = _entity get "units";
private _group = _entity get "group";

// store waypoints

private _waypoints = waypoints _group;
private _waypointCount = count _waypoints - 1;
private _IVCSWaypointCount = {
    private _name = waypointName _x;
    _name find "wp_" != -1
} count _waypoints;

// delete units

{
    private _object = _x get "object";

    private _unitWeapons = [_object] call IVCS_Common_getUnitObjectLoadoutInfo;

    _x set ["object", objnull];
    _x set ["weapons", _unitWeapons];
    _x set ["damage", damage _object];

    deletevehicle _object;
} foreach _units;

deleteGroup _group;
_entity set ["group", grpNull];

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity set ["currentWaypointPathGenerated", false];
_entity set ["pathGenInProgress", false];
_entity set ["movePoints", []];

_entity set ["active", false];

// despawn any connected vehicles

private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
private _vehiclesInCargoOf = _entity get "vehiclesInCargoOf";
{
    private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
    private _vehicleEntityActive = _vehicleEntity get "active";
    if (_vehicleEntityActive) then {
        private _despawnFunc = missionnamespace getvariable (_vehicleEntity get "despawn");
        [_vehicleEntity] call _despawnFunc;
    };
} foreach (_vehiclesInCommandOf + _vehiclesInCargoOf);