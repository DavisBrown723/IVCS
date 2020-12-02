params ["_entity"];

private _active = _entity getvariable "active";
if (!_active) exitwith {};

// despawn any connected entities first

private _commandingEntityID = _entity getvariable "commandingEntity";
private _entitiesInCargo = _entity getvariable "entitiesInCargo";
{
    private _entity = [_x] call IVCS_VirtualSpace_getEntity;
    private _despawnFunc = missionnamespace getvariable (_entity getvariable "despawn");
    [_entity] call _despawnFunc;
} foreach (_entitiesInCargo + [_commandingEntityID]);

// despawn this entity

private _vehicleObject = _entity getvariable "object";

private _hitpoints = _entity getvariable "hitpoints";
{
    private _hitpoint = _x select 0;

    private _hitpointDamage = _vehicleObject getHitPointDamage _hitpoint;
    _x set [1, _hitpointDamage];
} foreach _hitpoints;

private _waypoints = _entity getvariable "waypoints";
if (_waypoints isequalto []) then {
    _entity setvariable ["engineOn", isEngineOn _vehicleObject];
};

deletevehicle _vehicleObject;

_entity setvariable ["object", objNull];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity setvariable ["active", false];