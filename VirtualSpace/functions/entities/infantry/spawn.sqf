params ["_entity"];

private _units = _entity getvariable "units";

// create group

private _side = _entity getvariable "side";
private _sideObject = [_side] call IVCS_Common_sideStringToObject;
private _group = createGroup [_sideObject, true];

_entity setvariable ["group", _group];

// spawn units

private _entityID = _entity getvariable "id";
private _position = _entity getvariable "position";

{
    private _class = _x getvariable "class";
    private _damage = _x getvariable "damage";
    private _unit = _group createUnit [_class, _position, [], 0, "NONE"];
    _unit setpos (formationPosition _unit);
    _unit setdamage _damage;

    _unit setvariable ["entityID", _entityID];
    _unit setvariable ["unitID", _x getvariable "id"];

    _unit addEventHandler ["Killed", IVCS_VirtualSpace_onUnitKilled];

    _x setvariable ["object", _unit];
} foreach _units;

// restore waypoints

private _waypoints = _entity getvariable "waypoints";
private _currentWaypoint = _entity getvariable "currentWaypoint";

{
    [_entity, _group, _x] call IVCS_VirtualSpace_entityWaypointToWaypoint;
} foreach _waypoints;

if (_currentWaypoint != -1) then {
    // setting current waypoint sets previous waypoint as completed
    // so lets temporarily ignore its callbacks to counter this
    // since we havent set current waypoint yet, wp_0 will always be the one we ignore
    if (_currentWaypoint > 0) then {
        _entity setvariable ["ignoreWpCallback", "wp_0"];
    };

    _group setCurrentWaypoint [_group, _currentWaypoint + 1];
};

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};